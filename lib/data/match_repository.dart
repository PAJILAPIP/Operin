import 'package:sqflite/sqflite.dart';

import '../core/utils/formatters.dart';
import '../core/utils/geo.dart';
import '../model/auth_user.dart';
import '../model/barter.dart';
import '../model/business_category.dart';
import '../model/food_category.dart';
import '../model/partner_profile.dart';
import '../model/stock_item.dart';
import 'local_database.dart';

class BarterException implements Exception {
  const BarterException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data matchmaking & barter. Implementasi saat ini SQLite lokal;
/// ganti dengan backend agar berjalan antar-perangkat.
abstract interface class MatchRepository {
  /// UMKM lain yang sudah menyelesaikan onboarding, beserta stoknya.
  Future<List<PartnerProfile>> listPartners({required AuthUser viewer});

  /// Barter yang melibatkan [userId], terbaru diperbarui lebih dulu.
  Future<List<Barter>> listBarters(int userId);

  Future<List<BarterMessage>> listMessages(int barterId);

  Future<Barter> createBarter(Barter barter, {String? message});

  /// Tawaran balik oleh [actorId] (harus pihak yang sedang ditunggu).
  Future<void> counterOffer(
    int barterId, {
    required int actorId,
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
    required DateTime now,
  });

  /// Terima / tolak oleh pihak yang sedang ditunggu.
  Future<void> respond(
    int barterId, {
    required int actorId,
    required bool accept,
    required DateTime now,
  });

  /// Dibatalkan oleh pengaju selama masih terbuka.
  Future<void> cancel(int barterId, {required int actorId, required DateTime now});

  Future<void> sendMessage(
    int barterId, {
    required int senderId,
    required String text,
    required DateTime now,
  });
}

class SqliteMatchRepository implements MatchRepository {
  const SqliteMatchRepository();

  @override
  Future<List<PartnerProfile>> listPartners({required AuthUser viewer}) async {
    final database = await LocalDatabase.instance.database;
    final users = await database.rawQuery('''
      SELECT u.id, u.full_name, u.role, u.business_type, u.address,
        u.latitude, u.longitude,
        b.business_name, b.whatsapp, b.preferred_categories
      FROM users u
      JOIN business_profiles b ON b.user_id = u.id
      WHERE u.id != ? AND u.role IS NOT NULL
    ''', [viewer.id]);
    if (users.isEmpty) return const [];

    final ids = users.map((row) => row['id']! as int).toList();
    final stockRows = await database.query(
      'stock_items',
      where: 'user_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      orderBy: 'expiry_date ASC',
    );
    final stocksByUser = <int, List<StockItem>>{};
    for (final row in stockRows) {
      final item = StockItem.fromMap(row);
      stocksByUser.putIfAbsent(item.userId, () => []).add(item);
    }

    return users.map((row) {
      final id = row['id']! as int;
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      return PartnerProfile(
        userId: id,
        name: row['business_name']! as String,
        role: row['role']! as String,
        businessCategory:
            BusinessCategory.fromName(row['business_type'] as String?),
        address: row['address']! as String,
        whatsapp: row['whatsapp'] as String?,
        distanceKm: viewer.hasLocation && lat != null && lng != null
            ? distanceKm(viewer.latitude!, viewer.longitude!, lat, lng)
            : null,
        preferredCategories:
            FoodCategory.parseList(row['preferred_categories'] as String?),
        stocks: stocksByUser[id] ?? const [],
      );
    }).toList();
  }

  static const _barterSelect = '''
    SELECT br.*,
      COALESCE(pb.business_name, pu.full_name) AS proposer_name,
      COALESCE(rb.business_name, ru.full_name) AS receiver_name,
      os.name AS offered_stock_name, os.unit AS offered_unit,
      rs.name AS requested_stock_name, rs.unit AS requested_unit
    FROM barters br
    JOIN users pu ON pu.id = br.proposer_id
    LEFT JOIN business_profiles pb ON pb.user_id = br.proposer_id
    JOIN users ru ON ru.id = br.receiver_id
    LEFT JOIN business_profiles rb ON rb.user_id = br.receiver_id
    JOIN stock_items os ON os.id = br.offered_stock_id
    LEFT JOIN stock_items rs ON rs.id = br.requested_stock_id
  ''';

  @override
  Future<List<Barter>> listBarters(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.rawQuery(
      '$_barterSelect WHERE br.proposer_id = ? OR br.receiver_id = ? '
      'ORDER BY br.updated_at DESC, br.id DESC',
      [userId, userId],
    );
    return rows.map(Barter.fromMap).toList();
  }

  @override
  Future<List<BarterMessage>> listMessages(int barterId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.rawQuery('''
      SELECT m.*, COALESCE(b.business_name, u.full_name) AS sender_name
      FROM barter_messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN business_profiles b ON b.user_id = m.sender_id
      WHERE m.barter_id = ?
      ORDER BY m.id ASC
    ''', [barterId]);
    return rows.map(BarterMessage.fromMap).toList();
  }

  @override
  Future<Barter> createBarter(Barter barter, {String? message}) async {
    if (barter.proposerId == barter.receiverId) {
      throw const BarterException('Tidak bisa barter dengan diri sendiri.');
    }
    final database = await LocalDatabase.instance.database;
    return database.transaction((txn) async {
      await _checkStock(
        txn,
        barter.offeredStockId,
        ownerId: barter.proposerId,
        quantity: barter.offeredQuantity,
        label: 'ditawarkan',
      );
      if (barter.requestedStockId != null) {
        await _checkStock(
          txn,
          barter.requestedStockId!,
          ownerId: barter.receiverId,
          quantity: barter.requestedQuantity ?? 0,
          label: 'diminta',
        );
      } else if (barter.type == BarterType.barter &&
          (barter.requestedNote == null || barter.requestedNote!.isEmpty)) {
        throw const BarterException('Sebutkan bahan yang Anda minta.');
      }

      final id = await txn.insert('barters', barter.toMap()..remove('id'));
      await _addMessage(
        txn,
        barterId: id,
        senderId: barter.proposerId,
        text: (message == null || message.trim().isEmpty)
            ? (barter.type == BarterType.donation
                ? 'Mengajukan penyaluran stok untuk daur ulang.'
                : 'Mengajukan penawaran barter.')
            : message.trim(),
        offered: barter.offeredQuantity,
        requested: barter.requestedQuantity,
        now: barter.createdAt,
      );
      return barter.copyWith(id: id);
    });
  }

  @override
  Future<void> counterOffer(
    int barterId, {
    required int actorId,
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final barter = await _openBarterAwaiting(txn, barterId, actorId);
      final requested = barter.requestedStockId == null
          ? barter.requestedQuantity
          : (requestedQuantity ?? barter.requestedQuantity);
      await _checkStock(
        txn,
        barter.offeredStockId,
        ownerId: barter.proposerId,
        quantity: offeredQuantity,
        label: 'ditawarkan',
      );
      if (barter.requestedStockId != null) {
        await _checkStock(
          txn,
          barter.requestedStockId!,
          ownerId: barter.receiverId,
          quantity: requested ?? 0,
          label: 'diminta',
        );
      }
      await txn.update(
        'barters',
        {
          'offered_quantity': offeredQuantity,
          'requested_quantity': requested,
          'status': BarterStatus.negotiating.name,
          'last_actor_id': actorId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [barterId],
      );
      await _addMessage(
        txn,
        barterId: barterId,
        senderId: actorId,
        text: (message == null || message.trim().isEmpty)
            ? 'Mengajukan tawaran balik.'
            : message.trim(),
        offered: offeredQuantity,
        requested: requested,
        now: now,
      );
    });
  }

  @override
  Future<void> respond(
    int barterId, {
    required int actorId,
    required bool accept,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final barter = await _openBarterAwaiting(txn, barterId, actorId);
      if (accept) {
        // Stok bisa berubah selama negosiasi; cek ulang sebelum sepakat.
        await _checkStock(
          txn,
          barter.offeredStockId,
          ownerId: barter.proposerId,
          quantity: barter.offeredQuantity,
          label: 'ditawarkan',
        );
        if (barter.requestedStockId != null) {
          await _checkStock(
            txn,
            barter.requestedStockId!,
            ownerId: barter.receiverId,
            quantity: barter.requestedQuantity ?? 0,
            label: 'diminta',
          );
        }
      }
      await _setStatus(
        txn,
        barterId,
        accept ? BarterStatus.accepted : BarterStatus.rejected,
        actorId,
        now,
      );
      await _addMessage(
        txn,
        barterId: barterId,
        senderId: actorId,
        text: accept ? 'Menyetujui kesepakatan.' : 'Menolak penawaran.',
        now: now,
      );
    });
  }

  @override
  Future<void> cancel(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final barter = await _load(txn, barterId);
      if (barter.proposerId != actorId) {
        throw const BarterException('Hanya pengaju yang bisa membatalkan.');
      }
      if (!barter.status.isOpen) {
        throw BarterException(
          'Barter sudah ${barter.status.label.toLowerCase()}.',
        );
      }
      await _setStatus(txn, barterId, BarterStatus.cancelled, actorId, now);
      await _addMessage(
        txn,
        barterId: barterId,
        senderId: actorId,
        text: 'Membatalkan penawaran.',
        now: now,
      );
    });
  }

  @override
  Future<void> sendMessage(
    int barterId, {
    required int senderId,
    required String text,
    required DateTime now,
  }) async {
    if (text.trim().isEmpty) return;
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final barter = await _load(txn, barterId);
      if (senderId != barter.proposerId && senderId != barter.receiverId) {
        throw const BarterException('Anda bukan bagian dari barter ini.');
      }
      await _addMessage(
        txn,
        barterId: barterId,
        senderId: senderId,
        text: text.trim(),
        now: now,
      );
      await txn.update(
        'barters',
        {'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [barterId],
      );
    });
  }

  // --- helper ---

  Future<Barter> _load(DatabaseExecutor txn, int barterId) async {
    final rows = await txn.query(
      'barters',
      where: 'id = ?',
      whereArgs: [barterId],
      limit: 1,
    );
    if (rows.isEmpty) throw const BarterException('Barter tidak ditemukan.');
    return Barter.fromMap(rows.first);
  }

  Future<Barter> _openBarterAwaiting(
    DatabaseExecutor txn,
    int barterId,
    int actorId,
  ) async {
    final barter = await _load(txn, barterId);
    if (!barter.status.isOpen) {
      throw BarterException(
        'Barter sudah ${barter.status.label.toLowerCase()}.',
      );
    }
    if (!barter.awaitingResponseFrom(actorId)) {
      throw const BarterException('Menunggu jawaban dari pihak lain.');
    }
    return barter;
  }

  Future<void> _checkStock(
    DatabaseExecutor txn,
    int stockId, {
    required int ownerId,
    required double quantity,
    required String label,
  }) async {
    if (quantity <= 0) {
      throw BarterException('Jumlah yang $label harus lebih dari 0.');
    }
    final rows = await txn.query(
      'stock_items',
      where: 'id = ?',
      whereArgs: [stockId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw BarterException('Stok yang $label sudah tidak ada.');
    }
    final stock = StockItem.fromMap(rows.first);
    if (stock.userId != ownerId) {
      throw BarterException('Stok yang $label bukan milik pihak tersebut.');
    }
    if (quantity > stock.quantity) {
      throw BarterException(
        'Jumlah yang $label melebihi stok '
        '(${formatQuantity(stock.quantity)} ${stock.unit.label}).',
      );
    }
  }

  Future<void> _setStatus(
    DatabaseExecutor txn,
    int barterId,
    BarterStatus status,
    int actorId,
    DateTime now,
  ) => txn.update(
    'barters',
    {
      'status': status.name,
      'last_actor_id': actorId,
      'updated_at': now.toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [barterId],
  );

  Future<void> _addMessage(
    DatabaseExecutor txn, {
    required int barterId,
    required int senderId,
    required String text,
    double? offered,
    double? requested,
    required DateTime now,
  }) => txn.insert(
    'barter_messages',
    BarterMessage(
      barterId: barterId,
      senderId: senderId,
      text: text,
      offeredQuantity: offered,
      requestedQuantity: requested,
      createdAt: now,
    ).toMap()
      ..remove('id'),
  );
}

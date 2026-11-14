import 'package:sqflite/sqflite.dart';

import '../core/utils/formatters.dart';
import '../model/activity_entry.dart';
import '../model/barter.dart';
import '../model/market_order.dart';
import '../model/promotion.dart';
import '../model/stock_item.dart';
import 'local_database.dart';

class TransactionException implements Exception {
  const TransactionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Penyelesaian transaksi (memindahkan stok) dan riwayat aktivitas.
abstract interface class TransactionRepository {
  /// Riwayat aktivitas milik [userId], terbaru lebih dulu.
  Future<List<ActivityEntry>> listActivity(int userId);

  /// Penjual menandai pesanan yang sudah diterima sebagai selesai:
  /// stok penjual berkurang, pembeli mendapat stok baru, riwayat dicatat.
  Future<void> completeOrder(
    int orderId, {
    required int actorId,
    required DateTime now,
  });

  /// Salah satu pihak menyelesaikan barter/donasi yang sudah disepakati:
  /// stok berpindah di kedua sisi, riwayat dicatat.
  Future<void> completeBarter(
    int barterId, {
    required int actorId,
    required DateTime now,
  });
}

class SqliteTransactionRepository implements TransactionRepository {
  const SqliteTransactionRepository();

  @override
  Future<List<ActivityEntry>> listActivity(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.query(
      'activity_log',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(ActivityEntry.fromMap).toList();
  }

  @override
  Future<void> completeOrder(
    int orderId, {
    required int actorId,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final order = MarketOrder.fromMap(
        await _row(txn, 'orders', orderId, 'Pesanan tidak ditemukan.'),
      );
      if (order.sellerId != actorId) {
        throw const TransactionException(
          'Hanya penjual yang bisa menyelesaikan pesanan.',
        );
      }
      if (order.status != OrderStatus.accepted) {
        throw TransactionException(
          'Pesanan berstatus "${order.status.label}", belum bisa diselesaikan.',
        );
      }
      final promotion = Promotion.fromMap(
        await _row(txn, 'promotions', order.promotionId, 'Promo tidak ditemukan.'),
      );
      final stock = await _takeStock(
        txn,
        promotion.stockId,
        ownerId: order.sellerId,
        quantity: order.quantity,
        now: now,
      );

      // Pembeli menerima bahan sebagai stok baru dengan harga yang dibayar.
      final sellerName = await _name(txn, order.sellerId);
      final buyerName = await _name(txn, order.buyerId);
      await _giveStock(
        txn,
        stock,
        toUserId: order.buyerId,
        quantity: order.quantity,
        pricePerUnit: order.unitPrice,
        note: 'Dibeli dari $sellerName',
        now: now,
      );

      await txn.update(
        'orders',
        {'status': OrderStatus.completed.name, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final weight = order.quantity * stock.unit.estimatedKg;
      final discount = (promotion.originalPrice - order.unitPrice) * order.quantity;
      await _log(txn, ActivityEntry(
        userId: order.sellerId,
        kind: ActivityKind.sale,
        counterpartId: order.buyerId,
        counterpartName: buyerName,
        stockName: stock.name,
        category: stock.category,
        quantity: order.quantity,
        unit: stock.unit,
        amount: order.totalPrice,
        savedValue: order.totalPrice,
        weightKg: weight,
        referenceType: 'order',
        referenceId: orderId,
        createdAt: now,
      ));
      await _log(txn, ActivityEntry(
        userId: order.buyerId,
        kind: ActivityKind.purchase,
        counterpartId: order.sellerId,
        counterpartName: sellerName,
        stockName: stock.name,
        category: stock.category,
        quantity: order.quantity,
        unit: stock.unit,
        amount: order.totalPrice,
        savedValue: discount <= 0 ? 0 : discount.round(),
        weightKg: weight,
        referenceType: 'order',
        referenceId: orderId,
        createdAt: now,
      ));
    });
  }

  @override
  Future<void> completeBarter(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final barter = Barter.fromMap(
        await _row(txn, 'barters', barterId, 'Barter tidak ditemukan.'),
      );
      if (actorId != barter.proposerId && actorId != barter.receiverId) {
        throw const TransactionException('Anda bukan bagian dari barter ini.');
      }
      if (barter.status != BarterStatus.accepted) {
        throw TransactionException(
          'Barter berstatus "${barter.status.label}", belum bisa diselesaikan.',
        );
      }
      final isDonation = barter.type == BarterType.donation;
      final proposerName = await _name(txn, barter.proposerId);
      final receiverName = await _name(txn, barter.receiverId);

      // Sisi pengaju → penerima
      final offered = await _takeStock(
        txn,
        barter.offeredStockId,
        ownerId: barter.proposerId,
        quantity: barter.offeredQuantity,
        now: now,
      );
      if (!isDonation) {
        await _giveStock(
          txn,
          offered,
          toUserId: barter.receiverId,
          quantity: barter.offeredQuantity,
          pricePerUnit: offered.pricePerUnit,
          note: 'Barter dengan $proposerName',
          now: now,
        );
      }
      final offeredWeight = barter.offeredQuantity * offered.unit.estimatedKg;
      await _log(txn, ActivityEntry(
        userId: barter.proposerId,
        kind: isDonation ? ActivityKind.donationOut : ActivityKind.barterOut,
        counterpartId: barter.receiverId,
        counterpartName: receiverName,
        stockName: offered.name,
        category: offered.category,
        quantity: barter.offeredQuantity,
        unit: offered.unit,
        amount: 0,
        savedValue: isDonation
            ? 0
            : (barter.offeredQuantity * offered.pricePerUnit).round(),
        weightKg: offeredWeight,
        referenceType: 'barter',
        referenceId: barterId,
        createdAt: now,
      ));
      await _log(txn, ActivityEntry(
        userId: barter.receiverId,
        kind: isDonation ? ActivityKind.donationIn : ActivityKind.barterIn,
        counterpartId: barter.proposerId,
        counterpartName: proposerName,
        stockName: offered.name,
        category: offered.category,
        quantity: barter.offeredQuantity,
        unit: offered.unit,
        amount: 0,
        savedValue: 0,
        weightKg: offeredWeight,
        referenceType: 'barter',
        referenceId: barterId,
        createdAt: now,
      ));

      // Sisi penerima → pengaju (hanya jika yang diminta adalah stok tercatat)
      final requestedId = barter.requestedStockId;
      final requestedQty = barter.requestedQuantity;
      if (!isDonation && requestedId != null && requestedQty != null) {
        final requested = await _takeStock(
          txn,
          requestedId,
          ownerId: barter.receiverId,
          quantity: requestedQty,
          now: now,
        );
        await _giveStock(
          txn,
          requested,
          toUserId: barter.proposerId,
          quantity: requestedQty,
          pricePerUnit: requested.pricePerUnit,
          note: 'Barter dengan $receiverName',
          now: now,
        );
        final weight = requestedQty * requested.unit.estimatedKg;
        await _log(txn, ActivityEntry(
          userId: barter.receiverId,
          kind: ActivityKind.barterOut,
          counterpartId: barter.proposerId,
          counterpartName: proposerName,
          stockName: requested.name,
          category: requested.category,
          quantity: requestedQty,
          unit: requested.unit,
          amount: 0,
          savedValue: (requestedQty * requested.pricePerUnit).round(),
          weightKg: weight,
          referenceType: 'barter',
          referenceId: barterId,
          createdAt: now,
        ));
        await _log(txn, ActivityEntry(
          userId: barter.proposerId,
          kind: ActivityKind.barterIn,
          counterpartId: barter.receiverId,
          counterpartName: receiverName,
          stockName: requested.name,
          category: requested.category,
          quantity: requestedQty,
          unit: requested.unit,
          amount: 0,
          savedValue: 0,
          weightKg: weight,
          referenceType: 'barter',
          referenceId: barterId,
          createdAt: now,
        ));
      }

      await txn.update(
        'barters',
        {
          'status': BarterStatus.completed.name,
          'last_actor_id': actorId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [barterId],
      );
      await txn.insert('barter_messages', {
        'barter_id': barterId,
        'sender_id': actorId,
        'text': 'Menandai barter selesai. Stok sudah dipindahkan.',
        'created_at': now.toIso8601String(),
      });
    });
  }

  // --- helper ---

  Future<Map<String, Object?>> _row(
    DatabaseExecutor txn,
    String table,
    int id,
    String notFound,
  ) async {
    final rows = await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw TransactionException(notFound);
    return rows.first;
  }

  Future<String> _name(DatabaseExecutor txn, int userId) async {
    final rows = await txn.rawQuery('''
      SELECT COALESCE(b.business_name, u.full_name) AS name
      FROM users u LEFT JOIN business_profiles b ON b.user_id = u.id
      WHERE u.id = ?
    ''', [userId]);
    return rows.isEmpty ? 'UMKM' : rows.first['name']! as String;
  }

  /// Mengurangi stok. Stok tidak dihapus walau habis (jumlah 0) agar
  /// riwayat order/barter yang merujuknya tetap ada.
  Future<StockItem> _takeStock(
    DatabaseExecutor txn,
    int stockId, {
    required int ownerId,
    required double quantity,
    required DateTime now,
  }) async {
    final stock = StockItem.fromMap(
      await _row(txn, 'stock_items', stockId, 'Stok sudah tidak ada.'),
    );
    if (stock.userId != ownerId) {
      throw const TransactionException('Stok bukan milik pihak tersebut.');
    }
    if (quantity > stock.quantity + 1e-9) {
      throw TransactionException(
        'Stok "${stock.name}" tinggal ${formatQuantity(stock.quantity)} '
        '${stock.unit.label}, tidak cukup untuk ${formatQuantity(quantity)}.',
      );
    }
    final remaining = (stock.quantity - quantity).clamp(0, double.infinity);
    await txn.update(
      'stock_items',
      {'quantity': remaining, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [stockId],
    );
    return stock;
  }

  Future<void> _giveStock(
    DatabaseExecutor txn,
    StockItem source, {
    required int toUserId,
    required double quantity,
    required int pricePerUnit,
    required String note,
    required DateTime now,
  }) => txn.insert(
    'stock_items',
    StockItem(
      userId: toUserId,
      name: source.name,
      category: source.category,
      quantity: quantity,
      unit: source.unit,
      pricePerUnit: pricePerUnit,
      expiryDate: source.expiryDate,
      notes: note,
      createdAt: now,
      updatedAt: now,
    ).toMap()
      ..remove('id'),
  );

  Future<void> _log(DatabaseExecutor txn, ActivityEntry entry) =>
      txn.insert('activity_log', entry.toMap()..remove('id'));
}

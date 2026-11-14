import 'package:sqflite/sqflite.dart';

import '../core/utils/geo.dart';
import '../model/auth_user.dart';
import '../model/food_category.dart';
import '../model/market_listing.dart';
import '../model/market_order.dart';
import '../model/promotion.dart';
import '../model/stock_item.dart';
import 'local_database.dart';

class MarketException implements Exception {
  const MarketException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data Pasar B2B.
///
/// Implementasi saat ini membaca SQLite lokal (promo dari akun lain di
/// perangkat yang sama). Ganti dengan implementasi backend agar marketplace
/// berjalan antar-perangkat tanpa mengubah UI.
abstract interface class MarketRepository {
  /// Promo aktif milik UMKM lain, terlihat oleh [viewer].
  Future<List<MarketListing>> listListings({
    required AuthUser viewer,
    required DateTime now,
  });

  /// Pengajuan pembelian yang melibatkan [userId] (sebagai pembeli/penjual).
  Future<List<MarketOrder>> listOrders(int userId);

  /// Membuat pengajuan pembelian. Melempar [MarketException] jika promo
  /// sudah berakhir atau jumlah melebihi yang tersedia.
  Future<MarketOrder> createOrder({
    required int promotionId,
    required int buyerId,
    required double quantity,
    String? note,
    required DateTime now,
  });

  /// Mengubah status pengajuan. Menerima pengajuan dicek ulang terhadap
  /// jumlah yang tersedia.
  Future<void> updateOrderStatus(
    int orderId,
    OrderStatus status, {
    required DateTime now,
  });
}

class SqliteMarketRepository implements MarketRepository {
  const SqliteMarketRepository();

  static const _reservedStatuses = "('accepted', 'completed')";

  @override
  Future<List<MarketListing>> listListings({
    required AuthUser viewer,
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.rawQuery('''
      SELECT p.*,
        s.name AS stock_name, s.category AS stock_category,
        s.unit AS stock_unit, s.expiry_date AS stock_expiry,
        u.full_name AS seller_full_name, u.address AS seller_address,
        u.latitude AS seller_lat, u.longitude AS seller_lng,
        b.business_name AS seller_business_name, b.whatsapp AS seller_whatsapp,
        COALESCE((
          SELECT SUM(o.quantity) FROM orders o
          WHERE o.promotion_id = p.id AND o.status IN $_reservedStatuses
        ), 0) AS reserved
      FROM promotions p
      JOIN stock_items s ON s.id = p.stock_id
      JOIN users u ON u.id = p.user_id
      LEFT JOIN business_profiles b ON b.user_id = p.user_id
      WHERE p.status = 'active' AND p.user_id != ?
      ORDER BY p.ends_at ASC
    ''', [viewer.id]);

    return rows
        .map((row) {
          final sellerLat = (row['seller_lat'] as num?)?.toDouble();
          final sellerLng = (row['seller_lng'] as num?)?.toDouble();
          final distance = viewer.hasLocation &&
                  sellerLat != null &&
                  sellerLng != null
              ? distanceKm(
                  viewer.latitude!, viewer.longitude!, sellerLat, sellerLng)
              : null;
          return MarketListing(
            promotion: Promotion.fromMap(row),
            stockName: row['stock_name']! as String,
            category: FoodCategory.parseList(row['stock_category'] as String?)
                    .firstOrNull ??
                FoodCategory.bahanKering,
            unit: StockUnit.fromName(row['stock_unit'] as String?),
            expiryDate: DateTime.parse(row['stock_expiry']! as String),
            sellerName: (row['seller_business_name'] ??
                row['seller_full_name'])! as String,
            sellerAddress: row['seller_address']! as String,
            sellerWhatsapp: row['seller_whatsapp'] as String?,
            distanceKm: distance,
            reservedQuantity: (row['reserved']! as num).toDouble(),
          );
        })
        .where((listing) => listing.promotion.isActiveAt(now))
        .toList();
  }

  @override
  Future<List<MarketOrder>> listOrders(int userId) async {
    final database = await LocalDatabase.instance.database;
    final rows = await database.rawQuery('''
      SELECT o.*, s.name AS stock_name, s.unit AS stock_unit,
        COALESCE(bb.business_name, bu.full_name) AS buyer_name,
        COALESCE(sb.business_name, su.full_name) AS seller_name
      FROM orders o
      JOIN promotions p ON p.id = o.promotion_id
      JOIN stock_items s ON s.id = p.stock_id
      JOIN users bu ON bu.id = o.buyer_id
      LEFT JOIN business_profiles bb ON bb.user_id = o.buyer_id
      JOIN users su ON su.id = o.seller_id
      LEFT JOIN business_profiles sb ON sb.user_id = o.seller_id
      WHERE o.buyer_id = ? OR o.seller_id = ?
      ORDER BY o.created_at DESC
    ''', [userId, userId]);
    return rows.map(MarketOrder.fromMap).toList();
  }

  @override
  Future<MarketOrder> createOrder({
    required int promotionId,
    required int buyerId,
    required double quantity,
    String? note,
    required DateTime now,
  }) async {
    if (quantity <= 0) {
      throw const MarketException('Jumlah harus lebih dari 0.');
    }
    final database = await LocalDatabase.instance.database;
    return database.transaction((txn) async {
      final promotion = await _activePromotion(txn, promotionId, now);
      if (promotion.userId == buyerId) {
        throw const MarketException('Tidak bisa membeli promo sendiri.');
      }
      final available = promotion.quantity - await _reserved(txn, promotionId);
      if (quantity > available) {
        throw MarketException(
          'Jumlah melebihi yang tersedia (${_fmt(available)}).',
        );
      }
      final order = MarketOrder(
        promotionId: promotionId,
        buyerId: buyerId,
        sellerId: promotion.userId,
        quantity: quantity,
        unitPrice: promotion.promoPrice,
        note: note,
        createdAt: now,
        updatedAt: now,
      );
      final id = await txn.insert('orders', order.toMap()..remove('id'));
      return order.copyWith(id: id);
    });
  }

  @override
  Future<void> updateOrderStatus(
    int orderId,
    OrderStatus status, {
    required DateTime now,
  }) async {
    final database = await LocalDatabase.instance.database;
    await database.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw const MarketException('Pengajuan tidak ditemukan.');
      }
      final order = MarketOrder.fromMap(rows.first);
      if (order.status != OrderStatus.pending) {
        throw MarketException(
          'Pengajuan sudah ${order.status.label.toLowerCase()}.',
        );
      }
      if (status == OrderStatus.accepted) {
        final promotion = await _activePromotion(txn, order.promotionId, now);
        final available =
            promotion.quantity - await _reserved(txn, order.promotionId);
        if (order.quantity > available) {
          throw MarketException(
            'Stok promo tidak cukup. Tersisa ${_fmt(available)}.',
          );
        }
      }
      await txn.update(
        'orders',
        {'status': status.name, 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  Future<Promotion> _activePromotion(
    DatabaseExecutor txn,
    int promotionId,
    DateTime now,
  ) async {
    final rows = await txn.query(
      'promotions',
      where: 'id = ?',
      whereArgs: [promotionId],
      limit: 1,
    );
    if (rows.isEmpty) throw const MarketException('Promo tidak ditemukan.');
    final promotion = Promotion.fromMap(rows.first);
    if (!promotion.isActiveAt(now)) {
      throw const MarketException('Promo sudah berakhir.');
    }
    return promotion;
  }

  Future<double> _reserved(DatabaseExecutor txn, int promotionId) async {
    final rows = await txn.rawQuery('''
      SELECT COALESCE(SUM(quantity), 0) AS total FROM orders
      WHERE promotion_id = ? AND status IN $_reservedStatuses
    ''', [promotionId]);
    return (rows.first['total']! as num).toDouble();
  }

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
}

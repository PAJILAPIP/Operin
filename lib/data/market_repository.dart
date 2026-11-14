import '../core/utils/db_codec.dart';
import '../core/utils/geo.dart';
import '../model/auth_user.dart';
import '../model/food_category.dart';
import '../model/market_listing.dart';
import '../model/market_order.dart';
import '../model/promotion.dart';
import '../model/stock_item.dart';
import 'supabase_support.dart';

class MarketException implements Exception {
  const MarketException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sumber data Pasar B2B.
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

/// Pasar B2B di Supabase. Validasi & penguncian stok dilakukan oleh fungsi
/// RPC `create_order` / `update_order_status` (lihat supabase/migrations).
class SupabaseMarketRepository implements MarketRepository {
  const SupabaseMarketRepository();

  @override
  Future<List<MarketListing>> listListings({
    required AuthUser viewer,
    required DateTime now,
  }) => guardDb(() async {
    final rows = await supabase
        .from('market_listings')
        .select()
        .neq('user_id', viewer.id!)
        .order('ends_at');
    return rows
        .map((row) => listingFromRow(row, viewer))
        .where((listing) => listing.promotion.isActiveAt(now))
        .toList();
  }, MarketException.new);

  @override
  Future<List<MarketOrder>> listOrders(int userId) => guardDb(() async {
    final rows = await supabase
        .from('order_details')
        .select()
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('created_at', ascending: false);
    return rows.map(MarketOrder.fromMap).toList();
  }, MarketException.new);

  @override
  Future<MarketOrder> createOrder({
    required int promotionId,
    required int buyerId,
    required double quantity,
    String? note,
    required DateTime now,
  }) => guardDb(() async {
    final row = await supabase.rpc(
      'create_order',
      params: {
        'p_promotion_id': promotionId,
        'p_quantity': quantity,
        'p_note': note,
      },
    );
    return MarketOrder.fromMap(Map<String, Object?>.from(row as Map));
  }, MarketException.new);

  @override
  Future<void> updateOrderStatus(
    int orderId,
    OrderStatus status, {
    required DateTime now,
  }) => guardDb(
    () => supabase.rpc(
      'update_order_status',
      params: {'p_order_id': orderId, 'p_status': status.name},
    ),
    MarketException.new,
  );

  /// Baris view `market_listings` → [MarketListing] (jarak dihitung lokal).
  static MarketListing listingFromRow(
    Map<String, Object?> row,
    AuthUser viewer,
  ) {
    final sellerLat = (row['seller_lat'] as num?)?.toDouble();
    final sellerLng = (row['seller_lng'] as num?)?.toDouble();
    final distance = viewer.hasLocation && sellerLat != null && sellerLng != null
        ? distanceKm(viewer.latitude!, viewer.longitude!, sellerLat, sellerLng)
        : null;
    return MarketListing(
      promotion: Promotion.fromMap(row),
      stockName: row['stock_name']! as String,
      category:
          FoodCategory.parseList(row['stock_category'] as String?).firstOrNull ??
          FoodCategory.bahanKering,
      unit: StockUnit.fromName(row['stock_unit'] as String?),
      expiryDate: decodeDate(row['stock_expiry']),
      sellerName:
          (row['seller_business_name'] ?? row['seller_full_name'])! as String,
      sellerAddress: row['seller_address']! as String,
      sellerWhatsapp: row['seller_whatsapp'] as String?,
      distanceKm: distance,
      reservedQuantity: (row['reserved'] as num? ?? 0).toDouble(),
    );
  }
}

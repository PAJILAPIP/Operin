import 'food_category.dart';
import 'promotion.dart';
import 'stock_item.dart';

/// Promo milik UMKM lain yang tampil di Pasar B2B (read model hasil join
/// promo + stok + penjual).
class MarketListing {
  const MarketListing({
    required this.promotion,
    required this.stockName,
    required this.category,
    required this.unit,
    required this.expiryDate,
    required this.sellerName,
    required this.sellerAddress,
    this.sellerWhatsapp,
    this.distanceKm,
    this.reservedQuantity = 0,
  });

  final Promotion promotion;
  final String stockName;
  final FoodCategory category;
  final StockUnit unit;
  final DateTime expiryDate;

  /// Nama usaha (atau nama pemilik jika profil usaha belum diisi).
  final String sellerName;
  final String sellerAddress;
  final String? sellerWhatsapp;

  /// Jarak dari lokasi pembeli; null jika salah satu belum punya koordinat.
  final double? distanceKm;

  /// Jumlah yang sudah dipesan dan diterima penjual.
  final double reservedQuantity;

  int get promotionId => promotion.id!;
  int get sellerId => promotion.userId;
  bool get isFlashSale => promotion.type == PromotionType.flashSale;

  double get availableQuantity =>
      (promotion.quantity - reservedQuantity).clamp(0, promotion.quantity);

  bool get isSoldOut => availableQuantity <= 0;
}

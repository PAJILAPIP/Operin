import 'stock_item.dart';

/// Stok UMKM lain yang dijual dengan harga normal di Katalog Pasar B2B
/// (read model hasil join stok + penjual).
class CatalogItem {
  const CatalogItem({
    required this.stock,
    required this.sellerName,
    required this.sellerAddress,
    this.sellerWhatsapp,
    this.distanceKm,
    this.reservedQuantity = 0,
  });

  final StockItem stock;

  /// Nama usaha (atau nama pemilik jika profil usaha belum diisi).
  final String sellerName;
  final String sellerAddress;
  final String? sellerWhatsapp;

  /// Jarak dari lokasi pembeli; null jika salah satu belum punya koordinat.
  final double? distanceKm;

  /// Jumlah yang sudah dijanjikan ke pembeli lain (pesanan diterima).
  final double reservedQuantity;

  int get stockId => stock.id!;
  int get sellerId => stock.userId;
  String get name => stock.name;
  int get price => stock.pricePerUnit;

  double get availableQuantity =>
      (stock.quantity - reservedQuantity).clamp(0, stock.quantity);

  bool get isSoldOut => availableQuantity <= 0;
}

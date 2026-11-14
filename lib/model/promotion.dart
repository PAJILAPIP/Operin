import '../core/utils/db_codec.dart';
/// Jenis promo penyelamatan stok.
enum PromotionType {
  /// Diskon berlaku sampai akhir hari kedaluwarsa.
  discount('Diskon'),

  /// Diskon besar dengan durasi singkat (beberapa jam).
  flashSale('Flash Sale');

  const PromotionType(this.label);

  final String label;

  static PromotionType fromName(String? name) =>
      name == flashSale.name ? flashSale : discount;
}

enum PromotionStatus {
  active,
  cancelled;

  static PromotionStatus fromName(String? name) =>
      name == cancelled.name ? cancelled : active;
}

/// Promo untuk satu stok. Harga disalin saat promo dibuat agar perubahan
/// stok berikutnya tidak mengubah promo yang sudah terbit.
class Promotion {
  const Promotion({
    this.id,
    required this.userId,
    required this.stockId,
    required this.type,
    required this.discountPercent,
    required this.originalPrice,
    required this.quantity,
    required this.createdAt,
    required this.endsAt,
    this.status = PromotionStatus.active,
  });

  static const int minDiscount = 5;
  static const int maxDiscount = 90;

  final int? id;
  final int userId;
  final int stockId;
  final PromotionType type;
  final int discountPercent;

  /// Harga normal per satuan (Rupiah).
  final int originalPrice;

  /// Jumlah yang ditawarkan (satuan mengikuti stok).
  final double quantity;
  final DateTime createdAt;
  final DateTime endsAt;
  final PromotionStatus status;

  int get promoPrice => priceAfterDiscount(originalPrice, discountPercent);

  bool isActiveAt(DateTime now) =>
      status == PromotionStatus.active && now.isBefore(endsAt);

  /// Harga setelah diskon, dibulatkan ke Rp100 terdekat.
  static int priceAfterDiscount(int price, int percent) {
    final raw = price * (100 - percent) / 100;
    return ((raw / 100).round() * 100).clamp(0, price);
  }

  factory Promotion.fromMap(Map<String, Object?> map) => Promotion(
    id: map['id'] as int?,
    userId: map['user_id']! as int,
    stockId: map['stock_id']! as int,
    type: PromotionType.fromName(map['type'] as String?),
    discountPercent: map['discount_percent']! as int,
    originalPrice: map['original_price']! as int,
    quantity: (map['quantity']! as num).toDouble(),
    createdAt: decodeTime(map['created_at']),
    endsAt: decodeTime(map['ends_at']),
    status: PromotionStatus.fromName(map['status'] as String?),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'stock_id': stockId,
    'type': type.name,
    'discount_percent': discountPercent,
    'original_price': originalPrice,
    'quantity': quantity,
    'created_at': encodeTime(createdAt),
    'ends_at': encodeTime(endsAt),
    'status': status.name,
  };

  Promotion copyWith({int? id, PromotionStatus? status}) => Promotion(
    id: id ?? this.id,
    userId: userId,
    stockId: stockId,
    type: type,
    discountPercent: discountPercent,
    originalPrice: originalPrice,
    quantity: quantity,
    createdAt: createdAt,
    endsAt: endsAt,
    status: status ?? this.status,
  );
}

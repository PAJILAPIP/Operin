import 'stock_item.dart';

/// Status pengajuan pembelian di Pasar B2B.
enum OrderStatus {
  pending('Menunggu'),
  accepted('Diterima'),
  rejected('Ditolak'),
  cancelled('Dibatalkan'),

  /// Diisi saat penyelesaian transaksi (Tahap 11).
  completed('Selesai');

  const OrderStatus(this.label);

  final String label;

  /// Status yang mengurangi jumlah promo yang tersedia.
  bool get reservesStock => this == accepted || this == completed;

  static OrderStatus fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return pending;
  }
}

/// Pengajuan pembelian dari pembeli ke penjual atas satu promo.
class MarketOrder {
  const MarketOrder({
    this.id,
    required this.promotionId,
    required this.buyerId,
    required this.sellerId,
    required this.quantity,
    required this.unitPrice,
    this.status = OrderStatus.pending,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.stockName,
    this.unit,
    this.buyerName,
    this.sellerName,
  });

  final int? id;
  final int promotionId;
  final int buyerId;
  final int sellerId;
  final double quantity;

  /// Harga promo per satuan saat pengajuan dibuat.
  final int unitPrice;
  final OrderStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Data tampilan hasil join (tidak disimpan di tabel orders).
  final String? stockName;
  final StockUnit? unit;
  final String? buyerName;
  final String? sellerName;

  int get totalPrice => (quantity * unitPrice).round();

  factory MarketOrder.fromMap(Map<String, Object?> map) => MarketOrder(
    id: map['id'] as int?,
    promotionId: map['promotion_id']! as int,
    buyerId: map['buyer_id']! as int,
    sellerId: map['seller_id']! as int,
    quantity: (map['quantity']! as num).toDouble(),
    unitPrice: map['unit_price']! as int,
    status: OrderStatus.fromName(map['status'] as String?),
    note: map['note'] as String?,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
    stockName: map['stock_name'] as String?,
    unit: map['stock_unit'] == null
        ? null
        : StockUnit.fromName(map['stock_unit'] as String?),
    buyerName: map['buyer_name'] as String?,
    sellerName: map['seller_name'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'promotion_id': promotionId,
    'buyer_id': buyerId,
    'seller_id': sellerId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'status': status.name,
    'note': note,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  MarketOrder copyWith({int? id, OrderStatus? status, DateTime? updatedAt}) =>
      MarketOrder(
        id: id ?? this.id,
        promotionId: promotionId,
        buyerId: buyerId,
        sellerId: sellerId,
        quantity: quantity,
        unitPrice: unitPrice,
        status: status ?? this.status,
        note: note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        stockName: stockName,
        unit: unit,
        buyerName: buyerName,
        sellerName: sellerName,
      );
}

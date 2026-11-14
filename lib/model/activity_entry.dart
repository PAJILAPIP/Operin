import '../core/utils/db_codec.dart';
import 'food_category.dart';
import 'stock_item.dart';

/// Jenis aktivitas yang tercatat saat transaksi diselesaikan.
enum ActivityKind {
  sale('Penjualan'),
  purchase('Pembelian'),
  barterOut('Barter keluar'),
  barterIn('Barter masuk'),
  donationOut('Disalurkan ke daur ulang'),
  donationIn('Diterima untuk daur ulang');

  const ActivityKind(this.label);

  final String label;

  /// Stok milik user yang keluar (diselamatkan dari terbuang).
  bool get isOutgoing => this == sale || this == barterOut || this == donationOut;

  static ActivityKind fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return sale;
  }
}

/// Satu baris riwayat aktivitas milik [userId]. Data stok & mitra disalin
/// (snapshot) agar riwayat tetap utuh walau stok diubah/dihapus.
class ActivityEntry {
  const ActivityEntry({
    this.id,
    required this.userId,
    required this.kind,
    required this.counterpartId,
    required this.counterpartName,
    required this.stockName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.amount,
    required this.savedValue,
    required this.weightKg,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
  });

  final int? id;
  final int userId;
  final ActivityKind kind;
  final int counterpartId;
  final String counterpartName;
  final String stockName;
  final FoodCategory category;
  final double quantity;
  final StockUnit unit;

  /// Uang yang berpindah (Rupiah). Penjualan = diterima, pembelian = dibayar,
  /// barter/donasi = 0.
  final int amount;

  /// Nilai yang diselamatkan dari kerugian (Rupiah):
  /// - penjualan: pemasukan dari stok yang hampir terbuang
  /// - pembelian: penghematan dari harga promo
  /// - barter keluar: nilai stok yang tertukar
  /// - lainnya: 0 (agar tidak dihitung ganda)
  final int savedValue;

  /// Perkiraan berat bahan (kg).
  final double weightKg;

  /// 'order' atau 'barter'.
  final String referenceType;
  final int referenceId;
  final DateTime createdAt;

  factory ActivityEntry.fromMap(Map<String, Object?> map) => ActivityEntry(
    id: map['id'] as int?,
    userId: map['user_id']! as int,
    kind: ActivityKind.fromName(map['kind'] as String?),
    counterpartId: map['counterpart_id']! as int,
    counterpartName: map['counterpart_name']! as String,
    stockName: map['stock_name']! as String,
    category: FoodCategory.parseList(map['category'] as String?).firstOrNull ??
        FoodCategory.bahanKering,
    quantity: (map['quantity']! as num).toDouble(),
    unit: StockUnit.fromName(map['unit'] as String?),
    amount: map['amount']! as int,
    savedValue: map['saved_value']! as int,
    weightKg: (map['weight_kg']! as num).toDouble(),
    referenceType: map['reference_type']! as String,
    referenceId: map['reference_id']! as int,
    createdAt: decodeTime(map['created_at']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'kind': kind.name,
    'counterpart_id': counterpartId,
    'counterpart_name': counterpartName,
    'stock_name': stockName,
    'category': category.name,
    'quantity': quantity,
    'unit': unit.name,
    'amount': amount,
    'saved_value': savedValue,
    'weight_kg': weightKg,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'created_at': encodeTime(createdAt),
  };
}

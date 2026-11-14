import 'food_category.dart';

/// Satuan jumlah stok.
enum StockUnit {
  kg('kg'),
  gram('gram'),
  liter('liter'),
  pcs('pcs'),
  pack('pack'),
  ikat('ikat'),
  porsi('porsi');

  const StockUnit(this.label);

  final String label;

  static StockUnit fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return pcs;
  }
}

/// Status kesegaran stok berdasarkan sisa hari sebelum kedaluwarsa.
enum StockStatus {
  expired('Kedaluwarsa'),
  critical('Kritis'),
  soon('Segera'),
  fresh('Aman');

  const StockStatus(this.label);

  final String label;

  /// Kedaluwarsa atau kritis → perlu tindakan segera.
  bool get needsAction => this == expired || this == critical;
}

class StockItem {
  const StockItem({
    this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.expiryDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Batas hari untuk status [StockStatus.soon].
  static const int soonDays = 7;

  /// Batas default status [StockStatus.critical] jika user belum mengatur
  /// notifikasi di profil usaha.
  static const int defaultCriticalDays = 2;

  final int? id;
  final int userId;
  final String name;
  final FoodCategory category;
  final double quantity;
  final StockUnit unit;

  /// Harga per satuan dalam Rupiah.
  final int pricePerUnit;

  /// Hanya tanggal yang dipakai (jam diabaikan).
  final DateTime expiryDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalValue => (quantity * pricePerUnit).round();

  /// Sisa hari sampai kedaluwarsa relatif terhadap [now]. Negatif = lewat.
  int daysUntilExpiry(DateTime now) {
    final expiry = DateTime.utc(expiryDate.year, expiryDate.month, expiryDate.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return expiry.difference(today).inDays;
  }

  StockStatus statusAt(
    DateTime now, {
    int criticalDays = defaultCriticalDays,
  }) {
    final days = daysUntilExpiry(now);
    if (days < 0) return StockStatus.expired;
    if (days <= criticalDays) return StockStatus.critical;
    if (days <= soonDays) return StockStatus.soon;
    return StockStatus.fresh;
  }

  /// Label singkat sisa waktu: "H-3", "Hari ini", "Lewat 2 hari".
  String expiryLabel(DateTime now) {
    final days = daysUntilExpiry(now);
    if (days < 0) return 'Lewat ${-days} hari';
    if (days == 0) return 'Hari ini';
    return 'H-$days';
  }

  factory StockItem.fromMap(Map<String, Object?> map) => StockItem(
    id: map['id'] as int?,
    userId: map['user_id']! as int,
    name: map['name']! as String,
    category: FoodCategory.parseList(map['category'] as String?).firstOrNull ??
        FoodCategory.bahanKering,
    quantity: (map['quantity']! as num).toDouble(),
    unit: StockUnit.fromName(map['unit'] as String?),
    pricePerUnit: map['price_per_unit']! as int,
    expiryDate: DateTime.parse(map['expiry_date']! as String),
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['created_at']! as String),
    updatedAt: DateTime.parse(map['updated_at']! as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'category': category.name,
    'quantity': quantity,
    'unit': unit.name,
    'price_per_unit': pricePerUnit,
    'expiry_date': _dateOnly(expiryDate),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  StockItem copyWith({
    int? id,
    String? name,
    FoodCategory? category,
    double? quantity,
    StockUnit? unit,
    int? pricePerUnit,
    DateTime? expiryDate,
    String? notes,
    DateTime? updatedAt,
  }) => StockItem(
    id: id ?? this.id,
    userId: userId,
    name: name ?? this.name,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    pricePerUnit: pricePerUnit ?? this.pricePerUnit,
    expiryDate: expiryDate ?? this.expiryDate,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// "2026-11-14" — disimpan sebagai teks agar bisa diurutkan di SQL.
  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

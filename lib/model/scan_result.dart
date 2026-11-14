import 'food_category.dart';
import 'stock_item.dart';

/// Grade kualitas bahan hasil analisis AI.
enum ScanQuality {
  gradeA('Grade A', 'Segar, kualitas terbaik'),
  gradeB('Grade B', 'Layak, ada sedikit cacat'),
  gradeC('Grade C', 'Segera olah / jual cepat'),
  rejected('Tidak Layak', 'Rusak atau busuk');

  const ScanQuality(this.label, this.description);

  final String label;
  final String description;

  /// Bahan yang masih bisa dijual/dipakai sebagai stok.
  bool get isUsable => this != rejected;

  /// Menerima "A", "B", "C", "rusak", "grade a", dll. Tidak dikenal → C.
  static ScanQuality parse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    final code = value.replaceFirst('grade', '').trim();
    if (code == 'a') return gradeA;
    if (code == 'b') return gradeB;
    if (code == 'c') return gradeC;
    if (code.contains('rusak') ||
        code.contains('reject') ||
        code.contains('busuk') ||
        code.contains('tidak') ||
        code == 'd') {
      return rejected;
    }
    return gradeC;
  }
}

/// Asal tanggal kedaluwarsa: dibaca dari label kemasan atau perkiraan AI.
enum ExpirySource { label, estimate }

/// Satu bahan yang terdeteksi pada foto.
class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.category,
    required this.quality,
    required this.freshnessScore,
    required this.unit,
    this.quantity,
    this.expiryDate,
    this.expirySource,
    this.reason,
    this.recommendation,
  });

  final String name;
  final FoodCategory category;
  final ScanQuality quality;

  /// 0–100, makin tinggi makin segar.
  final int freshnessScore;
  final double? quantity;
  final StockUnit unit;

  /// Tanggal kedaluwarsa efektif (dari label, atau hari ini + perkiraan
  /// umur simpan). Null jika AI tidak bisa menentukan.
  final DateTime? expiryDate;
  final ExpirySource? expirySource;

  /// Alasan penilaian (warna, memar, jamur, label, dll).
  final String? reason;
  final String? recommendation;

  /// Mengurai satu objek item dari JSON jawaban AI. [today] dipakai untuk
  /// menghitung tanggal dari `shelf_life_days`.
  factory ScannedItem.fromAiJson(Map<String, dynamic> json, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    DateTime? expiry;
    ExpirySource? source;

    final labelDate = _parseDate(json['expiry_date']);
    if (labelDate != null) {
      expiry = labelDate;
      source = ExpirySource.label;
    } else {
      final days = _toNum(json['shelf_life_days'])?.round();
      if (days != null && days >= 0) {
        expiry = day.add(Duration(days: days));
        source = ExpirySource.estimate;
      }
    }

    final quantity = _toNum(json['quantity'])?.toDouble();
    final name = json['name']?.toString().trim();

    return ScannedItem(
      name: (name == null || name.isEmpty) ? 'Bahan tidak dikenal' : name,
      category: _parseCategory(json['category']),
      quality: ScanQuality.parse(json['quality']),
      freshnessScore:
          (_toNum(json['freshness_score'])?.round() ?? 0).clamp(0, 100),
      quantity: quantity != null && quantity > 0 ? quantity : null,
      unit: _parseUnit(json['unit']),
      expiryDate: expiry,
      expirySource: source,
      reason: _text(json['reason']),
      recommendation: _text(json['recommendation']),
    );
  }

  /// Draf stok untuk form "Tambah Stok" (harga tetap diisi user).
  StockDraft toDraft() {
    final note = [
      'Scan AI: ${quality.label} (kesegaran $freshnessScore%)',
      ?reason,
    ].join(' · ');
    return StockDraft(
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      expiryDate: expiryDate,
      notes: note,
    );
  }

  static String? _text(Object? raw) {
    final value = raw?.toString().trim();
    return (value == null || value.isEmpty || value == 'null') ? null : value;
  }

  static num? _toNum(Object? raw) {
    if (raw is num) return raw;
    if (raw is String) return num.tryParse(raw.replaceAll(',', '.').trim());
    return null;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String) return null;
    final match = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final dayOfMonth = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || dayOfMonth < 1 || dayOfMonth > 31) {
      return null;
    }
    return DateTime(year, month, dayOfMonth);
  }

  static FoodCategory _parseCategory(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final category in FoodCategory.values) {
      if (category.name.toLowerCase() == value ||
          category.label.toLowerCase() == value) {
        return category;
      }
    }
    if (value.contains('buah') || value.contains('fruit')) {
      return FoodCategory.buah;
    }
    if (value.contains('sayur') || value.contains('veg')) {
      return FoodCategory.sayur;
    }
    if (value.contains('daging') || value.contains('ikan')) {
      return FoodCategory.dagingIkan;
    }
    if (value.contains('susu') || value.contains('telur')) {
      return FoodCategory.susuOlahan;
    }
    if (value.contains('roti') || value.contains('kue')) {
      return FoodCategory.roti;
    }
    if (value.contains('jadi') || value.contains('masak')) {
      return FoodCategory.makananJadi;
    }
    return FoodCategory.bahanKering;
  }

  static StockUnit _parseUnit(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final unit in StockUnit.values) {
      if (unit.name == value || unit.label == value) return unit;
    }
    if (value == 'g' || value == 'gr') return StockUnit.gram;
    if (value == 'l' || value == 'ltr') return StockUnit.liter;
    if (value.contains('buah') || value.contains('biji')) return StockUnit.pcs;
    return StockUnit.pcs;
  }
}

/// Hasil analisis satu foto.
class ScanResult {
  const ScanResult({
    required this.items,
    required this.isFood,
    this.summary,
  });

  final List<ScannedItem> items;

  /// False jika foto tidak berisi bahan makanan.
  final bool isFood;
  final String? summary;

  factory ScanResult.fromAiJson(Map<String, dynamic> json, DateTime today) {
    final rawItems = json['items'];
    final items = <ScannedItem>[
      if (rawItems is List)
        for (final item in rawItems)
          if (item is Map) ScannedItem.fromAiJson(item.cast(), today),
    ];
    final isFood = json['is_food'];
    return ScanResult(
      items: items,
      isFood: isFood is bool ? isFood : items.isNotEmpty,
      summary: ScannedItem._text(json['summary']),
    );
  }
}

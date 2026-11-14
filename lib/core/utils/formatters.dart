/// Helper format tampilan (Rupiah, jumlah, tanggal) tanpa package tambahan.
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// 15450000 → "Rp 15.450.000"
String formatRupiah(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}Rp $buffer';
}

/// 25.0 → "25", 2.5 → "2,5", 0.125 → "0,13"
String formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceAll('.', ',');
}

/// 2026-11-14 → "14 Nov 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Mengurai input jumlah "2,5" / "2.5" → 2.5. Null jika tidak valid.
double? parseQuantity(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));

/// Mengurai input harga "15.000" / "Rp 15000" → 15000. Null jika kosong.
int? parseRupiah(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

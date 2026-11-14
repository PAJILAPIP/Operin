/// Konversi nilai antara model Dart dan kolom database (Supabase/Postgres).
///
/// Timestamp disimpan sebagai `timestamptz` (UTC) dan ditampilkan dalam
/// waktu lokal; tanggal kedaluwarsa disimpan sebagai `date` (tanpa jam) agar
/// tidak bergeser hari karena zona waktu.
library;

DateTime decodeTime(Object? value) => DateTime.parse(value! as String).toLocal();

String encodeTime(DateTime time) => time.toUtc().toIso8601String();

/// "2026-11-17" → tengah malam waktu lokal.
DateTime decodeDate(Object? value) {
  final text = value! as String;
  final date = DateTime.parse(text.length >= 10 ? text.substring(0, 10) : text);
  return DateTime(date.year, date.month, date.day);
}

String encodeDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

bool decodeBool(Object? value) => value is bool ? value : value == 1;

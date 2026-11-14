import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client Supabase global (diinisialisasi di `main.dart`).
SupabaseClient get supabase => Supabase.instance.client;

const networkErrorMessage =
    'Tidak dapat terhubung ke server. Periksa koneksi internet.';

/// Gagal membaca/menulis data di server (koneksi, sesi, atau izin).
class DataException implements Exception {
  const DataException(this.message);

  final String message;

  @override
  String toString() => 'DataException: $message';
}

/// Pesan yang ramah untuk error database. Error dari `raise exception` di
/// fungsi RPC (kode P0001) sudah berbahasa Indonesia dan dipakai apa adanya.
@visibleForTesting
String friendlyDbMessage(PostgrestException error) {
  final code = error.code ?? '';
  if (code == 'P0001') return error.message;
  if (code == 'PGRST301' || error.message.toLowerCase().contains('jwt')) {
    return 'Sesi berakhir. Silakan login ulang.';
  }
  if (code == '42501') return 'Akses ditolak.';
  if (code == '23505') return 'Data sudah ada.';
  return 'Terjadi kesalahan server. Coba lagi.';
}

/// Menjalankan [action] dan mengubah error Supabase/jaringan menjadi
/// exception domain lewat [wrap] (mis. `MarketException.new`).
Future<T> guardDb<T>(
  Future<T> Function() action,
  Exception Function(String message) wrap,
) async {
  try {
    return await action();
  } on PostgrestException catch (error) {
    debugPrint('Supabase error ${error.code}: ${error.message}');
    throw wrap(friendlyDbMessage(error));
  } on http.ClientException catch (error) {
    debugPrint('Jaringan gagal: $error');
    throw wrap(networkErrorMessage);
  } on TimeoutException {
    throw wrap(networkErrorMessage);
  }
}

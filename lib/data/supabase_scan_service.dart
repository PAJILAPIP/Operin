import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/db_codec.dart';
import '../model/scan_result.dart';
import 'scan_service.dart';
import 'supabase_support.dart';

/// Scan AI lewat Edge Function `scan-food` di Supabase. Key Groq tersimpan
/// sebagai secret di server, sehingga tidak ikut di APK.
class SupabaseScanService implements StockScanService {
  const SupabaseScanService({this.functionName = 'scan-food'});

  final String functionName;

  @override
  bool get isConfigured => SupabaseConfig.isConfigured;

  @override
  Future<ScanResult> analyze(
    Uint8List imageBytes, {
    required String mimeType,
    required DateTime today,
  }) async {
    final FunctionResponse response;
    try {
      response = await supabase.functions
          .invoke(
            functionName,
            body: {
              'image': base64Encode(imageBytes),
              'mimeType': mimeType,
              'today': encodeDate(today),
            },
          )
          .timeout(const Duration(seconds: 90));
    } on FunctionException catch (error) {
      debugPrint('scan-food ${error.status}: ${error.details}');
      throw ScanException(functionErrorMessage(error.status, error.details));
    } on TimeoutException {
      throw const ScanException(
        'Analisis terlalu lama. Periksa koneksi lalu coba lagi.',
      );
    } on http.ClientException {
      throw const ScanException(networkErrorMessage);
    }

    return parseResponse(response.data, today);
  }

  /// Jawaban Groq (chat completions) dari Edge Function → [ScanResult].
  @visibleForTesting
  static ScanResult parseResponse(Object? data, DateTime today) {
    final body = data is String ? data : jsonEncode(data);
    final text = AiScanService.extractOutputText(body);
    final json = AiScanService.parseJsonObject(text);
    if (json == null) {
      debugPrint('Jawaban scan-food bukan JSON: $text');
      throw const ScanException(
        'Jawaban AI tidak dapat dibaca. Coba foto ulang.',
      );
    }
    return ScanResult.fromAiJson(json, today);
  }

  /// Status HTTP dari Edge Function → pesan untuk user.
  @visibleForTesting
  static String functionErrorMessage(int status, Object? details) {
    final serverMessage = details is Map ? details['error'] : null;
    if (serverMessage is String && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    return switch (status) {
      401 => 'Sesi berakhir. Silakan login ulang.',
      404 => 'Layanan scan belum di-deploy di server (scan-food).',
      413 => 'Ukuran foto terlalu besar.',
      429 => 'Batas pemakaian AI tercapai. Coba lagi beberapa saat.',
      _ => 'Layanan AI sedang bermasalah. Coba lagi nanti.',
    };
  }
}

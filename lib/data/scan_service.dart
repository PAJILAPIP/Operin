import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../model/scan_result.dart';

/// Gagal menganalisis foto; [message] siap ditampilkan ke user.
class ScanException implements Exception {
  const ScanException(this.message);

  final String message;

  @override
  String toString() => 'ScanException: $message';
}

/// Analisis foto bahan baku dengan AI. Implementasi bisa diganti (mis. lewat
/// backend proxy nanti) tanpa mengubah UI.
abstract class StockScanService {
  /// False jika layanan belum dikonfigurasi (mis. API key kosong).
  bool get isConfigured;

  Future<ScanResult> analyze(
    Uint8List imageBytes, {
    required String mimeType,
    required DateTime today,
  });
}

/// Penyedia AI vision yang didukung.
enum AiProvider {
  /// Groq (console.groq.com, key `gsk_...`), API chat completions.
  groq(
    label: 'Groq',
    console: 'console.groq.com',
    keyPrefix: 'gsk_',
    defaultModel: 'qwen/qwen3.8-27b',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
  ),

  /// xAI Grok (console.x.ai, key `xai-...`), Responses API.
  xai(
    label: 'Grok',
    console: 'console.x.ai',
    keyPrefix: 'xai-',
    defaultModel: 'grok-4.7',
    endpoint: 'https://api.x.ai/v1/responses',
  );

  const AiProvider({
    required this.label,
    required this.console,
    required this.keyPrefix,
    required this.defaultModel,
    required this.endpoint,
  });

  final String label;
  final String console;
  final String keyPrefix;
  final String defaultModel;
  final String endpoint;

  /// Menebak penyedia dari awalan key; null jika tidak dikenal.
  static AiProvider? fromKey(String key) {
    for (final provider in values) {
      if (key.startsWith(provider.keyPrefix)) return provider;
    }
    return null;
  }
}

/// Konfigurasi AI scanner dari `--dart-define` / `--dart-define-from-file`:
///
/// ```
/// flutter run --dart-define-from-file=env.json
/// // env.json: {"GROQ_API_KEY": "gsk_..."}  atau  {"GROK_API_KEY": "xai-..."}
/// ```
///
/// Opsional: `AI_MODEL` untuk mengganti model default penyedia.
///
/// Catatan keamanan: key yang ditanam di aplikasi bisa diekstrak dari APK.
/// Untuk rilis produksi, panggilan ini dipindah ke backend (Tahap 12).
class AiScanConfig {
  const AiScanConfig({
    required this.provider,
    required this.apiKey,
    this.modelOverride,
    this.timeout = const Duration(seconds: 90),
  });

  /// Groq diutamakan jika `GROQ_API_KEY` diisi; key `gsk_` yang terlanjur
  /// diisi di `GROK_API_KEY` juga otomatis memakai Groq.
  factory AiScanConfig.fromEnvironment() {
    const groqKey = String.fromEnvironment('GROQ_API_KEY');
    const grokKey = String.fromEnvironment('GROK_API_KEY');
    const model = String.fromEnvironment('AI_MODEL');
    // Urutan: GROQ_API_KEY → GROK_API_KEY → key bawaan prototype.
    final key = cleanKey(groqKey).isNotEmpty
        ? groqKey
        : cleanKey(grokKey).isNotEmpty
        ? grokKey
        : prototypeApiKey;
    final provider = cleanKey(groqKey).isNotEmpty
        ? AiProvider.groq
        : AiProvider.fromKey(cleanKey(key)) ?? AiProvider.xai;
    return AiScanConfig(
      provider: provider,
      apiKey: key,
      modelOverride: model.isEmpty ? null : model,
    );
  }

  /// Key Groq bawaan PROTOTYPE agar APK langsung bisa scan tanpa
  /// `--dart-define`. Key ini ikut terbaca siapa pun yang punya kode/APK:
  /// ganti (regenerate) di console.groq.com dan pindahkan ke backend sebelum
  /// rilis (Tahap 12).
  static const String prototypeApiKey =
      'GROQ_KEY_DIHAPUS';

  final AiProvider provider;
  final String apiKey;
  /// Model selain default penyedia (dari AI_MODEL).
  final String? modelOverride;
  final Duration timeout;

  String get model => modelOverride ?? provider.defaultModel;

  /// Key tanpa spasi dan tanda kutip pembungkus.
  String get cleanApiKey => cleanKey(apiKey);

  /// Membuang spasi dan tanda kutip yang sering ikut tersalin dari
  /// launch.json / terminal.
  static String cleanKey(String raw) {
    var key = raw.trim();
    while (key.length >= 2 &&
        (key.startsWith('"') || key.startsWith("'")) &&
        (key.endsWith('"') || key.endsWith("'"))) {
      key = key.substring(1, key.length - 1).trim();
    }
    return key;
  }
}

/// Analisis gambar lewat Groq (chat completions) atau xAI Grok (Responses
/// API), dengan instruksi & format JSON yang sama.
class AiScanService implements StockScanService {
  AiScanService({AiScanConfig? config, this.client})
    : config = config ?? AiScanConfig.fromEnvironment();

  final AiScanConfig config;

  /// Client HTTP opsional (untuk test). Null = buat client per permintaan.
  final http.Client? client;

  @override
  bool get isConfigured => config.cleanApiKey.isNotEmpty;

  @visibleForTesting
  static String instructions(DateTime today) {
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return '''
Kamu adalah inspektur kualitas bahan baku untuk UMKM kuliner di Indonesia.
Tanggal hari ini: $date.

Analisis foto. Untuk SETIAP jenis bahan makanan yang terlihat (buah, sayur,
daging, ikan, roti, susu, bahan kering, makanan kemasan, makanan jadi):
- Nilai kualitas: "A" (segar, mulus), "B" (layak, cacat kecil), "C" (harus
  segera diolah/dijual), atau "rusak" (busuk, berjamur, tidak layak konsumsi).
- freshness_score 0-100.
- Jika ada tanggal kedaluwarsa TERCETAK dan terbaca di kemasan, isi
  expiry_date (YYYY-MM-DD). Jangan menebak tanggal label.
- Jika tidak ada label, perkirakan shelf_life_days: sisa hari layak pakai
  pada suhu ruang mulai hari ini (0 jika sudah tidak layak).
- Perkirakan jumlah yang terlihat beserta satuannya bila memungkinkan.

Balas HANYA dengan JSON valid (tanpa markdown) dengan format:
{
  "is_food": true,
  "summary": "ringkasan singkat bahasa Indonesia",
  "items": [
    {
      "name": "nama bahan bahasa Indonesia, mis. Tomat",
      "category": "sayur|buah|roti|dagingIkan|susuOlahan|bahanKering|makananJadi",
      "quality": "A|B|C|rusak",
      "freshness_score": 0,
      "quantity": 0,
      "unit": "kg|gram|liter|pcs|pack|ikat|porsi",
      "expiry_date": null,
      "shelf_life_days": null,
      "reason": "alasan singkat penilaian (warna, memar, jamur, label)",
      "recommendation": "saran singkat: jual normal / diskon / olah hari ini / salurkan ke daur ulang"
    }
  ]
}
Jika foto bukan bahan makanan: {"is_food": false, "summary": "...", "items": []}.
''';
  }

  static const _task = 'Analisis kualitas bahan baku pada foto ini.';

  /// Body permintaan sesuai format API penyedia.
  @visibleForTesting
  Map<String, Object?> buildRequest(String dataUrl, DateTime today) {
    switch (config.provider) {
      case AiProvider.groq:
        return {
          'model': config.model,
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
          // Instruksi digabung di pesan user: contoh vision Groq hanya
          // memakai pesan user.
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': '${instructions(today)}\n$_task'},
                {
                  'type': 'image_url',
                  'image_url': {'url': dataUrl},
                },
              ],
            },
          ],
        };
      case AiProvider.xai:
        return {
          'model': config.model,
          // Jangan simpan riwayat di server (disarankan untuk input gambar).
          'store': false,
          'input': [
            {'role': 'system', 'content': instructions(today)},
            {
              'role': 'user',
              'content': [
                {'type': 'input_image', 'image_url': dataUrl, 'detail': 'high'},
                {'type': 'input_text', 'text': _task},
              ],
            },
          ],
        };
    }
  }

  @override
  Future<ScanResult> analyze(
    Uint8List imageBytes, {
    required String mimeType,
    required DateTime today,
  }) async {
    final provider = config.provider;
    if (!isConfigured) {
      throw const ScanException(
        'API key AI belum diatur. Isi GROQ_API_KEY di env.json lalu jalankan '
        'dengan --dart-define-from-file=env.json',
      );
    }
    final apiKey = config.cleanApiKey;
    final keyProvider = AiProvider.fromKey(apiKey);
    if (keyProvider != null && keyProvider != provider) {
      throw ScanException(
        'Key ${keyProvider.label} (${keyProvider.keyPrefix}...) dipakai untuk '
        '${provider.label}. Gunakan key dari ${provider.console}.',
      );
    }

    final dataUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
    final body = jsonEncode(buildRequest(dataUrl, today));

    final httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .post(
            Uri.parse(provider.endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(config.timeout);
    } on TimeoutException {
      throw const ScanException(
        'Analisis terlalu lama. Periksa koneksi lalu coba lagi.',
      );
    } on http.ClientException catch (error) {
      debugPrint('${provider.label} request gagal: $error');
      throw const ScanException(
        'Tidak dapat terhubung ke layanan AI. Periksa koneksi internet.',
      );
    } finally {
      if (client == null) httpClient.close();
    }

    final status = response.statusCode;
    if (status != 200) {
      debugPrint('${provider.label} $status: ${response.body}');
      final invalidKey = 'API key ${provider.label} tidak valid. Pastikan key '
          'dari ${provider.console} (diawali ${provider.keyPrefix}).';
      // xAI memakai 400 (bukan 401) untuk key yang salah.
      if ((status == 400 || status == 401 || status == 403) &&
          response.body.toLowerCase().contains('api key')) {
        throw ScanException(invalidKey);
      }
      throw ScanException(switch (status) {
        401 || 403 => invalidKey,
        404 => 'Model "${config.model}" tidak ditemukan di ${provider.label}.',
        413 => 'Ukuran foto terlalu besar.',
        429 => 'Batas pemakaian AI tercapai. Coba lagi beberapa saat.',
        >= 500 => 'Layanan AI sedang bermasalah. Coba lagi nanti.',
        _ => 'Analisis gagal (kode $status).',
      });
    }

    final text = extractOutputText(utf8.decode(response.bodyBytes));
    final json = parseJsonObject(text);
    if (json == null) {
      debugPrint('Jawaban ${provider.label} bukan JSON: $text');
      throw const ScanException(
        'Jawaban AI tidak dapat dibaca. Coba foto ulang.',
      );
    }
    return ScanResult.fromAiJson(json, today);
  }

  /// Mengambil teks jawaban dari respons Responses API (xAI) atau chat
  /// completions (Groq).
  @visibleForTesting
  static String extractOutputText(String responseBody) {
    final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException {
      return responseBody;
    }
    if (decoded is! Map) return responseBody;

    final direct = decoded['output_text'];
    if (direct is String && direct.isNotEmpty) return direct;

    final buffer = StringBuffer();
    final output = decoded['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map || item['type'] != 'message') continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content) {
          if (part is Map && part['type'] == 'output_text') {
            buffer.write(part['text'] ?? '');
          }
        }
      }
    }
    final choices = decoded['choices'];
    if (buffer.isEmpty && choices is List && choices.isNotEmpty) {
      final message = (choices.first as Map?)?['message'];
      if (message is Map && message['content'] is String) {
        buffer.write(message['content']);
      }
    }
    return buffer.toString();
  }

  /// Mengurai objek JSON dari teks, toleran terhadap pagar ```json dan blok
  /// penalaran `<think>...</think>` (model Qwen).
  @visibleForTesting
  static Map<String, dynamic>? parseJsonObject(String text) {
    final cleaned = text.replaceAll(
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
      '',
    );
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

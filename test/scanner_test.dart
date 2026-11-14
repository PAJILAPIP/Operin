import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:operin/data/scan_service.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/scan_result.dart';
import 'package:operin/model/stock_item.dart';

final _today = DateTime(2026, 11, 14, 10);
final _image = Uint8List.fromList([1, 2, 3, 4]);

const _aiJson = {
  'is_food': true,
  'summary': '2 bahan terdeteksi',
  'items': [
    {
      'name': 'Tomat',
      'category': 'sayur',
      'quality': 'B',
      'freshness_score': 72,
      'quantity': 2.5,
      'unit': 'kg',
      'expiry_date': null,
      'shelf_life_days': 3,
      'reason': 'Sedikit lunak',
      'recommendation': 'Jual dengan diskon',
    },
    {
      'name': 'Susu UHT',
      'category': 'Susu & Olahan',
      'quality': 'Grade A',
      'freshness_score': '95',
      'quantity': 12,
      'unit': 'pcs',
      'expiry_date': '2027-01-20',
      'shelf_life_days': 60,
    },
  ],
};

/// Respons Responses API xAI dengan [text] sebagai output_text.
String _responsesBody(String text) => jsonEncode({
  'id': 'resp_1',
  'output': [
    {'type': 'reasoning', 'summary': []},
    {
      'type': 'message',
      'role': 'assistant',
      'content': [
        {'type': 'output_text', 'text': text},
      ],
    },
  ],
});

void main() {
  group('ScanResult.fromAiJson', () {
    test('mengurai item, grade, kategori, dan tanggal', () {
      final result = ScanResult.fromAiJson(_aiJson, _today);
      expect(result.isFood, isTrue);
      expect(result.items, hasLength(2));

      final tomat = result.items[0];
      expect(tomat.category, FoodCategory.sayur);
      expect(tomat.quality, ScanQuality.gradeB);
      expect(tomat.unit, StockUnit.kg);
      expect(tomat.quantity, 2.5);
      // Tanpa label → hari ini + perkiraan umur simpan.
      expect(tomat.expiryDate, DateTime(2026, 11, 17));
      expect(tomat.expirySource, ExpirySource.estimate);

      final susu = result.items[1];
      expect(susu.category, FoodCategory.susuOlahan); // dari label kategori
      expect(susu.quality, ScanQuality.gradeA);
      expect(susu.freshnessScore, 95); // angka dalam string
      // Tanggal dari label lebih diutamakan daripada perkiraan.
      expect(susu.expiryDate, DateTime(2027, 1, 20));
      expect(susu.expirySource, ExpirySource.label);
    });

    test('nilai tak dikenal memakai fallback aman', () {
      final item = ScannedItem.fromAiJson({
        'name': '',
        'category': 'fruit',
        'quality': 'busuk',
        'freshness_score': 140,
        'unit': 'buah',
        'quantity': 0,
        'expiry_date': 'tidak terbaca',
      }, _today);
      expect(item.name, 'Bahan tidak dikenal');
      expect(item.category, FoodCategory.buah);
      expect(item.quality, ScanQuality.rejected);
      expect(item.freshnessScore, 100);
      expect(item.unit, StockUnit.pcs);
      expect(item.quantity, isNull);
      expect(item.expiryDate, isNull);
    });

    test('draf stok membawa data hasil scan', () {
      final draft = ScanResult.fromAiJson(_aiJson, _today).items.first
          .toDraft();
      expect(draft.name, 'Tomat');
      expect(draft.category, FoodCategory.sayur);
      expect(draft.quantity, 2.5);
      expect(draft.unit, StockUnit.kg);
      expect(draft.expiryDate, DateTime(2026, 11, 17));
      expect(draft.notes, 'Scan AI: Grade B (kesegaran 72%) · Sedikit lunak');
    });

    test('bukan makanan', () {
      final result = ScanResult.fromAiJson(
        {'is_food': false, 'summary': 'Foto berisi laptop', 'items': []},
        _today,
      );
      expect(result.isFood, isFalse);
      expect(result.items, isEmpty);
    });
  });

  group('AiScanService (xAI Grok)', () {
    const config = AiScanConfig(
      provider: AiProvider.xai,
      apiKey: 'xai-test',
      modelOverride: 'grok-test',
    );

    test('mengirim gambar base64 ke Responses API dan mengurai JSON',
        () async {
      late http.Request sent;
      final service = AiScanService(
        config: config,
        client: MockClient((request) async {
          sent = request;
          // Jawaban dibungkus pagar markdown tetap terbaca.
          final text = '```json\n${jsonEncode(_aiJson)}\n```';
          return http.Response(_responsesBody(text), 200);
        }),
      );

      final result = await service.analyze(
        _image,
        mimeType: 'image/jpeg',
        today: _today,
      );

      expect(sent.url.toString(), 'https://api.x.ai/v1/responses');
      expect(sent.headers['Authorization'], 'Bearer xai-test');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'grok-test');
      expect(body['store'], isFalse);
      final input = body['input'] as List;
      expect(input.first['content'], contains('2026-11-14'));
      final image = (input.last['content'] as List).first as Map;
      expect(image['type'], 'input_image');
      expect(image['image_url'], 'data:image/jpeg;base64,AQIDBA==');

      expect(result.items.map((i) => i.name), ['Tomat', 'Susu UHT']);
    });

    test('API key kosong → tidak dikonfigurasi & menolak analisis', () async {
      final service = AiScanService(
        config: const AiScanConfig(provider: AiProvider.groq, apiKey: ' '),
        client: MockClient((_) async => fail('tidak boleh memanggil API')),
      );
      expect(service.isConfigured, isFalse);
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(isA<ScanException>()),
      );
    });

    test('kode error dipetakan ke pesan yang jelas', () async {
      Future<String> messageFor(int status) async {
        final service = AiScanService(
          config: config,
          client: MockClient((_) async => http.Response('{}', status)),
        );
        try {
          await service.analyze(_image, mimeType: 'image/png', today: _today);
        } on ScanException catch (error) {
          return error.message;
        }
        fail('harus melempar ScanException');
      }

      expect(await messageFor(401), contains('API key'));
      expect(await messageFor(429), contains('Batas pemakaian'));
      expect(await messageFor(503), contains('bermasalah'));
    });

    test('400 "Incorrect API key" → pesan key tidak valid', () async {
      final service = AiScanService(
        config: config,
        client: MockClient(
          (_) async => http.Response(
            '{"code":"invalid-argument","error":"Incorrect API key provided. '
            'You can obtain an API key from https://console.x.ai."}',
            400,
          ),
        ),
      );
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            contains('API key Grok tidak valid'),
          ),
        ),
      );
    });

    test('spasi & tanda kutip di sekitar key dibuang', () async {
      late http.Request sent;
      final service = AiScanService(
        config: const AiScanConfig(
          provider: AiProvider.xai,
          apiKey: '  "xai-abc"  ',
        ),
        client: MockClient((request) async {
          sent = request;
          return http.Response(_responsesBody(jsonEncode(_aiJson)), 200);
        }),
      );
      await service.analyze(_image, mimeType: 'image/png', today: _today);
      expect(sent.headers['Authorization'], 'Bearer xai-abc');
    });

    test('key Groq dipakai untuk xAI → ditolak tanpa memanggil API', () async {
      final service = AiScanService(
        config: const AiScanConfig(
          provider: AiProvider.xai,
          apiKey: 'gsk_abc123',
        ),
        client: MockClient((_) async => fail('tidak boleh memanggil API')),
      );
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            contains('Key Groq (gsk_...) dipakai untuk Grok'),
          ),
        ),
      );
    });

    test('jawaban bukan JSON → ScanException', () async {
      final service = AiScanService(
        config: config,
        client: MockClient(
          (_) async => http.Response(_responsesBody('Maaf, saya tidak bisa.'),
              200),
        ),
      );
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(isA<ScanException>()),
      );
    });

    test('koneksi gagal → ScanException', () async {
      final service = AiScanService(
        config: config,
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            contains('koneksi'),
          ),
        ),
      );
    });
  });

  group('AiScanService (Groq)', () {
    const config = AiScanConfig(provider: AiProvider.groq, apiKey: 'gsk_test');

    test('model default & endpoint Groq', () {
      expect(config.model, 'qwen/qwen3.8-27b');
      expect(
        AiProvider.groq.endpoint,
        'https://api.groq.com/openai/v1/chat/completions',
      );
      expect(AiProvider.fromKey('gsk_abc'), AiProvider.groq);
      expect(AiProvider.fromKey('xai-abc'), AiProvider.xai);
      expect(AiProvider.fromKey('sk-abc'), isNull);
    });

    test('mengirim chat completions + image_url dan mengurai jawaban',
        () async {
      late http.Request sent;
      final service = AiScanService(
        config: config,
        client: MockClient((request) async {
          sent = request;
          // Blok penalaran <think> diabaikan.
          final content = '<think>cek {warna} tomat</think>'
              '${jsonEncode(_aiJson)}';
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': content},
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await service.analyze(
        _image,
        mimeType: 'image/jpeg',
        today: _today,
      );

      expect(
        sent.url.toString(),
        'https://api.groq.com/openai/v1/chat/completions',
      );
      expect(sent.headers['Authorization'], 'Bearer gsk_test');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'qwen/qwen3.8-27b');
      expect(body['response_format'], {'type': 'json_object'});
      final content = (body['messages'] as List).single['content'] as List;
      expect(content.first['type'], 'text');
      expect(content.first['text'], contains('2026-11-14'));
      expect(content.last['type'], 'image_url');
      expect(content.last['image_url']['url'], 'data:image/jpeg;base64,AQIDBA==');

      expect(result.items.map((i) => i.name), ['Tomat', 'Susu UHT']);
    });

    test('401 "Invalid API Key" → pesan key Groq tidak valid', () async {
      final service = AiScanService(
        config: config,
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"message":"Invalid API Key","type":"invalid_request_error"}}',
            401,
          ),
        ),
      );
      await expectLater(
        service.analyze(_image, mimeType: 'image/png', today: _today),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            contains('API key Groq tidak valid'),
          ),
        ),
      );
    });
  });
}
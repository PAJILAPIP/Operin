import 'package:flutter_test/flutter_test.dart';
import 'package:operin/core/utils/formatters.dart';
import 'package:operin/core/utils/geo.dart';

void main() {
  // Database terpisah per file test agar aman dijalankan paralel.

  group('geo', () {
    test('jarak haversine', () {
      expect(distanceKm(-0.95, 100.35, -0.95, 100.35), 0);
      // 0,01° lintang ≈ 1,11 km
      expect(distanceKm(-0.95, 100.35, -0.94, 100.35), closeTo(1.11, 0.01));
      // Padang → Bukittinggi ± 70 km garis lurus
      expect(distanceKm(-0.9471, 100.4172, -0.3056, 100.3692),
          closeTo(71, 2));
    });

    test('format jarak & sisa waktu', () {
      expect(formatDistance(0.35), '350 m');
      expect(formatDistance(2.46), '2,5 km');
      final now = DateTime(2026, 11, 14, 10);
      expect(formatTimeLeft(now.add(const Duration(minutes: 30)), now),
          'Sisa 30 menit');
      expect(formatTimeLeft(now.add(const Duration(hours: 3)), now),
          'Sisa 3 jam');
      expect(formatTimeLeft(now.add(const Duration(days: 2)), now),
          'Sisa 2 hari');
      expect(formatTimeLeft(now.subtract(const Duration(minutes: 1)), now),
          'Berakhir');
    });
  });
}

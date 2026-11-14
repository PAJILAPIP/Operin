import 'package:flutter_test/flutter_test.dart';
import 'package:operin/model/business_category.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';

void main() {
  // Database terpisah per file test agar aman dijalankan paralel.

  group('BusinessProfile.normalizeWhatsapp', () {
    test('menerima berbagai format nomor Indonesia', () {
      expect(BusinessProfile.normalizeWhatsapp('081234567890'), '6281234567890');
      expect(
        BusinessProfile.normalizeWhatsapp('0812-3456-7890'),
        '6281234567890',
      );
      expect(
        BusinessProfile.normalizeWhatsapp('+62 812 3456 7890'),
        '6281234567890',
      );
      expect(BusinessProfile.normalizeWhatsapp('81234567890'), '6281234567890');
    });

    test('menolak nomor tidak valid', () {
      expect(BusinessProfile.normalizeWhatsapp(''), isNull);
      expect(BusinessProfile.normalizeWhatsapp('12345'), isNull);
      expect(BusinessProfile.normalizeWhatsapp('0211234567'), isNull);
    });
  });

  test('FoodCategory encode/parse bolak-balik dan abaikan nilai asing', () {
    final encoded = FoodCategory.encodeList([
      FoodCategory.sayur,
      FoodCategory.roti,
    ]);
    expect(encoded, 'sayur,roti');
    expect(
      FoodCategory.parseList('$encoded,tidakAda'),
      {FoodCategory.sayur, FoodCategory.roti},
    );
    expect(FoodCategory.parseList(null), isEmpty);
  });

  test('BusinessCategory.fromName fallback ke lainnya', () {
    expect(BusinessCategory.fromName('katering'), BusinessCategory.katering);
    expect(BusinessCategory.fromName('usaha1'), BusinessCategory.lainnya);
    expect(BusinessCategory.fromName(null), BusinessCategory.lainnya);
  });
}

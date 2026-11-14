import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';
import 'package:operin/data/profile_repository.dart';
import 'package:operin/model/business_category.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';

void main() {
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

  test('SqliteProfileRepository simpan, baca, dan perbarui profil', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const auth = SqliteAuthRepository();
    const profiles = SqliteProfileRepository();
    final email = 'profile-${DateTime.now().microsecondsSinceEpoch}@operin.test';

    try {
      final user = await auth.register(
        fullName: 'Profile User',
        email: email,
        password: 'password123',
        businessType: BusinessCategory.bakery.name,
        address: 'Padang',
        latitude: -0.95,
        longitude: 100.35,
      );
      expect(user.latitude, -0.95);
      expect(await profiles.getProfile(user.id!), isNull);

      final profile = BusinessProfile(
        userId: user.id!,
        businessName: 'Roti Enak',
        whatsapp: '6281234567890',
        preferredCategories: const {FoodCategory.roti, FoodCategory.susuOlahan},
        radiusKm: 7,
        notifyExpiry: true,
        notifyDaysBefore: 3,
        updatedAt: DateTime(2026, 11, 14),
      );
      await profiles.saveProfile(profile);

      final loaded = (await profiles.getProfile(user.id!))!;
      expect(loaded.businessName, 'Roti Enak');
      expect(loaded.preferredCategories, profile.preferredCategories);
      expect(loaded.radiusKm, 7);
      expect(loaded.notifyExpiry, isTrue);
      expect(loaded.notifyDaysBefore, 3);

      // Simpan ulang = update, bukan duplikat
      await profiles.saveProfile(
        BusinessProfile(
          userId: user.id!,
          businessName: 'Roti Enak 2',
          whatsapp: profile.whatsapp,
          preferredCategories: profile.preferredCategories,
          radiusKm: 12,
          notifyExpiry: false,
          notifyDaysBefore: 1,
          updatedAt: DateTime(2026, 11, 15),
        ),
      );
      final updated = (await profiles.getProfile(user.id!))!;
      expect(updated.businessName, 'Roti Enak 2');
      expect(updated.radiusKm, 12);
      expect(updated.notifyExpiry, isFalse);

      // Login mengembalikan koordinat yang tersimpan
      final loggedIn = await auth.login(email: email, password: 'password123');
      expect(loggedIn.longitude, 100.35);
    } finally {
      final database = await LocalDatabase.instance.database;
      await database.delete('users', where: 'email = ?', whereArgs: [email]);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

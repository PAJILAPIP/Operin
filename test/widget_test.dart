import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operin/app.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/profile_repository.dart';
import 'package:operin/model/auth_user.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';

const _welcomeText = 'Welcome back please login to your account';

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeAuthRepository auth,
  required _FakeProfileRepository profiles,
}) async {
  // Lebar ponsel, tapi cukup tinggi agar seluruh form onboarding muat
  // tanpa scroll.
  tester.view.physicalSize = const Size(412, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    OperinApp(authRepository: auth, profileRepository: profiles),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, {bool remember = true}) async {
  await tester.enterText(find.byType(TextField).at(0), 'user@operin.test');
  await tester.enterText(find.byType(TextField).at(1), 'password123');
  if (!remember) await tester.tap(find.text('Remember me'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Login -> survey -> profil usaha -> dashboard -> logout',
      (tester) async {
    final auth = _FakeAuthRepository();
    final profiles = _FakeProfileRepository();
    await _pumpApp(tester, auth: auth, profiles: profiles);

    // Belum ada sesi → halaman login
    expect(find.text(_welcomeText), findsOneWidget);
    await _login(tester);
    expect(find.text('Pilih Peran Anda'), findsOneWidget);
    expect(auth.sessionUserId, 1, reason: 'Remember me aktif');

    // Pilih peran → onboarding profil usaha
    await tester.tap(find.text('Jual Stok Surplus'));
    await tester.pump();
    await _tapButton(tester, 'Lanjutkan ke Dashboard');
    expect(auth.user.role, 'seller');
    expect(find.text('Lengkapi Profil Usaha'), findsOneWidget);

    // Validasi: form kosong tidak bisa disimpan
    await _tapButton(tester, 'Simpan & Lanjutkan');
    expect(find.text('Nama usaha wajib diisi.'), findsOneWidget);
    expect(profiles.saved, isNull);
    // Tunggu SnackBar hilang agar tidak menutupi tombol simpan.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Isi profil usaha
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama Usaha / Toko'),
      'Warung Berkah',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nomor WhatsApp (08xx)'),
      '0812-3456-7890',
    );
    await tester.ensureVisible(find.text('Sayur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sayur'));
    await tester.pump();
    await tester.tap(find.text('Buah'));
    await tester.pump();
    await _tapButton(tester, 'Simpan & Lanjutkan');

    expect(find.text('DAMPAK BISNIS ANDA'), findsOneWidget);
    final saved = profiles.saved!;
    expect(saved.businessName, 'Warung Berkah');
    expect(saved.whatsapp, '6281234567890');
    expect(saved.preferredCategories, {FoodCategory.sayur, FoodCategory.buah});
    expect(saved.radiusKm, 5);
    expect(saved.notifyExpiry, isTrue);

    // Profil menampilkan nama user & nama usaha
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Operin User'), findsOneWidget);
    expect(find.text('Warung Berkah'), findsOneWidget);

    // Logout → sesi dihapus, kembali ke login
    await tester.ensureVisible(find.text('Keluar Akun'));
    await tester.tap(find.text('Keluar Akun'));
    await tester.pumpAndSettle();
    expect(auth.sessionUserId, isNull);
    expect(find.text(_welcomeText), findsOneWidget);
  });

  testWidgets('Sesi lengkap (peran + profil) langsung ke dashboard',
      (tester) async {
    final auth = _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'buyer')
      ..sessionUserId = 1;
    final profiles = _FakeProfileRepository()..saved = _sampleProfile;

    await _pumpApp(tester, auth: auth, profiles: profiles);

    expect(find.text('DAMPAK BISNIS ANDA'), findsOneWidget);
  });

  testWidgets('Sesi dengan peran tapi tanpa profil diarahkan ke onboarding',
      (tester) async {
    final auth = _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
      ..sessionUserId = 1;

    await _pumpApp(tester, auth: auth, profiles: _FakeProfileRepository());

    expect(find.text('Lengkapi Profil Usaha'), findsOneWidget);
  });

  testWidgets('Sesi tanpa peran diarahkan ke survey', (tester) async {
    final auth = _FakeAuthRepository()..sessionUserId = 1;

    await _pumpApp(tester, auth: auth, profiles: _FakeProfileRepository());

    expect(find.text('Pilih Peran Anda'), findsOneWidget);
  });

  testWidgets('Login tanpa Remember me tidak menyimpan sesi', (tester) async {
    final auth = _FakeAuthRepository();
    await _pumpApp(tester, auth: auth, profiles: _FakeProfileRepository());

    await _login(tester, remember: false);

    expect(find.text('Pilih Peran Anda'), findsOneWidget);
    expect(auth.sessionUserId, isNull);
  });

  testWidgets('Edit profil usaha dari menu Informasi Toko', (tester) async {
    final auth = _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
      ..sessionUserId = 1;
    final profiles = _FakeProfileRepository()..saved = _sampleProfile;
    await _pumpApp(tester, auth: auth, profiles: profiles);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informasi Toko'));
    await tester.pumpAndSettle();

    // Form terisi data lama
    expect(find.text('Toko Lama'), findsOneWidget);
    expect(find.text('081111111111'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Toko Lama'),
      'Toko Baru',
    );
    await _tapButton(tester, 'Simpan Perubahan');

    expect(profiles.saved!.businessName, 'Toko Baru');
    expect(find.text('Toko Baru'), findsOneWidget); // kembali ke tab Profil
  });
}

final _sampleProfile = BusinessProfile(
  userId: 1,
  businessName: 'Toko Lama',
  whatsapp: '6281111111111',
  preferredCategories: const {FoodCategory.roti},
  radiusKm: 10,
  notifyExpiry: false,
  notifyDaysBefore: 1,
  updatedAt: DateTime(2026),
);

/// Repository in-memory dengan satu akun: user@operin.test / password123.
class _FakeAuthRepository implements AuthRepository {
  static final defaultUser = AuthUser(
    id: 1,
    fullName: 'Operin User',
    email: 'user@operin.test',
    businessType: 'warungMakan',
    address: 'Jakarta',
    createdAt: DateTime(2026),
    latitude: -6.2,
    longitude: 106.8,
  );

  AuthUser user = defaultUser;
  int? sessionUserId;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    if (email != user.email || password != 'password123') {
      throw const AuthException('Email atau password salah.');
    }
    return user;
  }

  @override
  Future<AuthUser> register({
    required String fullName,
    required String email,
    required String password,
    required String businessType,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    user = AuthUser(
      id: 2,
      fullName: fullName,
      email: email,
      businessType: businessType,
      address: address,
      createdAt: DateTime(2026),
      latitude: latitude,
      longitude: longitude,
    );
    return user;
  }

  @override
  Future<AuthUser?> restoreSession() async =>
      sessionUserId == user.id ? user : null;

  @override
  Future<void> saveSession(int userId) async => sessionUserId = userId;

  @override
  Future<void> clearSession() async => sessionUserId = null;

  @override
  Future<AuthUser> updateRole(int userId, String role) async {
    user = user.copyWith(role: role);
    return user;
  }
}

class _FakeProfileRepository implements ProfileRepository {
  BusinessProfile? saved;

  @override
  Future<BusinessProfile?> getProfile(int userId) async =>
      saved?.userId == userId ? saved : null;

  @override
  Future<BusinessProfile> saveProfile(BusinessProfile profile) async =>
      saved = profile;
}

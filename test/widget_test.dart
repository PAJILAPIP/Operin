import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:operin/app.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/profile_repository.dart';
import 'package:operin/model/auth_user.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/stock_item.dart';
import 'package:operin/data/stock_repository.dart';
import 'package:operin/data/promotion_repository.dart';
import 'package:operin/model/promotion.dart';

const _welcomeText = 'Welcome back please login to your account';

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeAuthRepository auth,
  required _FakeProfileRepository profiles,
  _FakeStockRepository? stock,
  _FakePromotionRepository? promotions,
}) async {
  // Lebar ponsel, tapi cukup tinggi agar seluruh form onboarding muat
  // tanpa scroll.
  tester.view.physicalSize = const Size(412, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    OperinApp(
      authRepository: auth,
      profileRepository: profiles,
      stockRepository: stock ?? _FakeStockRepository(),
      promotionRepository: promotions ?? _FakePromotionRepository(),
      clock: () => _today,
    ),
  );
  await tester.pumpAndSettle();
}

/// "Hari ini" yang tetap untuk semua widget test.
final _today = DateTime(2026, 11, 14, 9);

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

  group('Manajemen stok', () {
    _FakeAuthRepository completedAuth() => _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
      ..sessionUserId = 1;

    testWidgets('tambah, lihat detail, edit, dan hapus stok', (tester) async {
      final stock = _FakeStockRepository();
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        stock: stock,
      );

      await tester.tap(find.text('Stok'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada stok'), findsOneWidget);

      // Tambah
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Tambah Stok'));
      await tester.pumpAndSettle();

      // Validasi form kosong
      await _tapButton(tester, 'Simpan Stok');
      expect(find.text('Nama bahan wajib diisi.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Bahan'),
        'Tomat Ceri',
      );
      await tester.tap(find.byType(DropdownButtonFormField<FoodCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sayur').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah'), '25');
      await tester.enterText(
        find.widgetWithText(TextField, 'Harga per Satuan (Rp)'),
        '12.000',
      );
      await tester.tap(find.widgetWithText(InkWell, 'Tanggal Kedaluwarsa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // default: hari ini + 3
      await tester.pumpAndSettle();
      expect(find.text('17 Nov 2026'), findsOneWidget);

      await _tapButton(tester, 'Simpan Stok');
      expect(stock.items, hasLength(1));
      expect(stock.items.single.pricePerUnit, 12000);
      expect(find.text('Tomat Ceri'), findsOneWidget);
      expect(find.text('H-3'), findsOneWidget);
      expect(find.text('Segera'), findsOneWidget); // ambang kritis profil = 1

      // Detail
      await tester.tap(find.text('Tomat Ceri'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Stok'), findsOneWidget);
      expect(find.text('Rp 300.000'), findsOneWidget);

      // Edit
      await _tapButton(tester, 'Edit Stok');
      expect(find.text('Edit Stok'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '25'), '10');
      await _tapButton(tester, 'Simpan Perubahan');
      expect(find.text('Detail Stok'), findsOneWidget);
      expect(find.text('Rp 120.000'), findsOneWidget);
      expect(stock.items.single.quantity, 10);

      // Hapus (dengan konfirmasi)
      await tester.tap(find.text('Hapus Stok'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(stock.items, isEmpty);
      expect(find.text('Belum ada stok'), findsOneWidget);
    });

    testWidgets('dasbor menampilkan stok kritis dan tab stok bisa difilter',
        (tester) async {
      final stock = _FakeStockRepository()
        ..seed([
          _stock('Susu Basi', DateTime(2026, 11, 12)), // kedaluwarsa
          _stock('Roti Tawar', DateTime(2026, 11, 15)), // kritis (H-1)
          _stock('Beras', DateTime(2026, 12, 30)), // aman
        ]);
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        stock: stock,
      );

      // Dasbor: hanya stok yang perlu tindakan
      expect(find.text('2 Kritis'), findsOneWidget);
      expect(find.text('Susu Basi'), findsOneWidget);
      expect(find.text('Roti Tawar'), findsOneWidget);
      expect(find.text('Beras'), findsNothing);

      // "Aksi" membuka detail stok
      await tester.tap(find.text('Aksi').first);
      await tester.pumpAndSettle();
      expect(find.text('Kedaluwarsa · Lewat 2 hari'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Tab stok: filter status & pencarian
      await tester.tap(find.text('Stok'));
      await tester.pumpAndSettle();
      expect(find.text('3 item'), findsOneWidget);

      await tester.ensureVisible(find.text('Aman (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aman (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Beras'), findsOneWidget);
      expect(find.text('Susu Basi'), findsNothing);

      await tester.ensureVisible(find.text('Semua (3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semua (3)'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Cari nama bahan'),
        'roti',
      );
      await tester.pumpAndSettle();
      expect(find.text('Roti Tawar'), findsOneWidget);
      expect(find.text('Beras'), findsNothing);
    });
  });

  group('Smart Stock Rescue', () {
    Future<(_FakeStockRepository, _FakePromotionRepository)> pumpRescue(
      WidgetTester tester, {
      List<StockItem> extra = const [],
    }) async {
      final stock = _FakeStockRepository()
        ..seed([
          _stock('Susu Basi', DateTime(2026, 11, 12)), // kedaluwarsa
          _stock('Roti Tawar', DateTime(2026, 11, 15), // H-1
              category: FoodCategory.roti),
          _stock('Beras', DateTime(2026, 12, 30)), // aman
          ...extra,
        ]);
      final promotions = _FakePromotionRepository();
      await _pumpApp(
        tester,
        auth: _FakeAuthRepository()
          ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
          ..sessionUserId = 1,
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        stock: stock,
        promotions: promotions,
      );
      return (stock, promotions);
    }

    testWidgets('rekomendasi → terbitkan promo → batalkan', (tester) async {
      final (_, promotions) = await pumpRescue(tester);

      // Tile layanan menampilkan jumlah stok yang perlu diselamatkan
      expect(
        find.text('2 stok perlu diselamatkan. Lihat rekomendasi.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Penyelamatan Lapis 1'));
      await tester.pumpAndSettle();

      expect(find.text('Penyelamatan Stok'), findsOneWidget);
      expect(find.text('2 stok perlu diselamatkan'), findsOneWidget);
      expect(find.text('TINDAKAN HARI INI'), findsOneWidget);
      expect(find.text('KEDALUWARSA MINGGU INI'), findsOneWidget);
      expect(find.text('Salurkan ke Daur Ulang'), findsNothing); // tak ada tombol
      expect(find.text('Beras'), findsNothing);

      // Roti H-1 (mudah rusak, kritis) → diskon 50%
      await tester.tap(find.text('Buat Diskon 50%'));
      await tester.pumpAndSettle();
      expect(find.text('Buat Promo'), findsOneWidget);
      expect(find.text('Diskon: 50%'), findsOneWidget);
      expect(find.text('Rp 5.000 /pcs'), findsOneWidget); // harga promo
      expect(find.text('Rp 25.000'), findsOneWidget); // pemasukan 5 pcs

      // Jumlah melebihi stok ditolak
      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah dipromosikan (pcs)'),
        '9',
      );
      await _tapButton(tester, 'Terbitkan Promo');
      expect(find.text('Jumlah promo melebihi stok (5 pcs).'), findsOneWidget);
      expect(promotions.items, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah dipromosikan (pcs)'),
        '4',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Terbitkan Promo');

      final promo = promotions.items.single;
      expect(promo.discountPercent, 50);
      expect(promo.quantity, 4);
      expect(promo.type, PromotionType.discount);
      expect(promo.endsAt, DateTime(2026, 11, 16)); // akhir hari kedaluwarsa

      // Kembali ke halaman penyelamatan dengan promo aktif
      expect(find.text('PROMO AKTIF (1)'), findsOneWidget);
      expect(find.text('Buat Diskon 50%'), findsNothing);

      await tester.tap(find.text('Batalkan'));
      await tester.pumpAndSettle();
      expect(promotions.items.single.status, PromotionStatus.cancelled);
      expect(find.text('PROMO AKTIF (1)'), findsNothing);
      expect(find.text('Buat Diskon 50%'), findsOneWidget);
    });

    testWidgets('"Aksi" di dasbor membuka form promo untuk stok kritis',
        (tester) async {
      await pumpRescue(tester);

      // Urutan peringatan: Susu Basi (kedaluwarsa), lalu Roti Tawar
      await tester.tap(find.text('Aksi').last);
      await tester.pumpAndSettle();
      expect(find.text('Buat Promo'), findsOneWidget);
      expect(find.text('Roti Tawar'), findsOneWidget);
    });

    testWidgets('flash sale berakhir sesuai durasi yang dipilih',
        (tester) async {
      final (_, promotions) = await pumpRescue(
        tester,
        extra: [
          // Kedaluwarsa hari ini → rekomendasi flash sale
          _stock('Nasi Kotak', DateTime(2026, 11, 14),
              category: FoodCategory.makananJadi),
        ],
      );

      await tester.tap(find.text('Penyelamatan Lapis 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Flash Sale 60%'));
      await tester.pumpAndSettle();
      expect(find.text('Diskon: 60%'), findsOneWidget);

      await tester.tap(find.text('6 jam'));
      await tester.pumpAndSettle();
      await _tapButton(tester, 'Terbitkan Promo');

      final promo = promotions.items.single;
      expect(promo.type, PromotionType.flashSale);
      expect(promo.endsAt, _today.add(const Duration(hours: 6)));
    });
  });
}

class _FakePromotionRepository implements PromotionRepository {
  final List<Promotion> items = [];
  int _nextId = 1;

  @override
  Future<List<Promotion>> listByUser(int userId) async =>
      items.where((p) => p.userId == userId).toList().reversed.toList();

  @override
  Future<Promotion> insert(Promotion promotion) async {
    final saved = promotion.copyWith(id: _nextId++);
    items.add(saved);
    return saved;
  }

  @override
  Future<void> updateStatus(int id, PromotionStatus status) async {
    final index = items.indexWhere((p) => p.id == id);
    items[index] = items[index].copyWith(status: status);
  }
}

StockItem _stock(
  String name,
  DateTime expiry, {
  FoodCategory category = FoodCategory.bahanKering,
}) => StockItem(
  userId: 1,
  name: name,
  category: category,
  quantity: 5,
  unit: StockUnit.pcs,
  pricePerUnit: 10000,
  expiryDate: expiry,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

class _FakeStockRepository implements StockRepository {
  final List<StockItem> items = [];
  int _nextId = 1;

  void seed(List<StockItem> seed) {
    for (final item in seed) {
      items.add(item.copyWith(id: _nextId++));
    }
  }

  @override
  Future<List<StockItem>> listByUser(int userId) async {
    final list = items.where((item) => item.userId == userId).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return list;
  }

  @override
  Future<StockItem> insert(StockItem item) async {
    final saved = item.copyWith(id: _nextId++);
    items.add(saved);
    return saved;
  }

  @override
  Future<StockItem> update(StockItem item) async {
    final index = items.indexWhere((existing) => existing.id == item.id);
    items[index] = item;
    return item;
  }

  @override
  Future<void> delete(int id) async =>
      items.removeWhere((item) => item.id == id);
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

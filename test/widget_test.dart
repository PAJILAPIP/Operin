import 'dart:convert';
import 'dart:typed_data';

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
import 'package:operin/data/market_repository.dart';
import 'package:operin/data/match_repository.dart';
import 'package:operin/data/transaction_repository.dart';
import 'package:operin/model/activity_entry.dart';
import 'package:operin/model/barter.dart';
import 'package:operin/model/business_category.dart';
import 'package:operin/model/partner_profile.dart';
import 'package:operin/model/market_listing.dart';
import 'package:operin/model/market_order.dart';
import 'package:operin/data/scan_service.dart';
import 'package:operin/features/scanner/scan_image_service.dart';
import 'package:operin/model/scan_result.dart';

const _welcomeText = 'Welcome back please login to your account';

Future<void> _pumpApp(
  WidgetTester tester, {
  required _FakeAuthRepository auth,
  required _FakeProfileRepository profiles,
  _FakeStockRepository? stock,
  _FakePromotionRepository? promotions,
  _FakeMarketRepository? market,
  _FakeMatchRepository? match,
  _FakeTransactionRepository? transactions,
  _FakeScanService? scan,
  _FakeScanImageService? images,
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
      marketRepository: market ?? _FakeMarketRepository(),
      matchRepository: match ?? _FakeMatchRepository(),
      transactionRepository: transactions ?? _FakeTransactionRepository(),
      scanService: scan ?? _FakeScanService(),
      scanImageService: images ?? _FakeScanImageService(),
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

  group('Marketplace B2B', () {
    MarketListing listing(
      int id,
      String name, {
      PromotionType type = PromotionType.discount,
      double? distance,
      Duration endsIn = const Duration(days: 1),
      double quantity = 10,
    }) => MarketListing(
      promotion: Promotion(
        id: id,
        userId: 2,
        stockId: id,
        type: type,
        discountPercent: 50,
        originalPrice: 10000,
        quantity: quantity,
        createdAt: _today,
        endsAt: _today.add(endsIn),
      ),
      stockName: name,
      category: FoodCategory.roti,
      unit: StockUnit.pcs,
      expiryDate: DateTime(2026, 11, 15),
      sellerName: 'Toko Sebelah',
      sellerAddress: 'Jl. Sebelah No. 1',
      sellerWhatsapp: '6281200000000',
      distanceKm: distance,
    );

    Future<_FakeMarketRepository> pumpMarket(
      WidgetTester tester, {
      List<MarketOrder> orders = const [],
    }) async {
      final market = _FakeMarketRepository()
        ..listings.addAll([
          listing(1, 'Nasi Kotak',
              type: PromotionType.flashSale,
              endsIn: const Duration(hours: 3),
              distance: 1.2),
          listing(2, 'Roti Gandum', distance: 2.5),
          listing(3, 'Kue Jauh', distance: 12), // di luar radius 10 km
        ])
        ..orders.addAll(orders);
      await _pumpApp(
        tester,
        auth: _FakeAuthRepository()
          ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'buyer')
          ..sessionUserId = 1,
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        market: market,
      );
      await tester.tap(find.text('Pasar B2B'));
      await tester.pumpAndSettle();
      return market;
    }

    testWidgets('pembeli melihat flash sale & sale lalu mengajukan pembelian',
        (tester) async {
      final market = await pumpMarket(tester);

      // Default: Flash Sale
      expect(find.text('Nasi Kotak'), findsOneWidget);
      expect(find.text('Sisa 3 jam'), findsOneWidget);
      expect(find.text('Roti Gandum'), findsNothing);

      // Sale: yang di luar radius disembunyikan sampai filter dimatikan
      await tester.tap(find.text('Sale'));
      await tester.pumpAndSettle();
      expect(find.text('Roti Gandum'), findsOneWidget);
      expect(find.text('Kue Jauh'), findsNothing);
      await tester.tap(find.text('Dalam radius 10 km'));
      await tester.pumpAndSettle();
      expect(find.text('Kue Jauh'), findsOneWidget);

      // Detail & pengajuan
      await tester.tap(find.text('Roti Gandum'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Penawaran'), findsOneWidget);
      expect(find.text('Rp 5.000 /pcs'), findsOneWidget);
      expect(find.text('Jl. Sebelah No. 1\n2,5 km dari Anda'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Jumlah dibeli (pcs)'),
        '3',
      );
      await tester.pump();
      expect(find.text('Total: Rp 15.000'), findsOneWidget);
      await _tapButton(tester, 'Ajukan Pembelian');

      final order = market.orders.single;
      expect(order.promotionId, 2);
      expect(order.quantity, 3);
      expect(order.unitPrice, 5000);

      // Tab Penawaran → Keluar → batalkan
      await tester.tap(find.text('Penawaran'));
      await tester.pumpAndSettle();
      expect(find.text('KELUAR (1)'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
      await tester.tap(find.text('Batalkan Pengajuan'));
      await tester.pumpAndSettle();
      expect(market.orders.single.status, OrderStatus.cancelled);
      expect(find.text('Dibatalkan'), findsOneWidget);
    });

    testWidgets('penjual menerima pengajuan masuk', (tester) async {
      final market = await pumpMarket(
        tester,
        orders: [
          MarketOrder(
            id: 7,
            promotionId: 99,
            buyerId: 3,
            sellerId: 1, // user yang login
            quantity: 2,
            unitPrice: 4000,
            note: 'Ambil sore',
            createdAt: _today,
            updatedAt: _today,
            stockName: 'Tomat Ceri',
            unit: StockUnit.kg,
            buyerName: 'Katering Bunda',
          ),
        ],
      );

      await tester.tap(find.text('Penawaran'));
      await tester.pumpAndSettle();
      expect(find.text('MASUK (1)'), findsOneWidget);
      expect(find.text('Tomat Ceri'), findsOneWidget);
      expect(find.text('Dari Katering Bunda · 14 Nov 2026'), findsOneWidget);
      expect(find.text('2 kg × Rp 4.000 = Rp 8.000'), findsOneWidget);

      await tester.tap(find.text('Terima'));
      await tester.pumpAndSettle();
      expect(market.orders.single.status, OrderStatus.accepted);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Terima'), findsNothing);
    });
  });

  group('Matchmaking & Barter', () {
    // Stok saya: Roti Tawar (id 1, kritis H-1) & Susu Basi (id 2, kedaluwarsa)
    _FakeStockRepository myStock() => _FakeStockRepository()
      ..seed([
        _stock('Roti Tawar', DateTime(2026, 11, 15), category: FoodCategory.roti),
        _stock('Susu Basi', DateTime(2026, 11, 12),
            category: FoodCategory.susuOlahan),
      ]);

    _FakeMatchRepository matchRepo() => _FakeMatchRepository()
      ..partners.addAll([
        _partnerProfile(2, 'Dapur Bunda',
            wants: {FoodCategory.roti},
            distance: 1.5,
            stocks: [
              _stock('Kue Basah', DateTime(2026, 11, 17),
                      category: FoodCategory.roti)
                  .copyWith(id: 50)
                  .withUser(2),
            ]),
        _partnerProfile(3, 'Kompos Hijau', role: 'waste', distance: 3),
        _partnerProfile(4, 'Toko Jauh',
            wants: {FoodCategory.roti}, distance: 40),
      ]);

    Future<void> pump(WidgetTester tester, _FakeMatchRepository match) =>
        _pumpApp(
          tester,
          auth: _FakeAuthRepository()
            ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
            ..sessionUserId = 1,
          profiles: _FakeProfileRepository()..saved = _sampleProfile,
          stock: myStock(),
          match: match,
        );

    testWidgets('rekomendasi mitra lalu ajukan barter', (tester) async {
      final match = matchRepo();
      await pump(tester, match);

      await tester.tap(find.text('Matchmaking B2B'));
      await tester.pumpAndSettle();
      expect(find.text('Dapur Bunda'), findsOneWidget);
      expect(find.text('COCOK'), findsOneWidget);
      expect(find.text('Saling membutuhkan, cocok untuk barter'), findsOneWidget);
      expect(find.text('Kompos Hijau'), findsOneWidget);
      expect(find.text('Toko Jauh'), findsNothing); // di luar radius 10 km

      await tester.tap(find.text('Ajukan Barter').first);
      await tester.pumpAndSettle();
      expect(find.text('Roti Tawar (5 pcs)'), findsOneWidget);
      expect(find.text('Kue Basah (5 pcs)'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Jumlah ditawarkan'), '3');
      await tester.enterText(find.widgetWithText(TextField, 'Jumlah diminta'), '2');
      await _tapButton(tester, 'Kirim Penawaran');

      final barter = match.barters.single;
      expect(barter.type, BarterType.barter);
      expect(barter.receiverId, 2);
      expect(barter.offeredStockId, 1);
      expect(barter.offeredQuantity, 3);
      expect(barter.requestedStockId, 50);
      expect(barter.requestedQuantity, 2);

      await tester.tap(find.text('Barter'));
      await tester.pumpAndSettle();
      expect(find.text('Dapur Bunda'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
    });

    testWidgets('penerima menawar balik lalu pengaju menerima', (tester) async {
      final match = matchRepo()
        ..barters.add(Barter(
          id: 9,
          type: BarterType.barter,
          proposerId: 2,
          receiverId: 1,
          offeredStockId: 50,
          offeredQuantity: 4,
          requestedStockId: 1,
          requestedQuantity: 2,
          lastActorId: 2,
          createdAt: _today,
          updatedAt: _today,
          proposerName: 'Dapur Bunda',
          receiverName: 'Toko Lama',
          offeredStockName: 'Kue Basah',
          offeredUnit: StockUnit.pcs,
          requestedStockName: 'Roti Tawar',
          requestedUnit: StockUnit.pcs,
        ));
      await pump(tester, match);

      await tester.tap(find.text('Matchmaking B2B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barter (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Perlu jawaban Anda'), findsOneWidget);
      await tester.tap(find.text('Dapur Bunda'));
      await tester.pumpAndSettle();

      expect(find.text('4 pcs Kue Basah'), findsOneWidget); // Anda terima
      expect(find.text('2 pcs Roti Tawar'), findsOneWidget); // Anda beri
      expect(find.text('Giliran Anda menjawab.'), findsOneWidget);

      // Tawar balik: minta 6 kue untuk 2 roti
      await tester.tap(find.text('Tawar Balik'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Kue Basah (pcs)'), '6');
      await tester.tap(find.text('Kirim Tawaran'));
      await tester.pumpAndSettle();

      expect(match.barters.single.status, BarterStatus.negotiating);
      expect(match.barters.single.offeredQuantity, 6);
      expect(find.text('Menunggu jawaban Dapur Bunda.'), findsOneWidget);
      expect(find.text('Tawar Balik'), findsNothing);
      expect(find.text('Kue Basah: 6 pcs  ⇄  Roti Tawar: 2 pcs'), findsOneWidget);

      // Mitra menerima (disimulasikan) → status disepakati
      match.barters[0] = match.barters[0].copyWith(
        status: BarterStatus.accepted,
        lastActorId: 2,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Matchmaking B2B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barter'));
      await tester.pumpAndSettle();
      expect(find.text('Disepakati'), findsOneWidget);
    });

    testWidgets('stok kedaluwarsa disalurkan ke mitra daur ulang',
        (tester) async {
      final match = matchRepo();
      await pump(tester, match);

      await tester.tap(find.text('Penyelamatan Lapis 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salurkan ke Mitra Daur Ulang'));
      await tester.pumpAndSettle();

      expect(find.text('Salurkan ke Daur Ulang'), findsOneWidget);
      expect(find.text('Kompos Hijau'), findsOneWidget);
      expect(find.text('Dapur Bunda'), findsNothing);

      await tester.tap(find.text('Salurkan Stok'));
      await tester.pumpAndSettle();
      expect(find.text('Susu Basi (5 pcs)'), findsOneWidget);
      await _tapButton(tester, 'Ajukan Penyaluran');

      final donation = match.barters.single;
      expect(donation.type, BarterType.donation);
      expect(donation.receiverId, 3);
      expect(donation.offeredStockId, 2);
      expect(donation.requestedStockId, isNull);
    });
  });

  group('Transaksi & Dampak', () {
    _FakeAuthRepository completedAuth() => _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
      ..sessionUserId = 1;

    ActivityEntry entry(
      ActivityKind kind, {
      required int saved,
      required double weight,
      int counterpart = 2,
      DateTime? at,
    }) => ActivityEntry(
      userId: 1,
      kind: kind,
      counterpartId: counterpart,
      counterpartName: 'Katering Bunda',
      stockName: 'Roti Gandum',
      category: FoodCategory.roti,
      quantity: 4,
      unit: StockUnit.pcs,
      amount: kind == ActivityKind.sale ? saved : 0,
      savedValue: saved,
      weightKg: weight,
      referenceType: 'order',
      referenceId: counterpart,
      createdAt: at ?? _today,
    );

    testWidgets('dasbor & halaman dampak memakai data riwayat', (tester) async {
      final transactions = _FakeTransactionRepository()
        ..entries.addAll([
          entry(ActivityKind.sale, saved: 30000, weight: 3),
          entry(ActivityKind.donationOut, saved: 0, weight: 2, counterpart: 3),
          entry(ActivityKind.sale,
              saved: 20000,
              weight: 1,
              at: DateTime(2026, 10, 20)),
        ]);
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        transactions: transactions,
      );

      // Kartu dasbor: bukan dummy lagi
      expect(find.text('Rp 50.000'), findsOneWidget);
      expect(find.text('+50% dibanding bulan lalu'), findsOneWidget);
      expect(find.text('6 kg'), findsOneWidget);
      expect(find.text('2 mitra'), findsOneWidget);

      await tester.tap(find.text('Lihat detail'));
      await tester.pumpAndSettle();
      expect(find.text('Dampak & Riwayat'), findsOneWidget);
      expect(find.text('15 kg CO₂e'), findsOneWidget);
      expect(find.text('NILAI TERSELAMATKAN PER BULAN'), findsOneWidget);
      expect(find.text('Nov'), findsOneWidget);

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('14 Nov 2026'), findsOneWidget);
      expect(find.text('20 Okt 2026'), findsOneWidget);
      expect(find.text('Penjualan: Roti Gandum'), findsNWidgets(2));
      expect(find.text('+Rp 30.000'), findsOneWidget);
    });

    testWidgets('penjual menandai pesanan selesai dari tab Penawaran',
        (tester) async {
      final market = _FakeMarketRepository()
        ..orders.add(MarketOrder(
          id: 7,
          promotionId: 99,
          buyerId: 3,
          sellerId: 1,
          quantity: 2,
          unitPrice: 4000,
          status: OrderStatus.accepted,
          createdAt: _today,
          updatedAt: _today,
          stockName: 'Tomat Ceri',
          unit: StockUnit.kg,
          buyerName: 'Katering Bunda',
        ));
      final transactions = _FakeTransactionRepository(market: market);
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        market: market,
        transactions: transactions,
      );

      await tester.tap(find.text('Pasar B2B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Penawaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tandai Selesai'));
      await tester.pumpAndSettle();

      expect(transactions.completedOrders, [7]);
      expect(market.orders.single.status, OrderStatus.completed);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Tandai Selesai'), findsNothing);

      // Dampak di dasbor ikut diperbarui
      await tester.tap(find.text('Dasbor'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 8.000'), findsOneWidget);
      expect(find.text('1 mitra'), findsOneWidget);
    });

    testWidgets('barter yang disepakati bisa diselesaikan', (tester) async {
      final match = _FakeMatchRepository()
        ..barters.add(Barter(
          id: 9,
          type: BarterType.barter,
          proposerId: 1,
          receiverId: 2,
          offeredStockId: 1,
          offeredQuantity: 2,
          requestedNote: 'Gula 1 kg',
          status: BarterStatus.accepted,
          lastActorId: 2,
          createdAt: _today,
          updatedAt: _today,
          receiverName: 'Dapur Bunda',
          offeredStockName: 'Roti Tawar',
          offeredUnit: StockUnit.pcs,
        ));
      final transactions = _FakeTransactionRepository(match: match);
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        match: match,
        transactions: transactions,
      );

      await tester.tap(find.text('Matchmaking B2B'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dapur Bunda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Selesaikan Barter'));
      await tester.pumpAndSettle();
      expect(find.text('Selesaikan transaksi?'), findsOneWidget);
      await tester.tap(find.text('Ya, Selesai'));
      await tester.pumpAndSettle();

      expect(transactions.completedBarters, [9]);
      expect(match.barters.single.status, BarterStatus.completed);
      expect(find.text('Selesaikan Barter'), findsNothing);
    });
  });

  group('AI Stock Scanner', () {
    _FakeAuthRepository completedAuth() => _FakeAuthRepository()
      ..user = _FakeAuthRepository.defaultUser.copyWith(role: 'seller')
      ..sessionUserId = 1;

    Future<void> openScanTab(
      WidgetTester tester, {
      required _FakeScanService scan,
      required _FakeScanImageService images,
      _FakeStockRepository? stock,
    }) async {
      await _pumpApp(
        tester,
        auth: completedAuth(),
        profiles: _FakeProfileRepository()..saved = _sampleProfile,
        stock: stock,
        scan: scan,
        images: images,
      );
      await tester.tap(find.text('Scan AI').last);
      await tester.pumpAndSettle();
    }

    testWidgets('foto dari galeri → hasil AI → tambah ke stok', (tester) async {
      final scan = _FakeScanService();
      final images = _FakeScanImageService();
      final stock = _FakeStockRepository();
      await openScanTab(tester, scan: scan, images: images, stock: stock);

      expect(find.text('Belum ada foto'), findsOneWidget);
      expect(find.textContaining('API key belum diatur'), findsNothing);

      await tester.tap(find.text('Galeri'));
      await tester.pumpAndSettle();

      expect(images.picked, [ScanImageSource.gallery]);
      expect(scan.calls, 1);
      expect(scan.lastToday, _today);
      expect(find.text('Hasil Analisis (2 bahan)'), findsOneWidget);
      expect(find.text('Tomat'), findsOneWidget);
      expect(find.text('Grade B'), findsOneWidget);
      expect(find.text('Kedaluwarsa 17 Nov 2026'), findsOneWidget);
      expect(find.text('Perkiraan AI'), findsOneWidget);
      expect(find.text('Dari label'), findsOneWidget);
      expect(find.text('Tidak Layak'), findsOneWidget);

      final addButton = find.text('Tambah ke Stok').first;
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Form terisi otomatis dari hasil scan
      expect(find.text('Tambah Stok'), findsOneWidget);
      expect(find.textContaining('Diisi dari hasil Scan AI'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Tomat'), findsOneWidget);
      expect(find.text('17 Nov 2026'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Harga per Satuan (Rp)'),
        '8000',
      );
      await _tapButton(tester, 'Simpan Stok');

      final saved = stock.items.single;
      expect(saved.name, 'Tomat');
      expect(saved.category, FoodCategory.sayur);
      expect(saved.quantity, 2.5);
      expect(saved.unit, StockUnit.kg);
      expect(saved.expiryDate, DateTime(2026, 11, 17));
      expect(saved.notes, startsWith('Scan AI: Grade B'));
      expect(find.text('Hasil Analisis (2 bahan)'), findsOneWidget);
    });

    testWidgets('kamera: penjelasan izin → izin diberikan → analisis',
        (tester) async {
      final scan = _FakeScanService();
      final images = _FakeScanImageService()
        ..status = CameraAccess.denied
        ..requestResult = CameraAccess.granted;
      await openScanTab(tester, scan: scan, images: images);

      await tester.tap(find.text('Ambil Foto'));
      await tester.pumpAndSettle();
      expect(find.text('Izinkan akses kamera'), findsOneWidget);
      await tester.tap(find.text('Izinkan'));
      await tester.pumpAndSettle();

      expect(images.requests, 1);
      expect(images.picked, [ScanImageSource.camera]);
      expect(find.text('Tomat'), findsOneWidget);
    });

    testWidgets('kamera: "Nanti" tidak meminta izin sistem', (tester) async {
      final images = _FakeScanImageService()..status = CameraAccess.denied;
      await openScanTab(tester, scan: _FakeScanService(), images: images);

      await tester.tap(find.text('Ambil Foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();

      expect(images.requests, 0);
      expect(images.picked, isEmpty);
    });

    testWidgets('kamera ditolak permanen → arahkan ke Pengaturan',
        (tester) async {
      final images = _FakeScanImageService()
        ..status = CameraAccess.permanentlyDenied;
      await openScanTab(tester, scan: _FakeScanService(), images: images);

      await tester.tap(find.text('Ambil Foto'));
      await tester.pumpAndSettle();
      expect(find.text('Akses kamera diblokir'), findsOneWidget);
      await tester.tap(find.text('Buka Pengaturan'));
      await tester.pumpAndSettle();

      expect(images.settingsOpened, isTrue);
      expect(images.picked, isEmpty);
    });

    testWidgets('API key belum diatur → banner & pesan error', (tester) async {
      final scan = _FakeScanService()..configured = false;
      await openScanTab(
        tester,
        scan: scan,
        images: _FakeScanImageService(),
      );

      expect(find.textContaining('API key belum diatur'), findsOneWidget);
      await tester.tap(find.text('Galeri'));
      await tester.pumpAndSettle();
      expect(find.text('API key AI belum diatur.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('Hasil Analisis (2 bahan)'), findsNothing);
    });
  });
}
/// PNG 1x1 transparan.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

class _FakeScanService implements StockScanService {
  bool configured = true;
  int calls = 0;
  DateTime? lastToday;

  @override
  bool get isConfigured => configured;

  @override
  Future<ScanResult> analyze(
    Uint8List imageBytes, {
    required String mimeType,
    required DateTime today,
  }) async {
    calls++;
    lastToday = today;
    if (!configured) {
      throw const ScanException('API key AI belum diatur.');
    }
    return ScanResult(
      isFood: true,
      summary: 'Sayur dan susu kemasan',
      items: [
        ScannedItem(
          name: 'Tomat',
          category: FoodCategory.sayur,
          quality: ScanQuality.gradeB,
          freshnessScore: 72,
          quantity: 2.5,
          unit: StockUnit.kg,
          expiryDate: DateTime(2026, 11, 17),
          expirySource: ExpirySource.estimate,
          reason: 'Sedikit lunak',
          recommendation: 'Jual dengan diskon',
        ),
        ScannedItem(
          name: 'Susu UHT',
          category: FoodCategory.susuOlahan,
          quality: ScanQuality.rejected,
          freshnessScore: 10,
          unit: StockUnit.pcs,
          expiryDate: DateTime(2026, 11, 10),
          expirySource: ExpirySource.label,
        ),
      ],
    );
  }
}

class _FakeScanImageService implements ScanImageService {
  CameraAccess status = CameraAccess.granted;
  CameraAccess requestResult = CameraAccess.granted;
  int requests = 0;
  bool settingsOpened = false;
  final picked = <ScanImageSource>[];

  @override
  Future<CameraAccess> cameraStatus() async => status;

  @override
  Future<CameraAccess> requestCamera() async {
    requests++;
    return status = requestResult;
  }

  @override
  Future<bool> openSettings() async => settingsOpened = true;

  @override
  Future<PickedImage?> pick(ScanImageSource source) async {
    picked.add(source);
    return PickedImage(bytes: _pngBytes, mimeType: 'image/png');
  }
}
class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository({this.market, this.match});

  final _FakeMarketRepository? market;
  final _FakeMatchRepository? match;
  final List<ActivityEntry> entries = [];
  final List<int> completedOrders = [];
  final List<int> completedBarters = [];

  @override
  Future<List<ActivityEntry>> listActivity(int userId) async =>
      entries.where((e) => e.userId == userId).toList();

  @override
  Future<void> completeOrder(
    int orderId, {
    required int actorId,
    required DateTime now,
  }) async {
    completedOrders.add(orderId);
    final orders = market!.orders;
    final i = orders.indexWhere((o) => o.id == orderId);
    final order = orders[i];
    orders[i] = order.copyWith(status: OrderStatus.completed);
    entries.add(ActivityEntry(
      userId: actorId,
      kind: ActivityKind.sale,
      counterpartId: order.buyerId,
      counterpartName: order.buyerName ?? 'Pembeli',
      stockName: order.stockName ?? 'Stok',
      category: FoodCategory.sayur,
      quantity: order.quantity,
      unit: order.unit ?? StockUnit.kg,
      amount: order.totalPrice,
      savedValue: order.totalPrice,
      weightKg: order.quantity,
      referenceType: 'order',
      referenceId: orderId,
      createdAt: now,
    ));
  }

  @override
  Future<void> completeBarter(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) async {
    completedBarters.add(barterId);
    final barters = match!.barters;
    final i = barters.indexWhere((b) => b.id == barterId);
    barters[i] = barters[i].copyWith(status: BarterStatus.completed);
  }
}
PartnerProfile _partnerProfile(
  int id,
  String name, {
  String role = 'seller',
  Set<FoodCategory> wants = const {},
  List<StockItem> stocks = const [],
  double? distance,
}) => PartnerProfile(
  userId: id,
  name: name,
  role: role,
  businessCategory: BusinessCategory.warungMakan,
  address: 'Jl. $name',
  distanceKm: distance,
  preferredCategories: wants,
  stocks: stocks,
);

extension on StockItem {
  StockItem withUser(int userId) => StockItem(
    id: id,
    userId: userId,
    name: name,
    category: category,
    quantity: quantity,
    unit: unit,
    pricePerUnit: pricePerUnit,
    expiryDate: expiryDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class _FakeMatchRepository implements MatchRepository {
  final List<PartnerProfile> partners = [];
  final List<Barter> barters = [];
  final List<BarterMessage> messages = [];
  int _nextId = 100;

  @override
  Future<List<PartnerProfile>> listPartners({required AuthUser viewer}) async =>
      partners.where((p) => p.userId != viewer.id).toList();

  @override
  Future<List<Barter>> listBarters(int userId) async => barters
      .where((b) => b.proposerId == userId || b.receiverId == userId)
      .toList();

  @override
  Future<List<BarterMessage>> listMessages(int barterId) async =>
      messages.where((m) => m.barterId == barterId).toList();

  @override
  Future<Barter> createBarter(Barter barter, {String? message}) async {
    final receiver = partners.where((p) => p.userId == barter.receiverId);
    final saved = Barter(
      id: _nextId++,
      type: barter.type,
      proposerId: barter.proposerId,
      receiverId: barter.receiverId,
      offeredStockId: barter.offeredStockId,
      offeredQuantity: barter.offeredQuantity,
      requestedStockId: barter.requestedStockId,
      requestedQuantity: barter.requestedQuantity,
      requestedNote: barter.requestedNote,
      lastActorId: barter.lastActorId,
      createdAt: barter.createdAt,
      updatedAt: barter.updatedAt,
      receiverName: receiver.isEmpty ? null : receiver.first.name,
    );
    barters.add(saved);
    return saved;
  }

  int _index(int id) => barters.indexWhere((b) => b.id == id);

  @override
  Future<void> counterOffer(
    int barterId, {
    required int actorId,
    required double offeredQuantity,
    double? requestedQuantity,
    String? message,
    required DateTime now,
  }) async {
    final i = _index(barterId);
    barters[i] = barters[i].copyWith(
      offeredQuantity: offeredQuantity,
      requestedQuantity: requestedQuantity,
      status: BarterStatus.negotiating,
      lastActorId: actorId,
      updatedAt: now,
    );
    messages.add(BarterMessage(
      id: _nextId++,
      barterId: barterId,
      senderId: actorId,
      text: 'Mengajukan tawaran balik.',
      offeredQuantity: offeredQuantity,
      requestedQuantity: requestedQuantity,
      createdAt: now,
    ));
  }

  @override
  Future<void> respond(
    int barterId, {
    required int actorId,
    required bool accept,
    required DateTime now,
  }) async {
    final i = _index(barterId);
    barters[i] = barters[i].copyWith(
      status: accept ? BarterStatus.accepted : BarterStatus.rejected,
      lastActorId: actorId,
    );
  }

  @override
  Future<void> cancel(
    int barterId, {
    required int actorId,
    required DateTime now,
  }) async {
    final i = _index(barterId);
    barters[i] = barters[i].copyWith(status: BarterStatus.cancelled);
  }

  @override
  Future<void> sendMessage(
    int barterId, {
    required int senderId,
    required String text,
    required DateTime now,
  }) async => messages.add(BarterMessage(
    id: _nextId++,
    barterId: barterId,
    senderId: senderId,
    text: text,
    createdAt: now,
  ));
}
class _FakeMarketRepository implements MarketRepository {
  final List<MarketListing> listings = [];
  final List<MarketOrder> orders = [];
  int _nextId = 100;

  @override
  Future<List<MarketListing>> listListings({
    required AuthUser viewer,
    required DateTime now,
  }) async =>
      listings.where((l) => l.sellerId != viewer.id).toList();

  @override
  Future<List<MarketOrder>> listOrders(int userId) async => orders
      .where((o) => o.buyerId == userId || o.sellerId == userId)
      .toList();

  @override
  Future<MarketOrder> createOrder({
    required int promotionId,
    required int buyerId,
    required double quantity,
    String? note,
    required DateTime now,
  }) async {
    final listing = listings.firstWhere((l) => l.promotionId == promotionId);
    final order = MarketOrder(
      id: _nextId++,
      promotionId: promotionId,
      buyerId: buyerId,
      sellerId: listing.sellerId,
      quantity: quantity,
      unitPrice: listing.promotion.promoPrice,
      note: note,
      createdAt: now,
      updatedAt: now,
      stockName: listing.stockName,
      unit: listing.unit,
      sellerName: listing.sellerName,
    );
    orders.add(order);
    return order;
  }

  @override
  Future<void> updateOrderStatus(
    int orderId,
    OrderStatus status, {
    required DateTime now,
  }) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    orders[index] = orders[index].copyWith(status: status, updatedAt: now);
  }
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

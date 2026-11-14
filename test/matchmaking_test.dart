import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';
import 'package:operin/data/match_repository.dart';
import 'package:operin/data/profile_repository.dart';
import 'package:operin/data/stock_repository.dart';
import 'package:operin/features/matchmaking/matchmaking_engine.dart';
import 'package:operin/model/barter.dart';
import 'package:operin/model/business_category.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/partner_profile.dart';
import 'package:operin/model/stock_item.dart';

final _now = DateTime(2026, 11, 14, 10);

StockItem _stock(
  String name,
  FoodCategory category,
  int daysLeft, {
  int userId = 1,
  int? id,
  double quantity = 10,
}) => StockItem(
  id: id,
  userId: userId,
  name: name,
  category: category,
  quantity: quantity,
  unit: StockUnit.kg,
  pricePerUnit: 10000,
  expiryDate: DateTime(2026, 11, 14 + daysLeft),
  createdAt: _now,
  updatedAt: _now,
);

PartnerProfile _partner(
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

void main() {
  // Database terpisah per file test agar aman dijalankan paralel.
  LocalDatabase.fileName = 'test_matchmaking.db';

  group('MatchmakingEngine', () {
    const engine = MatchmakingEngine();
    final myStocks = [
      _stock('Roti Tawar', FoodCategory.roti, 1), // kritis
      _stock('Beras', FoodCategory.bahanKering, 30),
      _stock('Susu Basi', FoodCategory.susuOlahan, -2), // kedaluwarsa
    ];

    List<PartnerMatch> run(List<PartnerProfile> partners, {int? radius}) =>
        engine.match(
          partners: partners,
          myStocks: myStocks,
          myPreferences: {FoodCategory.sayur},
          now: _now,
          radiusKm: radius,
        );

    test('mitra yang saling membutuhkan diprioritaskan', () {
      final result = run([
        _partner(2, 'Hanya Jual Sayur',
            stocks: [_stock('Bayam', FoodCategory.sayur, 2, userId: 2)]),
        _partner(3, 'Saling Butuh',
            wants: {FoodCategory.roti},
            stocks: [_stock('Kangkung', FoodCategory.sayur, 2, userId: 3)]),
        _partner(4, 'Tidak Cocok', wants: {FoodCategory.dagingIkan}),
      ]);

      expect(result.map((m) => m.partner.name), ['Saling Butuh', 'Hanya Jual Sayur']);
      final best = result.first;
      expect(best.isMutual, isTrue);
      expect(best.theyNeed.single.name, 'Roti Tawar');
      expect(best.theyHave.single.name, 'Kangkung');
      expect(best.reasons.first, 'Saling membutuhkan, cocok untuk barter');
      expect(best.reasons, contains(contains('1 stok kritis')));
    });

    test('stok kedaluwarsa tidak ditawarkan, kecuali ke mitra daur ulang', () {
      final result = run([
        _partner(2, 'Butuh Susu', wants: {FoodCategory.susuOlahan}),
        _partner(3, 'Kompos', role: 'waste'),
      ]);
      expect(result.map((m) => m.partner.name), ['Kompos']);
      expect(result.single.recyclable.single.name, 'Susu Basi');
    });

    test('stok mitra yang kedaluwarsa diabaikan & radius dihormati', () {
      final result = run([
        _partner(2, 'Sayur Basi',
            stocks: [_stock('Sawi', FoodCategory.sayur, -1, userId: 2)]),
        _partner(3, 'Jauh',
            distance: 25,
            stocks: [_stock('Tomat', FoodCategory.sayur, 3, userId: 3)]),
        _partner(4, 'Dekat',
            distance: 2,
            stocks: [_stock('Tomat', FoodCategory.sayur, 3, userId: 4)]),
      ], radius: 10);
      expect(result.map((m) => m.partner.name), ['Dekat']);
    });
  });

  test('SqliteMatchRepository: mitra, barter, negosiasi, dan donasi', () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const auth = SqliteAuthRepository();
    const profiles = SqliteProfileRepository();
    const stocks = SqliteStockRepository();
    const repo = SqliteMatchRepository();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final emails = [
      'match-a-$stamp@operin.test',
      'match-b-$stamp@operin.test',
      'match-c-$stamp@operin.test',
    ];

    Future<int> user(int i, String role, Set<FoodCategory> wants) async {
      final registered = await auth.register(
        fullName: 'User $i',
        email: emails[i],
        password: 'password123',
        businessType: 'warungMakan',
        address: 'Jl. $i',
        latitude: -0.95,
        longitude: 100.35 + i * 0.01,
      );
      await auth.updateRole(registered.id!, role);
      await profiles.saveProfile(BusinessProfile(
        userId: registered.id!,
        businessName: 'Usaha $i',
        whatsapp: '6281200000000',
        preferredCategories: wants,
        radiusKm: 10,
        notifyExpiry: true,
        notifyDaysBefore: 2,
        updatedAt: _now,
      ));
      return registered.id!;
    }

    try {
      final a = await user(0, 'seller', {FoodCategory.sayur});
      final b = await user(1, 'seller', {FoodCategory.roti});
      final c = await user(2, 'waste', {});

      final roti = await stocks.insert(
          _stock('Roti Tawar', FoodCategory.roti, 1, userId: a, quantity: 10));
      final basi = await stocks.insert(
          _stock('Susu Basi', FoodCategory.susuOlahan, -2, userId: a));
      final bayam = await stocks.insert(
          _stock('Bayam', FoodCategory.sayur, 2, userId: b, quantity: 5));

      // Daftar mitra untuk A: B & C (dengan stok & jarak), bukan A sendiri
      final viewer = (await auth.login(email: emails[0], password: 'password123'));
      final partners = await repo.listPartners(viewer: viewer);
      final mine = partners.where((p) => [b, c].contains(p.userId)).toList();
      expect(mine, hasLength(2));
      expect(partners.any((p) => p.userId == a), isFalse);
      final partnerB = mine.firstWhere((p) => p.userId == b);
      expect(partnerB.name, 'Usaha 1');
      expect(partnerB.stocks.single.name, 'Bayam');
      expect(partnerB.distanceKm, closeTo(1.11, 0.05));

      Barter proposal({double offered = 4, double requested = 3}) => Barter(
        type: BarterType.barter,
        proposerId: a,
        receiverId: b,
        offeredStockId: roti.id!,
        offeredQuantity: offered,
        requestedStockId: bayam.id,
        requestedQuantity: requested,
        lastActorId: a,
        createdAt: _now,
        updatedAt: _now,
      );

      // Validasi jumlah
      await expectLater(
        repo.createBarter(proposal(offered: 11)),
        throwsA(isA<BarterException>()),
      );
      await expectLater(
        repo.createBarter(proposal(requested: 6)),
        throwsA(isA<BarterException>()),
      );

      final barter = await repo.createBarter(proposal(), message: 'Halo!');
      var list = await repo.listBarters(b);
      expect(list.single.offeredStockName, 'Roti Tawar');
      expect(list.single.requestedStockName, 'Bayam');
      expect(list.single.proposerName, 'Usaha 0');
      expect(list.single.awaitingResponseFrom(b), isTrue);

      // A tidak bisa menjawab tawarannya sendiri
      await expectLater(
        repo.respond(barter.id!, actorId: a, accept: true, now: _now),
        throwsA(isA<BarterException>()),
      );

      // B menawar balik → giliran A
      await repo.counterOffer(barter.id!,
          actorId: b, offeredQuantity: 5, requestedQuantity: 2, now: _now);
      list = await repo.listBarters(a);
      expect(list.single.status, BarterStatus.negotiating);
      expect(list.single.offeredQuantity, 5);
      expect(list.single.requestedQuantity, 2);
      expect(list.single.awaitingResponseFrom(a), isTrue);

      await repo.sendMessage(barter.id!, senderId: a, text: 'Oke', now: _now);
      await repo.respond(barter.id!, actorId: a, accept: true, now: _now);
      list = await repo.listBarters(a);
      expect(list.single.status, BarterStatus.accepted);
      await expectLater(
        repo.cancel(barter.id!, actorId: a, now: _now),
        throwsA(isA<BarterException>()),
      );

      final messages = await repo.listMessages(barter.id!);
      expect(messages.map((m) => m.text),
          ['Halo!', 'Mengajukan tawaran balik.', 'Oke', 'Menyetujui kesepakatan.']);
      expect(messages[1].isCounterOffer, isTrue);
      expect(messages[1].senderName, 'Usaha 1');

      // Donasi stok kedaluwarsa ke mitra daur ulang, lalu dibatalkan pengaju
      final donation = await repo.createBarter(Barter(
        type: BarterType.donation,
        proposerId: a,
        receiverId: c,
        offeredStockId: basi.id!,
        offeredQuantity: 10,
        lastActorId: a,
        createdAt: _now,
        updatedAt: _now,
      ));
      await expectLater(
        repo.cancel(donation.id!, actorId: c, now: _now),
        throwsA(isA<BarterException>()),
      );
      await repo.cancel(donation.id!, actorId: a, now: _now);
      final forC = await repo.listBarters(c);
      expect(forC.single.type, BarterType.donation);
      expect(forC.single.status, BarterStatus.cancelled);
    } finally {
      final database = await LocalDatabase.instance.database;
      for (final email in emails) {
        await database.delete('users', where: 'email = ?', whereArgs: [email]);
      }
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

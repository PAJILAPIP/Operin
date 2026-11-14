import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';
import 'package:operin/data/market_repository.dart';
import 'package:operin/data/match_repository.dart';
import 'package:operin/data/profile_repository.dart';
import 'package:operin/data/promotion_repository.dart';
import 'package:operin/data/stock_repository.dart';
import 'package:operin/data/transaction_repository.dart';
import 'package:operin/features/impact/impact_calculator.dart';
import 'package:operin/model/activity_entry.dart';
import 'package:operin/model/barter.dart';
import 'package:operin/model/business_profile.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/market_order.dart';
import 'package:operin/model/promotion.dart';
import 'package:operin/model/stock_item.dart';

final _now = DateTime(2026, 11, 14, 10);

ActivityEntry _entry(
  ActivityKind kind, {
  int saved = 0,
  double weight = 0,
  int counterpart = 2,
  DateTime? at,
  int ref = 1,
}) => ActivityEntry(
  userId: 1,
  kind: kind,
  counterpartId: counterpart,
  counterpartName: 'Mitra $counterpart',
  stockName: 'Roti',
  category: FoodCategory.roti,
  quantity: 1,
  unit: StockUnit.kg,
  amount: 0,
  savedValue: saved,
  weightKg: weight,
  referenceType: 'order',
  referenceId: ref,
  createdAt: at ?? _now,
);

void main() {
  LocalDatabase.fileName = 'test_transaction.db';

  group('ImpactCalculator', () {
    const calc = ImpactCalculator();

    test('menjumlah nilai, limbah keluar, mitra unik, CO2', () {
      final summary = calc.compute([
        _entry(ActivityKind.sale, saved: 30000, weight: 3, counterpart: 2),
        _entry(ActivityKind.purchase, saved: 5000, weight: 2, counterpart: 3,
            ref: 2),
        _entry(ActivityKind.donationOut, weight: 4, counterpart: 3, ref: 3),
        _entry(ActivityKind.barterIn, weight: 1, counterpart: 2, ref: 4),
      ], _now);

      expect(summary.savedValue, 35000);
      expect(summary.wasteKg, 7); // hanya aktivitas keluar: 3 + 4
      expect(summary.co2Kg, 17.5);
      expect(summary.partnersHelped, 2);
      expect(summary.transactionCount, 4);
      expect(summary.countByKind[ActivityKind.sale], 1);
    });

    test('perbandingan bulanan & 6 bucket bulan', () {
      final summary = calc.compute([
        _entry(ActivityKind.sale, saved: 15000),
        _entry(ActivityKind.sale, saved: 10000, at: DateTime(2026, 10, 3), ref: 2),
        _entry(ActivityKind.sale, saved: 99000, at: DateTime(2025, 1, 1), ref: 3),
      ], _now);

      expect(summary.savedThisMonth, 15000);
      expect(summary.savedLastMonth, 10000);
      expect(summary.monthlyChangePercent, 50);
      expect(summary.months.map((m) => m.month.month), [6, 7, 8, 9, 10, 11]);
      expect(summary.months.last.savedValue, 15000);
      expect(summary.savedValue, 124000); // total tetap semua waktu
    });

    test('tanpa data → nol, bulan lalu kosong → persen null', () {
      final empty = calc.compute(const [], _now);
      expect(empty.savedValue, 0);
      expect(empty.months, hasLength(6));
      expect(empty.monthlyChangePercent, isNull);
    });
  });

  group('SqliteTransactionRepository', () {
    const auth = SqliteAuthRepository();
    const profiles = SqliteProfileRepository();
    const stocks = SqliteStockRepository();
    const promotions = SqlitePromotionRepository();
    const market = SqliteMarketRepository();
    const match = SqliteMatchRepository();
    const transactions = SqliteTransactionRepository();

    late List<String> emails;
    late TargetPlatform? previousPlatform;

    setUp(() {
      previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final stamp = DateTime.now().microsecondsSinceEpoch;
      emails = ['tx-a-$stamp@operin.test', 'tx-b-$stamp@operin.test'];
    });

    tearDown(() async {
      final database = await LocalDatabase.instance.database;
      for (final email in emails) {
        await database.delete('users', where: 'email = ?', whereArgs: [email]);
      }
      debugDefaultTargetPlatformOverride = previousPlatform;
    });

    Future<int> user(int i) async {
      final u = await auth.register(
        fullName: 'User $i',
        email: emails[i],
        password: 'password123',
        businessType: 'bakery',
        address: 'Jl. $i',
      );
      await profiles.saveProfile(BusinessProfile(
        userId: u.id!,
        businessName: 'Usaha $i',
        whatsapp: '6281200000000',
        preferredCategories: const {FoodCategory.roti},
        radiusKm: 10,
        notifyExpiry: true,
        notifyDaysBefore: 2,
        updatedAt: _now,
      ));
      return u.id!;
    }

    Future<StockItem> stock(int owner, String name, double qty,
            {StockUnit unit = StockUnit.pcs}) =>
        stocks.insert(StockItem(
          userId: owner,
          name: name,
          category: FoodCategory.roti,
          quantity: qty,
          unit: unit,
          pricePerUnit: 10000,
          expiryDate: DateTime(2026, 11, 16),
          createdAt: _now,
          updatedAt: _now,
        ));

    test('pesanan selesai: stok pindah, status selesai, riwayat 2 sisi',
        () async {
      final seller = await user(0);
      final buyer = await user(1);
      final roti = await stock(seller, 'Roti Gandum', 10);
      final promo = await promotions.insert(Promotion(
        userId: seller,
        stockId: roti.id!,
        type: PromotionType.discount,
        discountPercent: 40,
        originalPrice: 10000,
        quantity: 10,
        createdAt: _now,
        endsAt: DateTime(2026, 11, 17),
      ));
      final order = await market.createOrder(
        promotionId: promo.id!,
        buyerId: buyer,
        quantity: 4,
        now: _now,
      );

      // Belum diterima → tidak bisa diselesaikan
      await expectLater(
        transactions.completeOrder(order.id!, actorId: seller, now: _now),
        throwsA(isA<TransactionException>()),
      );
      await market.updateOrderStatus(order.id!, OrderStatus.accepted, now: _now);
      // Pembeli tidak boleh menyelesaikan
      await expectLater(
        transactions.completeOrder(order.id!, actorId: buyer, now: _now),
        throwsA(isA<TransactionException>()),
      );

      await transactions.completeOrder(order.id!, actorId: seller, now: _now);

      final sellerStock = await stocks.listByUser(seller);
      expect(sellerStock.single.quantity, 6);
      final buyerStock = await stocks.listByUser(buyer);
      expect(buyerStock.single.name, 'Roti Gandum');
      expect(buyerStock.single.quantity, 4);
      expect(buyerStock.single.pricePerUnit, 6000); // harga yang dibayar
      expect(buyerStock.single.notes, 'Dibeli dari Usaha 0');

      final orders = await market.listOrders(seller);
      expect(orders.single.status, OrderStatus.completed);

      final sale = (await transactions.listActivity(seller)).single;
      expect(sale.kind, ActivityKind.sale);
      expect(sale.amount, 24000);
      expect(sale.savedValue, 24000);
      expect(sale.weightKg, closeTo(0.8, 1e-9)); // 4 pcs × 0,2 kg
      expect(sale.counterpartName, 'Usaha 1');

      final purchase = (await transactions.listActivity(buyer)).single;
      expect(purchase.kind, ActivityKind.purchase);
      expect(purchase.savedValue, 16000); // hemat 4.000 × 4

      // Tidak bisa diselesaikan dua kali
      await expectLater(
        transactions.completeOrder(order.id!, actorId: seller, now: _now),
        throwsA(isA<TransactionException>()),
      );
    });

    test('barter selesai: stok tertukar di kedua pihak', () async {
      final a = await user(0);
      final b = await user(1);
      final roti = await stock(a, 'Roti', 10);
      final sayur = await stock(b, 'Bayam', 5, unit: StockUnit.kg);
      final barter = await match.createBarter(Barter(
        type: BarterType.barter,
        proposerId: a,
        receiverId: b,
        offeredStockId: roti.id!,
        offeredQuantity: 6,
        requestedStockId: sayur.id,
        requestedQuantity: 2,
        lastActorId: a,
        createdAt: _now,
        updatedAt: _now,
      ));

      await expectLater(
        transactions.completeBarter(barter.id!, actorId: a, now: _now),
        throwsA(isA<TransactionException>()),
      );
      await match.respond(barter.id!, actorId: b, accept: true, now: _now);
      await transactions.completeBarter(barter.id!, actorId: b, now: _now);

      final aStock = {
        for (final s in await stocks.listByUser(a)) s.name: s.quantity,
      };
      final bStock = {
        for (final s in await stocks.listByUser(b)) s.name: s.quantity,
      };
      expect(aStock, {'Roti': 4, 'Bayam': 2});
      expect(bStock, {'Roti': 6, 'Bayam': 3});

      final barters = await match.listBarters(a);
      expect(barters.single.status, BarterStatus.completed);

      final aLog = await transactions.listActivity(a);
      expect(aLog.map((e) => e.kind).toSet(),
          {ActivityKind.barterOut, ActivityKind.barterIn});
      final aOut = aLog.firstWhere((e) => e.kind == ActivityKind.barterOut);
      expect(aOut.savedValue, 60000);
      final bOut = (await transactions.listActivity(b))
          .firstWhere((e) => e.kind == ActivityKind.barterOut);
      expect(bOut.stockName, 'Bayam');
      expect(bOut.weightKg, 2);
    });

    test('donasi selesai: stok pengaju berkurang, penerima tidak dapat stok',
        () async {
      final a = await user(0);
      final b = await user(1);
      final basi = await stock(a, 'Roti Basi', 5);
      final donation = await match.createBarter(Barter(
        type: BarterType.donation,
        proposerId: a,
        receiverId: b,
        offeredStockId: basi.id!,
        offeredQuantity: 5,
        lastActorId: a,
        createdAt: _now,
        updatedAt: _now,
      ));
      await match.respond(donation.id!, actorId: b, accept: true, now: _now);

      // Stok berkurang sebelum diselesaikan → ditolak
      await stocks.update(basi.copyWith(quantity: 3));
      await expectLater(
        transactions.completeBarter(donation.id!, actorId: a, now: _now),
        throwsA(isA<TransactionException>()),
      );
      await stocks.update(basi.copyWith(quantity: 5));

      await transactions.completeBarter(donation.id!, actorId: a, now: _now);
      expect((await stocks.listByUser(a)).single.quantity, 0);
      expect(await stocks.listByUser(b), isEmpty);
      final out = (await transactions.listActivity(a)).single;
      expect(out.kind, ActivityKind.donationOut);
      expect(out.savedValue, 0);
      expect(out.weightKg, 1); // 5 pcs × 0,2 kg
      expect((await transactions.listActivity(b)).single.kind,
          ActivityKind.donationIn);
    });
  });
}

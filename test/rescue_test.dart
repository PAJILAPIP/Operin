import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operin/data/auth_repository.dart';
import 'package:operin/data/local_database.dart';
import 'package:operin/data/promotion_repository.dart';
import 'package:operin/data/stock_repository.dart';
import 'package:operin/features/rescue/rescue_advisor.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/promotion.dart';
import 'package:operin/model/stock_item.dart';

final _now = DateTime(2026, 11, 14, 10);

StockItem _item(
  int daysLeft, {
  FoodCategory category = FoodCategory.sayur,
  double quantity = 10,
  int price = 10000,
  int userId = 1,
}) => StockItem(
  id: daysLeft + 100,
  userId: userId,
  name: 'Bahan $daysLeft',
  category: category,
  quantity: quantity,
  unit: StockUnit.kg,
  pricePerUnit: price,
  expiryDate: DateTime(2026, 11, 14 + daysLeft),
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  const advisor = RescueAdvisor();

  group('RescueAdvisor', () {
    RescueRecommendation rec(int days, {FoodCategory? category, int critical = 2}) =>
        advisor.recommend(
          _item(days, category: category ?? FoodCategory.sayur),
          _now,
          criticalDays: critical,
        );

    test('aksi & diskon mengikuti sisa hari (bahan mudah rusak)', () {
      expect(rec(-1).action, RescueAction.recycle);
      expect(rec(-1).discountPercent, 0);
      expect(rec(0).action, RescueAction.flashSale);
      expect(rec(0).discountPercent, 60);
      expect(rec(1).discountPercent, 50);
      expect(rec(2).discountPercent, 40);
      expect(rec(3).discountPercent, 30);
      expect(rec(5).discountPercent, 20);
      expect(rec(7).action, RescueAction.discount);
      expect(rec(8).action, RescueAction.monitor);
    });

    test('bahan tahan lama mendapat diskon 10% lebih kecil', () {
      expect(rec(0, category: FoodCategory.bahanKering).discountPercent, 50);
      expect(rec(1, category: FoodCategory.bahanKering).discountPercent, 40);
      expect(rec(5, category: FoodCategory.bahanKering).discountPercent, 10);
    });

    test('ambang kritis user memperpanjang diskon besar', () {
      // H-3 dengan notifikasi H-3 → masih kategori kritis (min 30%)
      expect(rec(3, critical: 3).discountPercent, 30);
      expect(rec(3, critical: 3).status, StockStatus.critical);
    });

    test('nilai berisiko & potensi diselamatkan', () {
      final r = rec(1); // 10 kg x Rp10.000, diskon 50%
      expect(r.valueAtRisk, 100000);
      expect(r.suggestedPrice, 5000);
      expect(r.potentialRecovery, 50000);
      expect(rec(-1).potentialRecovery, 0);
    });

    test('recommendAll membuang stok aman & urut paling mendesak', () {
      final list = advisor.recommendAll(
        [_item(10), _item(3), _item(-2), _item(0)],
        _now,
      );
      expect(list.map((r) => r.daysLeft), [-2, 0, 3]);
    });
  });

  group('Promotion', () {
    test('harga diskon dibulatkan ke Rp100', () {
      expect(Promotion.priceAfterDiscount(12000, 30), 8400);
      expect(Promotion.priceAfterDiscount(12345, 50), 6200);
      expect(Promotion.priceAfterDiscount(500, 90), 100);
    });

    test('aktif sampai endsAt kecuali dibatalkan', () {
      final promo = Promotion(
        userId: 1,
        stockId: 1,
        type: PromotionType.flashSale,
        discountPercent: 60,
        originalPrice: 10000,
        quantity: 5,
        createdAt: _now,
        endsAt: _now.add(const Duration(hours: 4)),
      );
      expect(promo.isActiveAt(_now), isTrue);
      expect(promo.isActiveAt(_now.add(const Duration(hours: 4))), isFalse);
      expect(
        promo.copyWith(status: PromotionStatus.cancelled).isActiveAt(_now),
        isFalse,
      );
      final restored = Promotion.fromMap(promo.copyWith(id: 3).toMap());
      expect(restored.id, 3);
      expect(restored.type, PromotionType.flashSale);
      expect(restored.promoPrice, 4000);
      expect(restored.endsAt, promo.endsAt);
    });
  });

  test('SqlitePromotionRepository simpan, batalkan, ikut terhapus bersama stok',
      () async {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const auth = SqliteAuthRepository();
    const stocks = SqliteStockRepository();
    const promotions = SqlitePromotionRepository();
    final email = 'promo-${DateTime.now().microsecondsSinceEpoch}@operin.test';

    try {
      final user = await auth.register(
        fullName: 'Promo',
        email: email,
        password: 'password123',
        businessType: 'bakery',
        address: 'Padang',
      );
      // insert() mengabaikan id bawaan dan memakai id dari database.
      final stock = await stocks.insert(_item(1, userId: user.id!));

      final saved = await promotions.insert(Promotion(
        userId: user.id!,
        stockId: stock.id!,
        type: PromotionType.discount,
        discountPercent: 50,
        originalPrice: 10000,
        quantity: 10,
        createdAt: _now,
        endsAt: DateTime(2026, 11, 16),
      ));
      expect(saved.id, isNotNull);

      var list = await promotions.listByUser(user.id!);
      expect(list.single.discountPercent, 50);
      expect(list.single.status, PromotionStatus.active);

      await promotions.updateStatus(saved.id!, PromotionStatus.cancelled);
      list = await promotions.listByUser(user.id!);
      expect(list.single.status, PromotionStatus.cancelled);

      await stocks.delete(stock.id!);
      expect(await promotions.listByUser(user.id!), isEmpty);
    } finally {
      final database = await LocalDatabase.instance.database;
      await database.delete('users', where: 'email = ?', whereArgs: [email]);
      debugDefaultTargetPlatformOverride = previousPlatform;
    }
  });
}

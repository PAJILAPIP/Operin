import 'package:flutter_test/flutter_test.dart';
import 'package:operin/features/matchmaking/matchmaking_engine.dart';
import 'package:operin/model/business_category.dart';
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:operin/features/impact/impact_calculator.dart';
import 'package:operin/model/activity_entry.dart';
import 'package:operin/model/food_category.dart';
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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:operin/core/utils/formatters.dart';
import 'package:operin/model/food_category.dart';
import 'package:operin/model/stock_item.dart';

StockItem _item({
  required DateTime expiry,
  String name = 'Tomat',
  int userId = 1,
  double quantity = 2.5,
  int price = 12000,
}) => StockItem(
  userId: userId,
  name: name,
  category: FoodCategory.sayur,
  quantity: quantity,
  unit: StockUnit.kg,
  pricePerUnit: price,
  expiryDate: expiry,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

void main() {
  // Database terpisah per file test agar aman dijalankan paralel.

  // Jam 23:30 untuk memastikan perhitungan hari hanya memakai tanggal.
  final now = DateTime(2026, 11, 14, 23, 30);

  group('StockItem status', () {
    test('sisa hari & status mengikuti tanggal saja', () {
      expect(_item(expiry: DateTime(2026, 11, 13)).daysUntilExpiry(now), -1);
      expect(_item(expiry: DateTime(2026, 11, 14)).daysUntilExpiry(now), 0);
      expect(_item(expiry: DateTime(2026, 11, 15)).daysUntilExpiry(now), 1);

      StockStatus status(int day, {int critical = 2}) =>
          _item(expiry: DateTime(2026, 11, day))
              .statusAt(now, criticalDays: critical);

      expect(status(13), StockStatus.expired);
      expect(status(14), StockStatus.critical);
      expect(status(16), StockStatus.critical);
      expect(status(17), StockStatus.soon);
      expect(status(21), StockStatus.soon);
      expect(status(22), StockStatus.fresh);
      // Ambang kritis mengikuti pengaturan notifikasi user (H-3)
      expect(status(17, critical: 3), StockStatus.critical);
    });

    test('label kedaluwarsa', () {
      expect(_item(expiry: DateTime(2026, 11, 12)).expiryLabel(now),
          'Lewat 2 hari');
      expect(_item(expiry: DateTime(2026, 11, 14)).expiryLabel(now),
          'Hari ini');
      expect(_item(expiry: DateTime(2026, 11, 17)).expiryLabel(now), 'H-3');
    });

    test('total nilai dibulatkan', () {
      expect(_item(expiry: now, quantity: 2.5, price: 12000).totalValue,
          30000);
    });

    test('toMap/fromMap bolak-balik', () {
      final original = _item(expiry: DateTime(2026, 12, 1)).copyWith(
        id: 7,
        notes: 'Grade B',
      );
      final restored = StockItem.fromMap(original.toMap());
      expect(restored.id, 7);
      expect(restored.name, original.name);
      expect(restored.category, FoodCategory.sayur);
      expect(restored.quantity, 2.5);
      expect(restored.unit, StockUnit.kg);
      expect(restored.expiryDate, DateTime(2026, 12, 1));
      expect(restored.notes, 'Grade B');
      expect(original.toMap()['expiry_date'], '2026-12-01');
    });
  });

  group('formatters', () {
    test('rupiah', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(950), 'Rp 950');
      expect(formatRupiah(15000), 'Rp 15.000');
      expect(formatRupiah(15450000), 'Rp 15.450.000');
    });

    test('jumlah', () {
      expect(formatQuantity(25), '25');
      expect(formatQuantity(2.5), '2,5');
      expect(formatQuantity(0.125), '0,13');
    });

    test('parse input', () {
      expect(parseQuantity('2,5'), 2.5);
      expect(parseQuantity('abc'), isNull);
      expect(parseRupiah('Rp 15.000'), 15000);
      expect(parseRupiah(''), isNull);
    });

    test('tanggal', () {
      expect(formatDate(DateTime(2026, 11, 14)), '14 Nov 2026');
    });
  });
}

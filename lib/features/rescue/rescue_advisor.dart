import '../../model/food_category.dart';
import '../../model/promotion.dart';
import '../../model/stock_item.dart';

/// Aksi yang disarankan untuk menyelamatkan stok.
enum RescueAction {
  /// Sudah kedaluwarsa: tidak layak jual, salurkan untuk kompos/pakan.
  recycle('Salurkan ke Daur Ulang'),

  /// Kedaluwarsa hari ini: diskon besar dengan durasi singkat.
  flashSale('Flash Sale'),
  discount('Diskon'),

  /// Masih aman, cukup dipantau.
  monitor('Pantau');

  const RescueAction(this.label);

  final String label;

  bool get canPromote => this == flashSale || this == discount;
}

class RescueRecommendation {
  const RescueRecommendation({
    required this.item,
    required this.status,
    required this.daysLeft,
    required this.action,
    required this.discountPercent,
    required this.reason,
  });

  final StockItem item;
  final StockStatus status;
  final int daysLeft;
  final RescueAction action;

  /// Persen diskon yang disarankan (0 jika tidak ada promo).
  final int discountPercent;
  final String reason;

  int get suggestedPrice =>
      Promotion.priceAfterDiscount(item.pricePerUnit, discountPercent);

  /// Nilai stok yang hilang jika bahan terbuang.
  int get valueAtRisk => item.totalValue;

  /// Perkiraan pemasukan jika seluruh stok terjual dengan harga promo.
  int get potentialRecovery =>
      action.canPromote ? (item.quantity * suggestedPrice).round() : 0;
}

/// Aturan rekomendasi penyelamatan stok berdasarkan sisa masa simpan.
///
/// | Sisa hari            | Aksi        | Diskon (mudah busuk / tahan lama) |
/// |----------------------|-------------|-----------------------------------|
/// | < 0                  | Daur ulang  | -                                 |
/// | 0                    | Flash sale  | 60% / 50%                         |
/// | 1 .. ambang kritis   | Diskon      | 50%, turun 10%/hari, min 30%      |
/// | ≤ 4                  | Diskon      | 30% / 20%                         |
/// | ≤ 7                  | Diskon      | 20% / 10%                         |
/// | > 7                  | Pantau      | -                                 |
class RescueAdvisor {
  const RescueAdvisor();

  /// Kategori yang cepat rusak mendapat diskon lebih besar.
  static const Set<FoodCategory> perishable = {
    FoodCategory.sayur,
    FoodCategory.buah,
    FoodCategory.roti,
    FoodCategory.dagingIkan,
    FoodCategory.susuOlahan,
    FoodCategory.makananJadi,
  };

  RescueRecommendation recommend(
    StockItem item,
    DateTime now, {
    int criticalDays = StockItem.defaultCriticalDays,
  }) {
    final days = item.daysUntilExpiry(now);
    final status = item.statusAt(now, criticalDays: criticalDays);
    final isPerishable = perishable.contains(item.category);
    final adjust = isPerishable ? 0 : -10;

    RescueRecommendation build(RescueAction action, int discount, String why) =>
        RescueRecommendation(
          item: item,
          status: status,
          daysLeft: days,
          action: action,
          discountPercent: discount,
          reason: why,
        );

    if (days < 0) {
      return build(
        RescueAction.recycle,
        0,
        'Sudah melewati masa simpan dan tidak layak dijual. Salurkan ke '
        'mitra daur ulang untuk kompos atau pakan ternak.',
      );
    }
    if (days == 0) {
      return build(
        RescueAction.flashSale,
        60 + adjust,
        'Kedaluwarsa hari ini. Flash sale beberapa jam agar cepat habis '
        'sebelum tutup toko.',
      );
    }
    if (days <= criticalDays) {
      final discount = (50 - (days - 1) * 10).clamp(30, 50) + adjust;
      return build(
        RescueAction.discount,
        discount,
        'Tinggal $days hari. Diskon besar sekarang lebih untung daripada '
        'kehilangan seluruh nilai stok.',
      );
    }
    if (days <= 4) {
      return build(
        RescueAction.discount,
        30 + adjust,
        isPerishable
            ? 'Bahan mudah rusak dan tinggal $days hari. Mulai promo agar '
                'stok berputar.'
            : 'Tinggal $days hari. Promo ringan untuk mempercepat penjualan.',
      );
    }
    if (days <= StockItem.soonDays) {
      return build(
        RescueAction.discount,
        20 + adjust,
        'Kedaluwarsa minggu ini ($days hari lagi). Promo ringan menjaga '
        'margin tetap aman.',
      );
    }
    return build(
      RescueAction.monitor,
      0,
      'Masa simpan masih panjang ($days hari). Cukup dipantau.',
    );
  }

  /// Rekomendasi untuk semua stok yang perlu tindakan (tanpa "Pantau"),
  /// urut dari yang paling mendesak.
  List<RescueRecommendation> recommendAll(
    Iterable<StockItem> items,
    DateTime now, {
    int criticalDays = StockItem.defaultCriticalDays,
  }) {
    return items
        .map((item) => recommend(item, now, criticalDays: criticalDays))
        .where((rec) => rec.action != RescueAction.monitor)
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  }
}

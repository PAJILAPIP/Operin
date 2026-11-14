import '../../model/food_category.dart';
import '../../model/partner_profile.dart';
import '../../model/stock_item.dart';

/// Hasil pencocokan dengan satu mitra.
class PartnerMatch {
  const PartnerMatch({
    required this.partner,
    required this.theyHave,
    required this.theyNeed,
    required this.recyclable,
    required this.score,
    required this.reasons,
  });

  final PartnerProfile partner;

  /// Stok mitra (belum kedaluwarsa) yang termasuk kategori minat saya.
  final List<StockItem> theyHave;

  /// Stok saya (belum kedaluwarsa) yang termasuk kategori minat mitra.
  final List<StockItem> theyNeed;

  /// Stok kedaluwarsa saya yang bisa disalurkan (hanya untuk mitra daur
  /// ulang).
  final List<StockItem> recyclable;

  final double score;
  final List<String> reasons;

  /// Kedua pihak saling membutuhkan → kandidat barter terbaik.
  bool get isMutual => theyHave.isNotEmpty && theyNeed.isNotEmpty;
}

/// Mencocokkan UMKM berdasarkan kategori minat, stok, urgensi, dan jarak.
///
/// Skor (semakin tinggi semakin cocok):
/// - +3 per stok mitra yang saya minati (maks. 3 dihitung)
/// - +4 per stok saya yang mitra minati (maks. 3), +2 lagi jika stok itu
///   kritis/kedaluwarsa sebentar lagi
/// - +6 jika saling membutuhkan (cocok untuk barter)
/// - +5 per stok kedaluwarsa saya untuk mitra daur ulang (maks. 3)
/// - −0,5 per km jarak
class MatchmakingEngine {
  const MatchmakingEngine();

  List<PartnerMatch> match({
    required List<PartnerProfile> partners,
    required List<StockItem> myStocks,
    required Set<FoodCategory> myPreferences,
    required DateTime now,
    int criticalDays = StockItem.defaultCriticalDays,
    int? radiusKm,
  }) {
    final mySellable =
        myStocks.where((s) => s.daysUntilExpiry(now) >= 0).toList();
    final myExpired =
        myStocks.where((s) => s.daysUntilExpiry(now) < 0).toList();

    final results = <PartnerMatch>[];
    for (final partner in partners) {
      final distance = partner.distanceKm;
      if (radiusKm != null && distance != null && distance > radiusKm) {
        continue;
      }

      final theyHave = partner.stocks
          .where((s) =>
              s.daysUntilExpiry(now) >= 0 &&
              s.quantity > 0 &&
              myPreferences.contains(s.category))
          .toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      final theyNeed = mySellable
          .where((s) => partner.preferredCategories.contains(s.category))
          .toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      final recyclable =
          partner.isRecyclePartner ? myExpired : const <StockItem>[];

      var score = 0.0;
      final reasons = <String>[];

      if (theyHave.isNotEmpty) {
        score += 3.0 * theyHave.length.clamp(0, 3);
        reasons.add('Punya ${_categories(theyHave)} yang Anda cari');
      }
      if (theyNeed.isNotEmpty) {
        score += 4.0 * theyNeed.length.clamp(0, 3);
        final urgent = theyNeed
            .where((s) => s.statusAt(now, criticalDays: criticalDays).needsAction)
            .length;
        score += 2.0 * urgent.clamp(0, 3);
        reasons.add(
          urgent > 0
              ? 'Butuh ${_categories(theyNeed)}: bisa selamatkan $urgent stok kritis Anda'
              : 'Butuh ${_categories(theyNeed)} yang Anda miliki',
        );
      }
      if (theyHave.isNotEmpty && theyNeed.isNotEmpty) {
        score += 6;
        reasons.insert(0, 'Saling membutuhkan, cocok untuk barter');
      }
      if (recyclable.isNotEmpty) {
        score += 5.0 * recyclable.length.clamp(0, 3);
        reasons.add('Mitra daur ulang untuk ${recyclable.length} stok kedaluwarsa');
      }
      if (score == 0) continue;
      if (distance != null) score -= distance * 0.5;

      results.add(PartnerMatch(
        partner: partner,
        theyHave: theyHave,
        theyNeed: theyNeed,
        recyclable: recyclable,
        score: score,
        reasons: reasons,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  static String _categories(List<StockItem> items) {
    final labels = items.map((s) => s.category.label.toLowerCase()).toSet();
    return labels.take(2).join(' & ');
  }
}

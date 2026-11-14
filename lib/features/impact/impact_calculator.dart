import '../../model/activity_entry.dart';

class MonthlyImpact {
  const MonthlyImpact({
    required this.month,
    required this.savedValue,
    required this.wasteKg,
  });

  /// Tanggal 1 pada bulan tersebut.
  final DateTime month;
  final int savedValue;
  final double wasteKg;
}

class ImpactSummary {
  const ImpactSummary({
    required this.savedValue,
    required this.wasteKg,
    required this.partnersHelped,
    required this.co2Kg,
    required this.savedThisMonth,
    required this.savedLastMonth,
    required this.months,
    required this.countByKind,
    required this.transactionCount,
  });

  static const empty = ImpactSummary(
    savedValue: 0,
    wasteKg: 0,
    partnersHelped: 0,
    co2Kg: 0,
    savedThisMonth: 0,
    savedLastMonth: 0,
    months: [],
    countByKind: {},
    transactionCount: 0,
  );

  /// Total kerugian yang terselamatkan (Rupiah).
  final int savedValue;

  /// Bahan makanan yang tidak jadi terbuang (kg, perkiraan).
  final double wasteKg;

  /// Jumlah UMKM berbeda yang pernah bertransaksi.
  final int partnersHelped;

  /// Emisi yang dicegah (kg CO₂e, perkiraan).
  final double co2Kg;
  final int savedThisMonth;
  final int savedLastMonth;

  /// 6 bulan terakhir, dari yang paling lama.
  final List<MonthlyImpact> months;
  final Map<ActivityKind, int> countByKind;

  /// Jumlah transaksi selesai (order + barter) yang melibatkan user.
  final int transactionCount;

  /// Perubahan bulan ini dibanding bulan lalu (persen), null jika bulan lalu
  /// kosong.
  double? get monthlyChangePercent => savedLastMonth == 0
      ? null
      : (savedThisMonth - savedLastMonth) / savedLastMonth * 100;
}

/// Menghitung dampak penyelamatan dari riwayat aktivitas.
class ImpactCalculator {
  const ImpactCalculator();

  /// Perkiraan emisi gas rumah kaca dari 1 kg sampah makanan (kg CO₂e).
  /// Angka konservatif untuk ilustrasi; bukan pengukuran.
  static const double co2PerKgFood = 2.5;

  ImpactSummary compute(List<ActivityEntry> entries, DateTime now) {
    if (entries.isEmpty) {
      return ImpactSummary(
        savedValue: 0,
        wasteKg: 0,
        partnersHelped: 0,
        co2Kg: 0,
        savedThisMonth: 0,
        savedLastMonth: 0,
        months: _emptyMonths(now),
        countByKind: const {},
        transactionCount: 0,
      );
    }

    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    final months = {
      for (final m in _monthStarts(now)) m: (saved: 0, waste: 0.0),
    };

    var saved = 0;
    var waste = 0.0;
    var savedThis = 0;
    var savedLast = 0;
    final partners = <int>{};
    final counts = <ActivityKind, int>{};
    final references = <String>{};

    for (final entry in entries) {
      saved += entry.savedValue;
      final outgoingWeight = entry.kind.isOutgoing ? entry.weightKg : 0.0;
      waste += outgoingWeight;
      partners.add(entry.counterpartId);
      counts.update(entry.kind, (c) => c + 1, ifAbsent: () => 1);
      references.add('${entry.referenceType}-${entry.referenceId}');

      final month = DateTime(entry.createdAt.year, entry.createdAt.month);
      if (month == thisMonth) savedThis += entry.savedValue;
      if (month == lastMonth) savedLast += entry.savedValue;
      final bucket = months[month];
      if (bucket != null) {
        months[month] = (
          saved: bucket.saved + entry.savedValue,
          waste: bucket.waste + outgoingWeight,
        );
      }
    }

    return ImpactSummary(
      savedValue: saved,
      wasteKg: waste,
      partnersHelped: partners.length,
      co2Kg: waste * co2PerKgFood,
      savedThisMonth: savedThis,
      savedLastMonth: savedLast,
      months: [
        for (final e in months.entries)
          MonthlyImpact(
            month: e.key,
            savedValue: e.value.saved,
            wasteKg: e.value.waste,
          ),
      ],
      countByKind: counts,
      transactionCount: references.length,
    );
  }

  static List<DateTime> _monthStarts(DateTime now) => [
    for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
  ];

  static List<MonthlyImpact> _emptyMonths(DateTime now) => [
    for (final m in _monthStarts(now))
      MonthlyImpact(month: m, savedValue: 0, wasteKg: 0),
  ];
}

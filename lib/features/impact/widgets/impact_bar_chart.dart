import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../impact_calculator.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Grafik batang satu seri: nilai terselamatkan per bulan (6 bulan).
///
/// Satu warna (tanpa legenda, judul kartu sudah menamai seri), batang tipis
/// dengan ujung membulat 4px di atas garis dasar, sumbu samar, label angka
/// hanya untuk bulan berjalan. Batang lain bisa diketuk untuk melihat nilai.
class ImpactBarChart extends StatelessWidget {
  const ImpactBarChart({super.key, required this.months, this.height = 140});

  final List<MonthlyImpact> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return SizedBox(height: height);
    final maxValue = months
        .map((m) => m.savedValue)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Semantics(
      label: 'Grafik nilai terselamatkan per bulan',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < months.length; i++)
            Expanded(
              child: _Bar(
                month: months[i],
                fraction: maxValue == 0 ? 0 : months[i].savedValue / maxValue,
                plotHeight: height,
                isCurrent: i == months.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.month,
    required this.fraction,
    required this.plotHeight,
    required this.isCurrent,
  });

  /// Ruang di atas batang tertinggi untuk label nilai bulan berjalan.
  static const double _labelSpace = 20;

  final MonthlyImpact month;
  final double fraction;

  /// Tinggi area plot (batang + label nilai), tetap untuk semua batang.
  final double plotHeight;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final label = _monthNames[month.month.month - 1];
    final value = formatRupiah(month.savedValue);
    final maxBar = plotHeight - _labelSpace;
    // Batang bernilai > 0 minimal 4px agar tetap terlihat.
    final barHeight =
        month.savedValue == 0 ? 0.0 : (fraction * maxBar).clamp(4.0, maxBar);

    return Tooltip(
      message: '$label ${month.month.year}: $value',
      triggerMode: TooltipTriggerMode.tap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: plotHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCurrent && month.savedValue > 0)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _compact(month.savedValue),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 18,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.45),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
          // Garis dasar (recessive).
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? AppColors.text : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  /// 1500000 → "1,5 jt", 250000 → "250 rb"
  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
    }
    if (value >= 1000) return '${(value / 1000).round()} rb';
    return '$value';
  }
}

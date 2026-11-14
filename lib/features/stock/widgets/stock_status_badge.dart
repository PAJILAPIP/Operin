import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../model/stock_item.dart';

/// Warna latar & teks untuk tiap [StockStatus].
extension StockStatusColors on StockStatus {
  Color get foreground => switch (this) {
    StockStatus.expired => const Color(0xFF991B1B), // red-800
    StockStatus.critical => AppColors.warning,
    StockStatus.soon => const Color(0xFFB45309), // amber-700
    StockStatus.fresh => AppColors.primary,
  };

  Color get background => switch (this) {
    StockStatus.expired => const Color(0xFFFECACA), // red-200
    StockStatus.critical => AppColors.redSoft,
    StockStatus.soon => const Color(0xFFFEF3C7), // amber-100
    StockStatus.fresh => AppColors.greenBadge,
  };
}

class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({super.key, required this.status, this.label});

  final StockStatus status;

  /// Teks badge; default nama status.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label ?? status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: status.foreground,
        ),
      ),
    );
  }
}

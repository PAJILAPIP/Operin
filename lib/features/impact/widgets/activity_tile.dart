import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/activity_entry.dart';
import '../../../widgets/app_card.dart';

IconData activityIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.sale => Icons.sell_outlined,
  ActivityKind.purchase => Icons.shopping_bag_outlined,
  ActivityKind.barterOut => Icons.call_made,
  ActivityKind.barterIn => Icons.call_received,
  ActivityKind.donationOut || ActivityKind.donationIn => Icons.recycling,
};

/// Satu baris riwayat aktivitas.
class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final outgoing = entry.kind.isOutgoing;
    final color = outgoing ? AppColors.primary : AppColors.blue;

    final String trailing;
    if (entry.kind == ActivityKind.sale) {
      trailing = '+${formatRupiah(entry.amount)}';
    } else if (entry.kind == ActivityKind.purchase) {
      trailing = '-${formatRupiah(entry.amount)}';
    } else {
      trailing = '';
    }

    return AppCard(
      radius: 12,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activityIcon(entry.kind), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.kind.label}: ${entry.stockName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${formatQuantity(entry.quantity)} ${entry.unit.label} · '
                  '${entry.counterpartName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              if (entry.savedValue > 0 && entry.kind != ActivityKind.sale)
                Text(
                  'Hemat ${formatRupiah(entry.savedValue)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

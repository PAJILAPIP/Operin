import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/section_title.dart';
import '../../stock/widgets/stock_status_badge.dart';

/// Seksi "Peringatan Stok": stok kedaluwarsa/kritis dari data asli.
class StockWarningSection extends StatelessWidget {
  const StockWarningSection({
    super.key,
    required this.items,
    required this.statusOf,
    required this.now,
    required this.onAction,
    this.onSeeAll,
    this.maxItems = 3,
  });

  /// Stok yang perlu tindakan, urut dari paling mendesak.
  final List<StockItem> items;
  final StockStatus Function(StockItem) statusOf;
  final DateTime now;
  final ValueChanged<StockItem> onAction;
  final VoidCallback? onSeeAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(maxItems).toList();
    final hasWarnings = items.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Peringatan Stok',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasWarnings ? AppColors.redSoft : AppColors.greenBadge,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              hasWarnings ? '${items.length} Kritis' : 'Aman',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasWarnings ? AppColors.warning : AppColors.primary,
              ),
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasWarnings ? AppColors.redSoft : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: hasWarnings
              ? Column(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      _WarningRow(
                        item: shown[i],
                        status: statusOf(shown[i]),
                        now: now,
                        highlighted: i.isOdd,
                        showDivider: i < shown.length - 1 ||
                            items.length > shown.length,
                        onAction: () => onAction(shown[i]),
                      ),
                    if (items.length > shown.length && onSeeAll != null)
                      TextButton(
                        onPressed: onSeeAll,
                        child: Text(
                          'Lihat ${items.length - shown.length} lainnya',
                        ),
                      ),
                  ],
                )
              : const _AllGood(),
        ),
      ],
    );
  }
}

class _AllGood extends StatelessWidget {
  const _AllGood();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tidak ada stok kritis. Semua bahan masih aman.',
              style: TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({
    required this.item,
    required this.status,
    required this.now,
    required this.highlighted,
    required this.showDivider,
    required this.onAction,
  });

  final StockItem item;
  final StockStatus status;
  final DateTime now;
  final bool highlighted;
  final bool showDivider;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFFEF2F2).withValues(alpha: 0.3)
            : Colors.white,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.surfaceMuted))
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: status.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${item.expiryLabel(now)} · '
                  '${formatQuantity(item.quantity)} ${item.unit.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Aksi'),
          ),
        ],
      ),
    );
  }
}

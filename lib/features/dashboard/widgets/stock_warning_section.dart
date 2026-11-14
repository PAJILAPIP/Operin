import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/section_title.dart';

class StockWarning {
  const StockWarning({required this.name, required this.info});

  final String name;
  final String info;
}

/// Seksi "Peringatan Stok" berisi daftar stok yang mendekati kedaluwarsa.
class StockWarningSection extends StatelessWidget {
  const StockWarningSection({
    super.key,
    required this.items,
    this.onAction,
  });

  final List<StockWarning> items;
  final ValueChanged<StockWarning>? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Peringatan Stok',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.redSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${items.length} Kritis',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.redSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _WarningRow(
                  item: items[i],
                  highlighted: i.isOdd,
                  showDivider: i < items.length - 1,
                  onAction: onAction == null ? null : () => onAction!(items[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningRow extends StatelessWidget {
  const _WarningRow({
    required this.item,
    required this.highlighted,
    required this.showDivider,
    this.onAction,
  });

  final StockWarning item;
  final bool highlighted;
  final bool showDivider;
  final VoidCallback? onAction;

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
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  item.info,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAction ?? () {},
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

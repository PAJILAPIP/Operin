import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/promotion.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';

/// Promo yang sedang berjalan, dengan tombol batalkan.
class ActivePromotionTile extends StatelessWidget {
  const ActivePromotionTile({
    super.key,
    required this.promotion,
    required this.item,
    required this.now,
    required this.onCancel,
  });

  final Promotion promotion;
  final StockItem? item;
  final DateTime now;
  final VoidCallback onCancel;

  String get _timeLeft {
    final left = promotion.endsAt.difference(now);
    if (left.inHours >= 24) return 'Berakhir ${left.inDays} hari lagi';
    if (left.inHours >= 1) return 'Sisa ${left.inHours} jam';
    return 'Sisa ${left.inMinutes.clamp(1, 59)} menit';
  }

  @override
  Widget build(BuildContext context) {
    final isFlash = promotion.type == PromotionType.flashSale;
    final color = isFlash ? AppColors.warning : AppColors.blue;
    final unit = item?.unit.label ?? '';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '-${promotion.discountPercent}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.name ?? 'Stok #${promotion.stockId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${promotion.type.label} · ${formatRupiah(promotion.promoPrice)}'
                  '/$unit · ${formatQuantity(promotion.quantity)} $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  _timeLeft,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import 'stock_status_badge.dart';

/// Satu baris stok di daftar: ikon kategori, nama, jumlah, sisa hari.
class StockListTile extends StatelessWidget {
  const StockListTile({
    super.key,
    required this.item,
    required this.status,
    required this.now,
    this.onTap,
    this.promoLabel,
  });

  final StockItem item;
  final StockStatus status;
  final DateTime now;
  final VoidCallback? onTap;

  /// Contoh "Promo -30%" jika stok sedang dipromosikan.
  final String? promoLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.category.icon, color: status.foreground),
          ),
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
                const SizedBox(height: 2),
                Text(
                  '${formatQuantity(item.quantity)} ${item.unit.label} · '
                  '${item.category.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (promoLabel != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      promoLabel!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blueText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StockStatusBadge(status: status),
              const SizedBox(height: 4),
              Text(
                item.expiryLabel(now),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

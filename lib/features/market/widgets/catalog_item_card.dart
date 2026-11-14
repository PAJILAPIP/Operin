import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../model/catalog_item.dart';
import '../../../widgets/app_card.dart';

/// Kartu satu stok di Katalog Pasar B2B (harga normal).
class CatalogItemCard extends StatelessWidget {
  const CatalogItemCard({
    super.key,
    required this.item,
    required this.now,
    required this.onTap,
  });

  final CatalogItem item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = item.stock;
    final unit = stock.unit.label;

    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(stock.category.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.distanceKm == null
                                ? item.sellerName
                                : '${item.sellerName} · '
                                      '${formatDistance(item.distanceKm!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stock.expiryLabel(now),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: formatRupiah(item.price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                    children: [
                      TextSpan(
                        text: ' /$unit',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                item.isSoldOut
                    ? 'Habis'
                    : 'Tersedia ${formatQuantity(item.availableQuantity)} $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: item.isSoldOut ? AppColors.warning : AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

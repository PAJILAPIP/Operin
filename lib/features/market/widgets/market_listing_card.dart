import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../model/market_listing.dart';
import '../../../widgets/app_card.dart';

/// Kartu satu promo di Pasar B2B.
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({
    super.key,
    required this.listing,
    required this.now,
    required this.onTap,
  });

  final MarketListing listing;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final promo = listing.promotion;
    final accent = listing.isFlashSale ? AppColors.warning : AppColors.blue;
    final unit = listing.unit.label;

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
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(listing.category.icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.stockName,
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
                        const Icon(Icons.storefront_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            listing.distanceKm == null
                                ? listing.sellerName
                                : '${listing.sellerName} · '
                                    '${formatDistance(listing.distanceKm!)}',
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
              _Tag(
                label: listing.isFlashSale
                    ? formatTimeLeft(promo.endsAt, now)
                    : '-${promo.discountPercent}%',
                color: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatRupiah(promo.originalPrice),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedLight,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: formatRupiah(promo.promoPrice),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
                  ],
                ),
              ),
              Text(
                listing.isSoldOut
                    ? 'Habis'
                    : 'Tersedia ${formatQuantity(listing.availableQuantity)} $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: listing.isSoldOut ? AppColors.warning : AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

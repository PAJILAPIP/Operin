import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/promotion.dart';
import '../../../widgets/app_card.dart';
import '../../stock/widgets/stock_status_badge.dart';
import '../rescue_advisor.dart';

/// Kartu rekomendasi penyelamatan untuk satu stok.
class RescueCard extends StatelessWidget {
  const RescueCard({
    super.key,
    required this.recommendation,
    required this.now,
    this.activePromotion,
    this.onCreatePromo,
    this.onOpenStock,
    this.showStockName = true,
  });

  final RescueRecommendation recommendation;
  final DateTime now;
  final Promotion? activePromotion;
  final VoidCallback? onCreatePromo;
  final VoidCallback? onOpenStock;

  /// false saat kartu ditampilkan di halaman detail stok itu sendiri.
  final bool showStockName;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final item = rec.item;
    final promo = activePromotion;

    return AppCard(
      onTap: onOpenStock,
      padding: const EdgeInsets.all(16),
      borderColor: rec.status.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(rec.action), size: 20, color: rec.status.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showStockName ? item.name : 'Rekomendasi Penyelamatan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),
              StockStatusBadge(
                status: rec.status,
                label: item.expiryLabel(now),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rec.reason,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.text.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          if (rec.action.canPromote)
            _PriceSuggestion(recommendation: rec)
          else
            _ValueLost(value: rec.valueAtRisk),
          const SizedBox(height: 12),
          if (promo != null)
            _ActivePromoNote(promotion: promo)
          else if (rec.action.canPromote && onCreatePromo != null)
            FilledButton.icon(
              onPressed: onCreatePromo,
              icon: const Icon(Icons.sell_outlined, size: 18),
              label: Text('Buat ${rec.action.label} ${rec.discountPercent}%'),
              style: FilledButton.styleFrom(
                backgroundColor: rec.action == RescueAction.flashSale
                    ? AppColors.warning
                    : AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else if (rec.action == RescueAction.recycle)
            const _RecycleNote(),
        ],
      ),
    );
  }

  static IconData _iconFor(RescueAction action) => switch (action) {
    RescueAction.recycle => Icons.recycling,
    RescueAction.flashSale => Icons.flash_on,
    RescueAction.discount => Icons.sell_outlined,
    RescueAction.monitor => Icons.visibility_outlined,
  };
}

class _PriceSuggestion extends StatelessWidget {
  const _PriceSuggestion({required this.recommendation});

  final RescueRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatRupiah(rec.item.pricePerUnit)}/${rec.item.unit.label}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedLight,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  '${formatRupiah(rec.suggestedPrice)}/${rec.item.unit.label}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Potensi diselamatkan',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                formatRupiah(rec.potentialRecovery),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueLost extends StatelessWidget {
  const _ValueLost({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nilai stok yang hilang: ${formatRupiah(value)}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.warning,
      ),
    );
  }
}

class _RecycleNote extends StatelessWidget {
  const _RecycleNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.recycling, size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Penyaluran ke Mitra Daur Ulang tersedia di fitur Matchmaking.',
              style: TextStyle(fontSize: 12, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePromoNote extends StatelessWidget {
  const _ActivePromoNote({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, size: 18, color: AppColors.blueText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${promotion.type.label} -${promotion.discountPercent}% sedang '
              'berjalan · ${formatRupiah(promotion.promoPrice)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.blueText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

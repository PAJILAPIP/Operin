import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../model/scan_result.dart';
import '../../../widgets/app_card.dart';

/// Kartu satu bahan hasil Scan AI: grade, kesegaran, kedaluwarsa, saran.
class ScannedItemCard extends StatelessWidget {
  const ScannedItemCard({
    super.key,
    required this.item,
    required this.onAddToStock,
  });

  final ScannedItem item;
  final VoidCallback onAddToStock;

  @override
  Widget build(BuildContext context) {
    final quantity = item.quantity;
    final subtitle = [
      item.category.label,
      if (quantity != null) '± ${formatQuantity(quantity)} ${item.unit.label}',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.category.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              QualityBadge(quality: item.quality),
            ],
          ),
          const SizedBox(height: 14),
          _FreshnessBar(score: item.freshnessScore),
          const SizedBox(height: 12),
          _ExpiryRow(item: item),
          if (item.reason != null) ...[
            const SizedBox(height: 10),
            Text(
              item.reason!,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
          if (item.recommendation != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: AppColors.amberText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.recommendation!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!item.quality.isUsable) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Tidak layak dijual. Catat sebagai stok lalu salurkan ke mitra '
                'daur ulang lewat Matchmaking.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddToStock,
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('Tambah ke Stok'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge grade kualitas: warna + ikon + label (tidak hanya warna).
class QualityBadge extends StatelessWidget {
  const QualityBadge({super.key, required this.quality});

  final ScanQuality quality;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (quality) {
      ScanQuality.gradeA => (
        AppColors.greenBadge,
        AppColors.primary,
        Icons.verified_outlined,
      ),
      ScanQuality.gradeB => (
        AppColors.blueSoft,
        AppColors.blueText,
        Icons.thumb_up_alt_outlined,
      ),
      ScanQuality.gradeC => (
        AppColors.amberSoft,
        AppColors.amberText,
        Icons.schedule,
      ),
      ScanQuality.rejected => (
        AppColors.redSoft,
        AppColors.warning,
        Icons.block,
      ),
    };

    return Tooltip(
      message: quality.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              quality.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreshnessBar extends StatelessWidget {
  const _FreshnessBar({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.primary
        : score >= 40
        ? AppColors.amberText
        : AppColors.warning;

    return Row(
      children: [
        const Text(
          'Kesegaran',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$score%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.item});

  final ScannedItem item;

  @override
  Widget build(BuildContext context) {
    final expiry = item.expiryDate;
    if (expiry == null) {
      return const Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 16, color: AppColors.mutedLight),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tanggal kedaluwarsa tidak terdeteksi',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      );
    }

    final fromLabel = item.expirySource == ExpirySource.label;
    return Row(
      children: [
        const Icon(Icons.event_outlined, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Kedaluwarsa ${formatDate(expiry)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            fromLabel ? 'Dari label' : 'Perkiraan AI',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

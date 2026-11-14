import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../model/stock_item.dart';
import '../../../widgets/app_card.dart';
import '../../survey/models/user_role.dart';
import '../matchmaking_engine.dart';

/// Label peran singkat, mis. "Mitra Daur Ulang".
String roleLabel(String role) {
  for (final value in UserRole.values) {
    if (value.name == role) return value.accountLabel.replaceFirst('Akun ', '');
  }
  return 'UMKM';
}

/// Kartu rekomendasi satu mitra hasil [MatchmakingEngine].
class PartnerMatchCard extends StatelessWidget {
  const PartnerMatchCard({
    super.key,
    required this.match,
    required this.now,
    this.onBarter,
    this.onRecycle,
  });

  final PartnerMatch match;
  final DateTime now;
  final VoidCallback? onBarter;
  final VoidCallback? onRecycle;

  @override
  Widget build(BuildContext context) {
    final partner = match.partner;
    final accent = partner.isRecyclePartner ? AppColors.primary : AppColors.purple;

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      borderColor: match.isMutual
          ? AppColors.secondary.withValues(alpha: 0.6)
          : AppColors.borderLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(
                  partner.isRecyclePartner
                      ? Icons.recycling
                      : partner.businessCategory.icon,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      [
                        roleLabel(partner.role),
                        if (partner.distanceKm != null)
                          formatDistance(partner.distanceKm!),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (match.isMutual)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'COCOK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final reason in match.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          if (match.theyHave.isNotEmpty)
            _StockChips(
              title: 'Mereka punya',
              items: match.theyHave,
              now: now,
            ),
          if (match.theyNeed.isNotEmpty)
            _StockChips(
              title: 'Mereka butuh dari Anda',
              items: match.theyNeed,
              now: now,
            ),
          if (match.recyclable.isNotEmpty)
            _StockChips(
              title: 'Stok kedaluwarsa Anda',
              items: match.recyclable,
              now: now,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onRecycle != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRecycle,
                    icon: const Icon(Icons.recycling, size: 18),
                    label: const Text('Salurkan Stok'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              if (onRecycle != null && onBarter != null)
                const SizedBox(width: 8),
              if (onBarter != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onBarter,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Ajukan Barter'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockChips extends StatelessWidget {
  const _StockChips({
    required this.title,
    required this.items,
    required this.now,
  });

  final String title;
  final List<StockItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items.take(3))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    '${item.name} · ${formatQuantity(item.quantity)} '
                    '${item.unit.label} · ${item.expiryLabel(now)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.text),
                  ),
                ),
              if (items.length > 3)
                Text(
                  '+${items.length - 3} lainnya',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_title.dart';

/// Seksi "Dampak Bisnis Anda" (trust indicators).
class ImpactStatsSection extends StatelessWidget {
  const ImpactStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Dampak Bisnis Anda'),
        const _SavingsCard(),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: _StatCard(
                icon: Icons.delete_outline,
                label: 'Limbah Dicegah',
                value: '450 kg',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.people_outline,
                label: 'UMKM Terbantu',
                value: '120',
                unit: ' orang',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 128,
              color: AppColors.text.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kerugian Terselamatkan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rp 15.450.000',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.sell_outlined,
                        size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      '+12% bulan ini',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: AppColors.text.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

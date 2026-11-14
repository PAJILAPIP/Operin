import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_title.dart';
import '../../stock/stock_controller.dart';
import '../promotion_controller.dart';
import '../rescue_advisor.dart';
import '../widgets/active_promotion_tile.dart';
import '../widgets/rescue_card.dart';

/// Pusat "Penyelamatan Lapis 1": pantau masa simpan, rekomendasi, promo.
class RescuePage extends StatelessWidget {
  const RescuePage({super.key});

  Future<void> _cancel(BuildContext context, int promotionId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await PromotionScope.read(context).cancel(promotionId);
      messenger.showSnackBar(const SnackBar(content: Text('Promo dibatalkan.')));
    } catch (error) {
      debugPrint('Gagal membatalkan promo: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal membatalkan promo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = StockScope.of(context);
    final promotions = PromotionScope.of(context);
    final now = promotions.now;
    final recommendations = promotions.recommendations;
    final active = promotions.activePromotions;

    final today = recommendations.where((r) => r.daysLeft <= 0).toList();
    final thisWeek = recommendations.where((r) => r.daysLeft > 0).toList();

    Widget card(RescueRecommendation rec) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RescueCard(
        recommendation: rec,
        now: now,
        activePromotion: promotions.activeForStock(rec.item.id!),
        onOpenStock: () => Navigator.of(context).pushNamed(
          AppRoutes.stockDetail,
          arguments: rec.item.id,
        ),
        onCreatePromo: () => Navigator.of(context).pushNamed(
          AppRoutes.promotionForm,
          arguments: rec.item.id,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Penyelamatan Stok',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryCard(recommendations: recommendations),
              const SizedBox(height: 24),
              if (active.isNotEmpty) ...[
                SectionTitle('Promo Aktif (${active.length})'),
                for (final promo in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ActivePromotionTile(
                      promotion: promo,
                      item: stock.byId(promo.stockId),
                      now: now,
                      onCancel: () => _cancel(context, promo.id!),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
              if (recommendations.isEmpty)
                const _AllSafe()
              else ...[
                if (today.isNotEmpty) ...[
                  const SectionTitle('Tindakan Hari Ini'),
                  for (final rec in today) card(rec),
                  const SizedBox(height: 12),
                ],
                if (thisWeek.isNotEmpty) ...[
                  const SectionTitle('Kedaluwarsa Minggu Ini'),
                  for (final rec in thisWeek) card(rec),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.recommendations});

  final List<RescueRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    final atRisk =
        recommendations.fold<int>(0, (sum, rec) => sum + rec.valueAtRisk);
    final recoverable = recommendations.fold<int>(
      0,
      (sum, rec) => sum + rec.potentialRecovery,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${recommendations.length} stok perlu diselamatkan',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(atRisk),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Nilai stok berisiko',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Potensi diselamatkan dengan promo: '
                    '${formatRupiah(recoverable)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

class _AllSafe extends StatelessWidget {
  const _AllSafe();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 40, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Semua stok aman',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tidak ada bahan yang kedaluwarsa dalam 7 hari ke depan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

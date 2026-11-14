import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/stock_item.dart';
import '../../matchmaking/match_controller.dart';
import '../../rescue/promotion_controller.dart';
import '../../stock/stock_controller.dart';
import '../../../widgets/section_title.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/impact_stats_section.dart';
import '../widgets/service_tile.dart';
import '../widgets/stock_warning_section.dart';

/// Tab "Dasbor": statistik dampak, peringatan stok, dan layanan.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigate});

  final ValueChanged<DashboardTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    final stock = StockScope.of(context);
    final promotions = PromotionScope.of(context);
    final rescueCount = promotions.recommendations.length;
    final awaitingBarter = MatchScope.of(context).awaitingMeCount;

    // "Aksi": stok yang masih bisa dijual & belum dipromosikan → buat promo;
    // selain itu (kedaluwarsa / promo sudah jalan) → buka detail stok.
    void handleAction(StockItem item) {
      final canPromote = promotions.recommend(item).action.canPromote &&
          promotions.activeForStock(item.id!) == null;
      Navigator.of(context).pushNamed(
        canPromote ? AppRoutes.promotionForm : AppRoutes.stockDetail,
        arguments: item.id,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ImpactStatsSection(),
        const SizedBox(height: 24),
        StockWarningSection(
          items: stock.urgentItems,
          statusOf: stock.statusOf,
          now: stock.now,
          onAction: handleAction,
          onSeeAll: () => onNavigate(DashboardTab.stok),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Layanan Operin'),
        ServiceTile(
          icon: Icons.document_scanner_outlined,
          iconBackground: AppColors.primary,
          title: 'Scan Stok & AI Grading',
          subtitle: 'Cek kelayakan stok segar dengan kamera AI.',
          onTap: () => onNavigate(DashboardTab.scan),
        ),
        const SizedBox(height: 12),
        ServiceTile(
          icon: Icons.sell_outlined,
          iconBackground: AppColors.blue,
          title: 'Penyelamatan Lapis 1',
          subtitle: rescueCount == 0
              ? 'Auto-promo cerdas sebelum masa kadaluwarsa.'
              : '$rescueCount stok perlu diselamatkan. Lihat rekomendasi.',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.rescue),
        ),
        const SizedBox(height: 12),
        ServiceTile(
          icon: Icons.handshake_outlined,
          iconBackground: AppColors.purple,
          title: 'Matchmaking B2B',
          subtitle: awaitingBarter > 0
              ? '$awaitingBarter barter menunggu jawaban Anda.'
              : 'Temukan mitra UMKM & barter sisa stok.',
          badge: 'HOT',
          accentColor: AppColors.secondary,
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.matchmaking),
        ),
      ],
    );
  }
}

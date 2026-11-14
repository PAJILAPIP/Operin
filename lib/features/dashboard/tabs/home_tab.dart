import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/section_title.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/impact_stats_section.dart';
import '../widgets/service_tile.dart';
import '../widgets/stock_warning_section.dart';

/// Tab "Dasbor": statistik dampak, peringatan stok, dan layanan.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigate});

  final ValueChanged<DashboardTab> onNavigate;

  static const _warnings = [
    StockWarning(
      name: 'Tomat Ceri Grade B',
      info: 'H-1 Kedaluwarsa (25kg)',
    ),
    StockWarning(
      name: 'Roti Tawar Gandum',
      info: 'H-2 Kedaluwarsa (100pcs)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ImpactStatsSection(),
        const SizedBox(height: 24),
        const StockWarningSection(items: _warnings),
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
          subtitle: 'Auto-promo cerdas sebelum masa kadaluwarsa.',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        ServiceTile(
          icon: Icons.handshake_outlined,
          iconBackground: AppColors.purple,
          title: 'Matchmaking B2B',
          subtitle: 'Flash sale & barter sisa stok antar UMKM.',
          badge: 'HOT',
          accentColor: AppColors.secondary,
          onTap: () => onNavigate(DashboardTab.pasar),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../survey/models/user_role.dart';
import '../tabs/home_tab.dart';
import '../tabs/market_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/scan_tab.dart';
import '../tabs/stock_tab.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/dashboard_header.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.role});

  final UserRole role;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DashboardTab _activeTab = DashboardTab.dashboard;

  void _setTab(DashboardTab tab) => setState(() => _activeTab = tab);

  Widget _buildTab() {
    switch (_activeTab) {
      case DashboardTab.dashboard:
        return HomeTab(onNavigate: _setTab);
      case DashboardTab.stok:
        return const StockTab();
      case DashboardTab.scan:
        return const ScanTab();
      case DashboardTab.pasar:
        return const MarketTab();
      case DashboardTab.profil:
        return ProfileTab(role: widget.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DashboardHeader(
        onAvatarTap: () => _setTab(DashboardTab.profil),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: SingleChildScrollView(
          key: ValueKey(_activeTab),
          // Ruang bawah ekstra agar item terakhir tidak tertutup tombol tambah.
          padding: EdgeInsets.fromLTRB(
            20,
            24,
            20,
            _activeTab == DashboardTab.stok ? 96 : 24,
          ),
          child: _buildTab(),
        ),
      ),
      floatingActionButton: _activeTab == DashboardTab.stok
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.stockForm),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text(
                'Tambah Stok',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      bottomNavigationBar: DashboardBottomNav(
        activeTab: _activeTab,
        onTap: _setTab,
      ),
    );
  }
}

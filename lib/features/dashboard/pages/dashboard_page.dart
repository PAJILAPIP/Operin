import 'package:flutter/material.dart';

import '../../survey/models/user_role.dart';
import '../tabs/home_tab.dart';
import '../tabs/market_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/scan_tab.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _buildTab(),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        activeTab: _activeTab,
        onTap: _setTab,
      ),
    );
  }
}

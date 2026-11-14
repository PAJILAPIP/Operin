import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum DashboardTab {
  dashboard('Dasbor', Icons.home_outlined, Icons.home),
  scan('Scan AI', Icons.document_scanner_outlined, Icons.document_scanner),
  pasar('Pasar B2B', Icons.storefront_outlined, Icons.storefront),
  profil('Profil', Icons.person_outline, Icons.person);

  const DashboardTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    super.key,
    required this.activeTab,
    required this.onTap,
  });

  final DashboardTab activeTab;
  final ValueChanged<DashboardTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: -10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: DashboardTab.values
                .map(
                  (tab) => _NavItem(
                    tab: tab,
                    active: tab == activeTab,
                    onTap: () => onTap(tab),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final DashboardTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.text;

    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1 : 0.6,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: active ? 1.1 : 1,
          child: SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? tab.activeIcon : tab.icon,
                      size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

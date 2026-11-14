import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_logo.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  const DashboardHeader({super.key, required this.onAvatarTap});

  final VoidCallback onAvatarTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  AppLogo(size: 32),
                  SizedBox(width: 8),
                  Text(
                    'Operin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary, width: 2),
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 20, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

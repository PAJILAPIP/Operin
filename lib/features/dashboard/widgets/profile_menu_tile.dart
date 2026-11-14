import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final iconColor = destructive ? AppColors.warning : const Color(0xFF4B5563);
    final iconBg = destructive ? AppColors.redSoft : AppColors.borderLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: destructive
            ? const Color(0xFFFEF2F2)
            : AppColors.surfaceMuted,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        destructive ? FontWeight.bold : FontWeight.w500,
                    color: destructive ? AppColors.warning : AppColors.text,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: destructive
                    ? const Color(0xFFF87171)
                    : AppColors.mutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

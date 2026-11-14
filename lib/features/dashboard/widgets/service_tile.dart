import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_card.dart';

/// Kartu layanan di seksi "Layanan Operin".
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.badge,
    this.accentColor,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Label kecil di pojok kanan atas, mis. "HOT".
  final String? badge;

  /// Garis aksen vertikal di sisi kiri kartu.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (accentColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accentColor),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(accentColor != null ? 20 : 16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.text.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge == null)
                  Icon(Icons.chevron_right,
                      size: 20, color: AppColors.text.withValues(alpha: 0.4))
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

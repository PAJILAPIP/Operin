import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/business_category.dart';
import '../../../model/business_profile.dart';
import '../../../widgets/app_card.dart';
import '../../survey/models/user_role.dart';
import '../widgets/profile_menu_tile.dart';

/// Tab "Profil": info akun dan menu pengaturan.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.role});

  final UserRole role;

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await SessionScope.read(context).signOut();
    navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.currentUser;
    final profile = session.profile;
    final category = BusinessCategory.fromName(user?.businessType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person_outline,
                size: 48, color: AppColors.mutedLight),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.fullName ?? 'Mitra UMKM',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.greenBadge,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              role.accountLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (profile != null) ...[
          _BusinessSummaryCard(
            profile: profile,
            category: category,
            address: user?.address,
          ),
          const SizedBox(height: 16),
        ],
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ProfileMenuTile(
                icon: Icons.storefront_outlined,
                label: 'Informasi Toko',
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.businessProfile,
                  arguments: true,
                ),
              ),
              const SizedBox(height: 4),
              ProfileMenuTile(
                icon: Icons.history,
                label: 'Riwayat Aktivitas',
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.impact,
                  arguments: true,
                ),
              ),
              const SizedBox(height: 16),
              ProfileMenuTile(
                icon: Icons.lock_outline,
                label: 'Keluar Akun',
                destructive: true,
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ringkasan profil usaha: nama toko, jenis usaha, alamat, preferensi.
class _BusinessSummaryCard extends StatelessWidget {
  const _BusinessSummaryCard({
    required this.profile,
    required this.category,
    this.address,
  });

  final BusinessProfile profile;
  final BusinessCategory category;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (address != null && address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.location_on_outlined, text: address!),
          ],
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.chat_outlined, text: '+${profile.whatsapp}'),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.radar_outlined,
            text: 'Radius ${profile.radiusKm} km · '
                '${profile.notifyExpiry ? 'Notifikasi H-${profile.notifyDaysBefore}' : 'Notifikasi mati'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final food in profile.preferredCategories)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.greenBadge,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    food.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.mutedLight),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.text.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

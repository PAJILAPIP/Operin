import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
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
    final user = SessionScope.of(context).currentUser;
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
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              ProfileMenuTile(
                icon: Icons.storefront_outlined,
                label: 'Informasi Toko',
                onTap: () {},
              ),
              const SizedBox(height: 4),
              ProfileMenuTile(
                icon: Icons.handshake_outlined,
                label: 'Riwayat Matchmaking B2B',
                onTap: () {},
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

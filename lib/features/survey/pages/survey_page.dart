import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/primary_button.dart';
import '../models/user_role.dart';
import '../widgets/role_option_card.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  UserRole? _selectedRole;
  bool _isSaving = false;

  Future<void> _continue() async {
    final role = _selectedRole;
    if (role == null) return;
    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      await session.setRole(role.name);
      if (!mounted) return;
      AppRoutes.goHome(navigator, session);
    } catch (error) {
      debugPrint('Gagal menyimpan peran: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan peran. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Peran Anda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bantu kami menyesuaikan dashboard Operin sesuai kebutuhan bisnis Anda.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: UserRole.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final role = UserRole.values[index];
                    return RoleOptionCard(
                      role: role,
                      selected: _selectedRole == role,
                      onTap: () => setState(() => _selectedRole = role),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Lanjutkan ke Dashboard',
                onPressed:
                    _selectedRole == null || _isSaving ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

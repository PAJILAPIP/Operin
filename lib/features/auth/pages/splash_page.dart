import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_logo.dart';

/// Halaman pembuka: memulihkan sesi tersimpan lalu mengarahkan user ke
/// login, survey, atau dashboard.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final session = SessionScope.read(context);
    final navigator = Navigator.of(context);

    try {
      final user = await session.restore();
      if (!mounted) return;
      if (user != null) {
        AppRoutes.goHome(navigator, session);
        return;
      }
    } catch (error) {
      debugPrint('Gagal memulihkan sesi: $error');
      if (!mounted) return;
    }
    navigator.pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(),
            SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

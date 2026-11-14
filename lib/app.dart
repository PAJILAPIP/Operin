import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/auth_repository.dart';

class OperinApp extends StatelessWidget {
  const OperinApp({
    super.key,
    this.authRepository = const SqliteAuthRepository(),
  });

  final AuthRepository authRepository;

  /// Lebar maksimum tampilan (setara `max-w-md` di Tailwind).
  static const double maxContentWidth = 448;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes(authRepository: authRepository),
      // Mobile constraint wrapper: di layar lebar (web/desktop) konten
      // tetap selebar ponsel dan berada di tengah.
      builder: (context, child) => ColoredBox(
        color: AppColors.outerBackground,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

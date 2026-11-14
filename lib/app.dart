import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/auth_repository.dart';

class OperinApp extends StatefulWidget {
  const OperinApp({
    super.key,
    this.authRepository = const SqliteAuthRepository(),
  });

  final AuthRepository authRepository;

  /// Lebar maksimum tampilan (setara `max-w-md` di Tailwind).
  static const double maxContentWidth = 448;

  @override
  State<OperinApp> createState() => _OperinAppState();
}

class _OperinAppState extends State<OperinApp> {
  late final SessionController _session =
      SessionController(repository: widget.authRepository);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Operin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes(authRepository: widget.authRepository),
      // Mobile constraint wrapper: di layar lebar (web/desktop) konten
      // tetap selebar ponsel dan berada di tengah.
      builder: (context, child) => SessionScope(
        controller: _session,
        child: ColoredBox(
          color: AppColors.outerBackground,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: OperinApp.maxContentWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

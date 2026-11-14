import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/signup_page.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/survey/models/user_role.dart';
import '../../features/survey/pages/survey_page.dart';
import '../../model/auth_user.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String survey = '/survey';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> routes({
    AuthRepository authRepository = const SqliteAuthRepository(),
  }) => {
    splash: (_) => const SplashPage(),
    login: (_) => LoginPage(authRepository: authRepository),
    signup: (_) => SignupPage(authRepository: authRepository),
    survey: (_) => const SurveyPage(),
    dashboard: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return DashboardPage(role: args is UserRole ? args : UserRole.seller);
    },
  };

  /// Mengubah nama peran tersimpan menjadi [UserRole], atau null jika
  /// kosong/tidak dikenal.
  static UserRole? roleOf(AuthUser user) {
    final name = user.role;
    if (name == null) return null;
    for (final role in UserRole.values) {
      if (role.name == name) return role;
    }
    return null;
  }

  /// Arahkan user yang sudah login ke halaman yang sesuai dan hapus riwayat
  /// navigasi: belum pilih peran → survey, sudah → dashboard.
  static void goHome(NavigatorState navigator, AuthUser user) {
    final role = roleOf(user);
    if (role == null) {
      navigator.pushNamedAndRemoveUntil(survey, (_) => false);
    } else {
      navigator.pushNamedAndRemoveUntil(
        dashboard,
        (_) => false,
        arguments: role,
      );
    }
  }
}

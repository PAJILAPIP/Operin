import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/signup_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/survey/models/user_role.dart';
import '../../features/survey/pages/survey_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String signup = '/signup';
  static const String survey = '/survey';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> routes({
    AuthRepository authRepository = const SqliteAuthRepository(),
  }) => {
    login: (_) => LoginPage(authRepository: authRepository),
    signup: (_) => SignupPage(authRepository: authRepository),
    survey: (_) => const SurveyPage(),
    dashboard: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      return DashboardPage(role: args is UserRole ? args : UserRole.seller);
    },
  };
}

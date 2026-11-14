import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../data/auth_repository.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_switch_text.dart';
import '../widgets/remember_me_checkbox.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.authRepository = const SqliteAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _usernameController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Masukkan email dan password.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = SessionScope.read(context);
      final navigator = Navigator.of(context);
      final user = await widget.authRepository.login(
        email: email,
        password: password,
      );
      await session.signIn(user, remember: _rememberMe);
      if (mounted) AppRoutes.goHome(navigator, session);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(
        kDebugMode ? 'Login gagal: $error' : 'Login gagal. Silakan coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const AppLogo(),
                const SizedBox(height: 40),
                AuthCard(
                  title: 'Login',
                  subtitle: 'Welcome back please login to your account',
                  children: [
                    AppTextField(
                      controller: _usernameController,
                      hint: 'Email Address',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      isPassword: true,
                    ),
                    const SizedBox(height: 12),
                    RememberMeCheckbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: _isSubmitting ? 'Signing in...' : 'Login',
                      onPressed: _isSubmitting ? null : _login,
                    ),
                    const SizedBox(height: 24),
                    AuthSwitchText(
                      prompt: "Don't have an account? ",
                      action: 'Signup',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.signup),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

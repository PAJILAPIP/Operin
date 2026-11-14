import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/auth_repository.dart';
import '../../../model/business_category.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../../location/location_picker_field.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_switch_text.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({
    super.key,
    this.authRepository = const SqliteAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _alamatController = TextEditingController();
  BusinessCategory? _jenisUsaha;
  LatLng? _lokasi;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.login);
    }
  }

  Future<void> _createAccount() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final address = _alamatController.text.trim();

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _jenisUsaha == null ||
        address.isEmpty) {
      _showMessage('Lengkapi semua data terlebih dahulu.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Format email tidak valid.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password minimal 8 karakter.');
      return;
    }
    final lokasi = _lokasi;
    if (lokasi == null) {
      _showMessage('Tandai lokasi usaha di peta.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final session = SessionScope.read(context);
      final navigator = Navigator.of(context);
      final user = await widget.authRepository.register(
        fullName: fullName,
        email: email,
        password: password,
        businessType: _jenisUsaha!.name,
        address: address,
        latitude: lokasi.latitude,
        longitude: lokasi.longitude,
      );
      await session.signIn(user, remember: true);
      if (mounted) AppRoutes.goHome(navigator, session);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage(
        kDebugMode
            ? 'Pendaftaran gagal: $error'
            : 'Pendaftaran gagal. Silakan coba lagi.',
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
                  title: 'Sign Up',
                  subtitle: 'Create your account to start saving food',
                  children: [
                    AppTextField(
                      controller: _nameController,
                      hint: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      hint: 'Email Address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<BusinessCategory>(
                      initialValue: _jenisUsaha,
                      isExpanded: true,
                      hint: const Text('Pilih Jenis Usaha'),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      iconEnabledColor: AppColors.text.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.text,
                      ),
                      items: BusinessCategory.values
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Row(
                                children: [
                                  Icon(category.icon,
                                      size: 18, color: AppColors.muted),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      category.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _jenisUsaha = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _alamatController,
                      hint: 'Alamat Usaha',
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.streetAddress,
                    ),
                    const SizedBox(height: 16),
                    LocationPickerField(
                      value: _lokasi,
                      onChanged: (point) => setState(() => _lokasi = point),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: _isSubmitting
                          ? 'Creating account...'
                          : 'Create Account',
                      onPressed: _isSubmitting ? null : _createAccount,
                    ),
                    const SizedBox(height: 24),
                    AuthSwitchText(
                      prompt: 'Already have an account? ',
                      action: 'Login',
                      onTap: _goToLogin,
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

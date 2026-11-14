import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/auth_repository.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/primary_button.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_switch_text.dart';
import '../widgets/map_picker_dialog.dart';

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
  static const Map<String, String> _jenisUsahaOptions = {
    'usaha1': 'Usaha 1 (Warung Makan)',
    'usaha2': 'Usaha 2 (Katering)',
    'usaha3': 'Usaha 3 (Toko Buah/Sayur)',
    'usaha4': 'Usaha 4 (Supermarket)',
    'usaha5': 'Usaha 5 (Distributor)',
    'lainnya': 'Lainnya...',
  };

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _alamatController = TextEditingController();
  String? _jenisUsaha;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final address = await MapPickerDialog.show(context);
    if (address != null && mounted) {
      setState(() => _alamatController.text = address);
    }
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

    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository.register(
        fullName: fullName,
        email: email,
        password: password,
        businessType: _jenisUsaha!,
        address: address,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.survey);
      }
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
                    DropdownButtonFormField<String>(
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
                      items: _jenisUsahaOptions.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _jenisUsaha = v),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _alamatController,
                      hint: 'Pilih Lokasi Usaha',
                      icon: Icons.location_on_outlined,
                      readOnly: true,
                      onTap: _pickLocation,
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

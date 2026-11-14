import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Input teks bergaya Operin dengan ikon di sisi kanan.
///
/// Jika [isPassword] true, ikon berubah menjadi tombol show/hide password.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.hint,
    this.icon,
    this.controller,
    this.keyboardType,
    this.isPassword = false,
    this.readOnly = false,
    this.onTap,
  });

  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool isPassword;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (widget.isPassword) {
      suffix = IconButton(
        splashRadius: 20,
        icon: Icon(
          _obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      );
    } else if (widget.icon != null) {
      suffix = Icon(widget.icon, size: 20);
    }

    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      maxLines: 1,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        suffixIcon: suffix,
      ),
    );
  }
}

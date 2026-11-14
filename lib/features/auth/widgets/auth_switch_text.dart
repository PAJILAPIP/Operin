import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Teks "Don't have an account? Signup" / "Already have an account? Login".
class AuthSwitchText extends StatefulWidget {
  const AuthSwitchText({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  State<AuthSwitchText> createState() => _AuthSwitchTextState();
}

class _AuthSwitchTextState extends State<AuthSwitchText> {
  late final TapGestureRecognizer _recognizer = TapGestureRecognizer()
    ..onTap = () => widget.onTap();

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        children: [
          TextSpan(text: widget.prompt),
          TextSpan(
            text: widget.action,
            style: const TextStyle(fontWeight: FontWeight.bold),
            recognizer: _recognizer,
            mouseCursor: SystemMouseCursors.click,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

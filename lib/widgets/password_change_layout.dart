import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'gradient_button.dart';

class PasswordChangeLayout extends StatelessWidget {
  const PasswordChangeLayout({
    super.key,
    required this.title,
    required this.currentController,
    required this.newController,
    required this.confirmController,
    required this.currentObscure,
    required this.newObscure,
    required this.confirmObscure,
    required this.onToggleCurrent,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.saving,
    this.currentError,
    this.newError,
    this.confirmError,
  });

  final String title;
  final TextEditingController currentController;
  final TextEditingController newController;
  final TextEditingController confirmController;
  final bool currentObscure;
  final bool newObscure;
  final bool confirmObscure;
  final VoidCallback onToggleCurrent;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final bool saving;
  final String? currentError;
  final String? newError;
  final String? confirmError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121B),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PasswordInput(
              controller: currentController,
              hintText: 'Current Password',
              obscureText: currentObscure,
              onToggle: onToggleCurrent,
              errorText: currentError,
            ),
            const SizedBox(height: 14),
            _PasswordInput(
              controller: newController,
              hintText: 'New Password',
              obscureText: newObscure,
              onToggle: onToggleNew,
              errorText: newError,
            ),
            const SizedBox(height: 14),
            _PasswordInput(
              controller: confirmController,
              hintText: 'Confirm Password',
              obscureText: confirmObscure,
              onToggle: onToggleConfirm,
              errorText: confirmError,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: saving ? 'Updating...' : 'Update Password',
              onPressed: saving ? () {} : onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordInput extends StatelessWidget {
  const _PasswordInput({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggle,
    this.errorText,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? errorText;

  bool get _hasError => errorText != null && errorText!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFBCC5D0),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFF0E1A25),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _hasError ? const Color(0xFFFF4D6D) : const Color(0xFF263646),
                width: _hasError ? 1.4 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _hasError ? const Color(0xFFFF4D6D) : AppColors.hotPink,
                width: 1.5,
              ),
            ),
            suffixIcon: _hasError
                ? const Icon(Icons.close_rounded, color: Color(0xFFFF4D6D), size: 28)
                : IconButton(
                    onPressed: onToggle,
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFFA9B2BF),
                    ),
                  ),
          ),
        ),
        if (_hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFF6B81),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

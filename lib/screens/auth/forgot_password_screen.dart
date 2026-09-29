import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

enum _Step { email, code, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();

  final _emailFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _newPasswordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  bool _autoValidateEmail = false;
  bool _autoValidatePassword = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String _maskedEmail = '';
  String _resetToken = '';
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizeOtpDigits(String value) {
    const easternArabic = '٠١٢٣٤٥٦٧٨٩';
    const extendedArabic = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final easternIndex = easternArabic.indexOf(char);
      if (easternIndex >= 0) {
        buffer.write(easternIndex);
        continue;
      }
      final extendedIndex = extendedArabic.indexOf(char);
      if (extendedIndex >= 0) {
        buffer.write(extendedIndex);
        continue;
      }
      if (RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _sendCode() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidateEmail = true);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _authService.sendPasswordResetOtp(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _maskedEmail = (data['maskedEmail'] ?? '').toString();
        _step = _Step.code;
      });
      _startResendTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_codeFocusNode);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlySendError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await _authService.sendPasswordResetOtp(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _codeController.clear();
      _startResendTimer();
      _showMessage(context.tr('Code sent.'));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlySendError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _normalizeOtpDigits(_codeController.text.trim());
    if (code.length != 6) {
      _showMessage(context.tr('Enter the 6 digit code.'));
      return;
    }
    setState(() => _loading = true);
    try {
      final resetToken = await _authService.verifyPasswordResetOtp(
        email: _emailController.text.trim(),
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _resetToken = resetToken;
        _step = _Step.newPassword;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyVerifyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_newPasswordFormKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidatePassword = true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _authService.resetPasswordWithOtp(
        email: _emailController.text.trim(),
        resetToken: _resetToken,
        newPassword: _newPasswordController.text.trim(),
      );
      if (!mounted) return;
      final message = context.tr('Your password has been changed.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1F6F3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.tr('Please verify the code again.'));
      setState(() => _step = _Step.email);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlySendError(Object e) {
    final text = e.toString();
    if (text.contains('not-found')) {
      return context.tr('No user found for that email.');
    }
    if (text.contains('invalid-argument')) {
      return context.tr('Enter a valid email.');
    }
    if (text.contains('Please wait')) {
      return context.tr('Please wait before requesting another code.');
    }
    return context.tr('Unable to send code. Please try again.');
  }

  String _friendlyVerifyError(Object e) {
    final text = e.toString();
    if (text.contains('deadline-exceeded') || text.contains('expired')) {
      return context.tr('Code expired. Please request a new one.');
    }
    if (text.contains('permission-denied') || text.contains('Invalid')) {
      return context.tr('Invalid code. Please try again.');
    }
    if (text.contains('resource-exhausted')) {
      return context.tr('Too many attempts. Please request a new code.');
    }
    return context.tr('Unable to verify code. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_step == _Step.email) {
                            Navigator.maybePop(context);
                          } else if (_step == _Step.code) {
                            setState(() => _step = _Step.email);
                          } else {
                            setState(() => _step = _Step.code);
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 92,
                            height: 64,
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  switch (_step) {
                    _Step.email => _buildEmailStep(),
                    _Step.code => _buildCodeStep(),
                    _Step.newPassword => _buildNewPasswordStep(),
                  },
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        Text(
          context.tr('Forgot Password?'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(
            'Enter your email address and we will send you a 6 digit code.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
        const SizedBox(height: 18),
        _Card(
          child: Column(
            children: [
              Form(
                key: _emailFormKey,
                autovalidateMode: _autoValidateEmail
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: context.tr('Email address'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    prefixIconColor: AppColors.textMuted,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Email is required.');
                    }
                    if (!value.contains('@')) {
                      return context.tr('Enter a valid email.');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: _loading
                    ? context.tr('Sending...')
                    : context.tr('Send Code'),
                onPressed: _loading ? () {} : _sendCode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      children: [
        Text(
          context.tr('Enter Code'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          '${context.tr('We sent a 6 digit code to')} $_maskedEmail',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
        const SizedBox(height: 18),
        _Card(
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    FocusScope.of(context).requestFocus(_codeFocusNode),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _codeController,
                      builder: (context, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          final text = _codeController.text;
                          final digit = index < text.length
                              ? text[index]
                              : '';
                          final active =
                              index == text.length && text.length < 6;
                          return Container(
                            width: 42,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cardSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: active
                                    ? AppColors.hotPink
                                    : AppColors.border,
                                width: active ? 1.8 : 1,
                              ),
                            ),
                            child: Text(
                              digit,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Positioned.fill(
                      child: TextField(
                        controller: _codeController,
                        focusNode: _codeFocusNode,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(),
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        inputFormatters: [
                          TextInputFormatter.withFunction((old, next) {
                            final normalized = _normalizeOtpDigits(next.text);
                            final truncated = normalized.length > 6
                                ? normalized.substring(0, 6)
                                : normalized;
                            return TextEditingValue(
                              text: truncated,
                              selection: TextSelection.collapsed(
                                offset: truncated.length,
                              ),
                            );
                          }),
                        ],
                        style: const TextStyle(
                          color: Colors.transparent,
                          fontSize: 1,
                        ),
                        cursorColor: Colors.transparent,
                        decoration: const InputDecoration(
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {});
                          if (value.length == 6 && !_loading) _verifyCode();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: _loading
                    ? context.tr('Verifying...')
                    : context.tr('Verify Code'),
                onPressed: _loading ? () {} : _verifyCode,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _secondsLeft == 0 && !_loading ? _resendCode : null,
                child: Text(
                  _secondsLeft == 0
                      ? context.tr('Resend code')
                      : '${context.tr('Resend in')} ${_secondsLeft}s',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        Text(
          context.tr('Set New Password'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('Choose a new password for your account.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
        ),
        const SizedBox(height: 18),
        _Card(
          child: Form(
            key: _newPasswordFormKey,
            autovalidateMode: _autoValidatePassword
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              children: [
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    hintText: context.tr('New password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    prefixIconColor: AppColors.textMuted,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return context.tr(
                        'Password must be at least 6 characters.',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: context.tr('Confirm password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    prefixIconColor: AppColors.textMuted,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirmPassword =
                            !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value != _newPasswordController.text) {
                      return context.tr('Passwords do not match.');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: _loading
                      ? context.tr('Saving...')
                      : context.tr('Reset Password'),
                  onPressed: _loading ? () {} : _submitNewPassword,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [AppColors.cosmicPurple, AppColors.deepSpace],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(size: 200, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

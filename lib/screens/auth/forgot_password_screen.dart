import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  late final TextEditingController _emailController;
  bool _sending = false;
  bool _sent = false;
  bool _autoValidate = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _authService.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Password reset link sent to your email.'),
            style: const TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B1B44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _friendlyError(context, e),
            style: const TextStyle(color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF41203D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
                        onPressed: () => Navigator.maybePop(context),
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
                  Text(
                    context.tr('Forgot Password?'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Enter your email address and we will send you a reset link.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Form(
                          key: _formKey,
                          autovalidateMode: _autoValidate
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
                          label: _sending
                              ? context.tr('Sending...')
                              : context.tr('Send Reset Link'),
                          onPressed: _sending ? () {} : _submit,
                        ),
                        if (_sent) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.neonGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.neonGreen.withOpacity(0.42),
                              ),
                            ),
                            child: Text(
                              context.tr(
                                'Check your email inbox and spam folder for the reset link.',
                              ),
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _friendlyError(BuildContext context, Object e) {
  final text = e.toString();
  if (text.contains('user-not-found')) {
    return context.tr('No user found for that email.');
  }
  if (text.contains('invalid-email')) {
    return context.tr('Invalid email address.');
  }
  if (text.contains('too-many-requests')) {
    return context.tr('Too many requests. Please try again later.');
  }
  return context.tr('Unable to send reset email. Please try again.');
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
          colors: [color.withOpacity(0.7), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

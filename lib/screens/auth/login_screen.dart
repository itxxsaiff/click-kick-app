import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/social_icon_button.dart';
import '../shared/legal_center_screen.dart';

enum _SocialProvider { google, apple, facebook }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _autoValidate = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = true);
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      _showMessage(context.tr('Login successful.'));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _handleSocialLogin(_SocialProvider provider) async {
    setState(() => _isLoading = true);
    try {
      if (provider == _SocialProvider.google) {
        await _authService.signInWithGoogle();
      } else if (provider == _SocialProvider.apple) {
        await _authService.signInWithApple();
      } else {
        await _authService.signInWithFacebook();
      }
      if (!mounted) return;
      _showMessage(context.tr('Login successful.'));
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showMessage(_friendlySocialError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlySocialError(Object e) {
    final text = e.toString();
    if (text.contains('operation-not-allowed')) {
      return 'This social provider is not enabled in Firebase yet.';
    }
    if (text.contains('popup-closed-by-user')) {
      return 'Login cancelled.';
    }
    if (text.contains('web-context-cancelled')) {
      return 'Login cancelled.';
    }
    if (text.contains('network-request-failed')) {
      return 'Network issue. Please try again.';
    }
    return 'Social login failed. Please try again.';
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('account-disabled-by-admin')) {
      return context.tr(
        'Your account access has been disabled. Please contact the administrator.',
      );
    }
    if (text.contains('user-not-found')) {
      return context.tr('No user found for that email.');
    }
    if (text.contains('wrong-password')) {
      return context.tr('Incorrect password.');
    }
    if (text.contains('invalid-credential')) {
      return context.tr('Email or password is incorrect.');
    }
    if (text.contains('invalid-email')) {
      return context.tr('Invalid email address.');
    }
    if (text.contains('permission-denied')) {
      return context.tr('Firestore permission denied. Check rules.');
    }
    return context.tr('Login failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 820;
                final horizontal = constraints.maxWidth < 420 ? 20.0 : 24.0;
                final vertical = isCompact ? 8.0 : 12.0;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LogoBadge(compact: isCompact),
                    SizedBox(height: isCompact ? 6 : 12),
                    _AuthCard(
                      compact: isCompact,
                      title: context.tr('Welcome Back'),
                      subtitle: context.tr(
                        'Login to continue the contest fun.',
                      ),
                      children: [
                        Form(
                          key: _formKey,
                          autovalidateMode: _autoValidate
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: context.tr('Email'),
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: context.tr('Password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  prefixIconColor: AppColors.textMuted,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return context.tr('Password is required.');
                                  }
                                  if (value.length < 6) {
                                    return context.tr('Minimum 6 characters.');
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isCompact ? 12 : 20),
                        GradientButton(
                          label: _isLoading
                              ? context.tr('Loading...')
                              : context.tr('Login'),
                          onPressed: _isLoading ? () {} : _handleLogin,
                        ),
                        SizedBox(height: isCompact ? 6 : 12),
                        TextButton(
                          onPressed: () {},
                          child: Text(context.tr('Forgot password?')),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 8 : 14),
                    Text(
                      context.tr('Or login with'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    SizedBox(height: isCompact ? 8 : 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SocialIconButton(
                          onPressed: _isLoading
                              ? () {}
                              : () =>
                                    _handleSocialLogin(_SocialProvider.google),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SocialIconButton(
                          onPressed: _isLoading
                              ? () {}
                              : () => _handleSocialLogin(_SocialProvider.apple),
                          child: const Icon(
                            Icons.apple,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SocialIconButton(
                          onPressed: _isLoading
                              ? () {}
                              : () => _handleSocialLogin(
                                  _SocialProvider.facebook,
                                ),
                          child: const Icon(
                            Icons.facebook,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 8 : 12),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LegalCenterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.privacy_tip_outlined),
                      label: Text(context.tr('Legal & Privacy')),
                    ),
                    SizedBox(height: isCompact ? 8 : 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('New here?'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: Text(context.tr('Create account')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
                final padding = EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: vertical,
                );
                return SingleChildScrollView(
                  padding: padding,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (padding.vertical),
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LogoImage(compact: compact),
        SizedBox(height: compact ? 6 : 12),
        const Text(
          'Video Contest',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textLight,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          context.tr('Showtime Arena'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final glowWidth = compact ? 160.0 : 220.0;
    final glowHeight = compact ? 78.0 : 120.0;
    final logoWidth = compact ? 122.0 : 184.0;
    final logoHeight = compact ? 84.0 : 116.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: glowWidth,
          height: glowHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: RadialGradient(
              colors: [
                AppColors.hotPink.withValues(alpha: 0.35),
                AppColors.hotPink.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        SizedBox(
          width: logoWidth,
          height: logoHeight,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.compact,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final bool compact;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: compact ? 4 : 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: compact ? 12 : 18),
          ...children,
        ],
      ),
    );
  }
}

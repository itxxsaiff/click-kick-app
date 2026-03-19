import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../shared/legal_center_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _companyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _phoneCountryCode = '+1';
  String _phoneCountryIso = 'US';
  final _authService = AuthService();
  bool _isSponsor = false;
  bool _acceptedTerms = true;
  bool _isLoading = false;
  bool _autoValidate = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _pickSponsorCountry() async {
    Country? selected;
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.card,
        textStyle: const TextStyle(color: AppColors.textLight),
        inputDecoration: InputDecoration(
          labelText: context.tr('Search country'),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      onSelect: (country) {
        selected = country;
        if (!mounted) return;
        setState(() => _countryController.text = selected!.name);
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _countryController.dispose();
    _companyController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = true);
      return;
    }
    if (!_acceptedTerms) {
      _showMessage(context.tr('Please accept the terms to continue.'));
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final password = _passwordController.text.trim();
    final country = _countryController.text.trim();
    final company = _companyController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_isSponsor) {
        await _authService.registerSponsor(
          email: email,
          password: password,
          displayName: name,
          phoneCountryCode: _phoneCountryCode,
          phoneNumber: phone,
          country: country,
          companyName: company,
          acceptedTerms: _acceptedTerms,
        );
      } else {
        await _authService.registerWithEmail(
          email: email,
          password: password,
          displayName: name,
          phoneCountryCode: _phoneCountryCode,
          phoneNumber: phone,
          acceptedTerms: _acceptedTerms,
        );
      }
      _showMessage(
        _isSponsor
            ? context.tr('Sponsor account created.')
            : context.tr('Account created.'),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      }
    } catch (e) {
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

  Future<void> _showAgreementModal() async {
    final title = _isSponsor
        ? context.tr('Sponsor Agreement')
        : context.tr('User Agreement');
    final body = _isSponsor
        ? context.tr('Sponsor Agreement Content')
        : context.tr('User Agreement Content');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Close')),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('email-already-in-use')) {
      return context.tr('Email already registered.');
    }
    if (text.contains('invalid-email')) {
      return context.tr('Invalid email address.');
    }
    if (text.contains('weak-password')) {
      return context.tr('Password is too weak.');
    }
    if (text.contains('operation-not-allowed')) {
      return context.tr('Email/password sign-in not enabled in Firebase.');
    }
    if (text.contains('permission-denied')) {
      return context.tr('Firestore permission denied. Check rules.');
    }
    return context.tr('Registration failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('Create Account'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      const LanguageMenuButton(compact: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _isSponsor = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSponsor
                                    ? Colors.transparent
                                    : AppColors.hotPink.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('Register User'),
                                  style: TextStyle(
                                    color: _isSponsor
                                        ? AppColors.textMuted
                                        : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _isSponsor = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSponsor
                                    ? AppColors.hotPink.withOpacity(0.22)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  context.tr('Join Sponsor'),
                                  style: TextStyle(
                                    color: _isSponsor
                                        ? Colors.white
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  _AuthCard(
                    title: _isSponsor
                        ? context.tr('Join as Sponsor')
                        : context.tr('Join the Contest'),
                    subtitle: _isSponsor
                        ? context.tr(
                            'Create sponsor account and manage your assigned contests.',
                          )
                        : context.tr(
                            'Upload, compete, and win amazing prizes.',
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
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: context.tr('Full name'),
                                prefixIcon: const Icon(Icons.person_outline),
                                prefixIconColor: AppColors.textMuted,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return context.tr('Full name is required.');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
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
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      showCountryPicker(
                                        context: context,
                                        showPhoneCode: true,
                                        countryListTheme: CountryListThemeData(
                                          backgroundColor: AppColors.card,
                                          textStyle: TextStyle(
                                            color: AppColors.textLight,
                                          ),
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(18),
                                          ),
                                          bottomSheetHeight: 560,
                                          inputDecoration: InputDecoration(
                                            labelText: context.tr(
                                              'Search country',
                                            ),
                                            prefixIcon: Icon(Icons.search),
                                          ),
                                        ),
                                        onSelect: (country) {
                                          setState(() {
                                            _phoneCountryCode =
                                                '+${country.phoneCode}';
                                            _phoneCountryIso =
                                                country.countryCode;
                                          });
                                        },
                                      );
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: context.tr('Code'),
                                        prefixIcon: Icon(Icons.flag_outlined),
                                        prefixIconColor: AppColors.textMuted,
                                      ),
                                      child: Text(
                                        '$_phoneCountryIso $_phoneCountryCode',
                                        style: const TextStyle(
                                          color: AppColors.textLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: context.tr('Phone number'),
                                      prefixIcon: Icon(Icons.phone_outlined),
                                      prefixIconColor: AppColors.textMuted,
                                    ),
                                    validator: (value) {
                                      final raw = (value ?? '').trim();
                                      if (raw.isEmpty) {
                                        return context.tr(
                                          'Phone number is required.',
                                        );
                                      }
                                      final digitsOnly = raw.replaceAll(
                                        RegExp(r'[^0-9]'),
                                        '',
                                      );
                                      if (digitsOnly.length < 7) {
                                        return context.tr(
                                          'Enter valid phone number.',
                                        );
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isSponsor) ...[
                              TextFormField(
                                controller: _countryController,
                                readOnly: true,
                                onTap: _pickSponsorCountry,
                                decoration: InputDecoration(
                                  labelText: context.tr('Country'),
                                  prefixIcon: const Icon(Icons.public),
                                  suffixIcon: IconButton(
                                    onPressed: _pickSponsorCountry,
                                    icon: const Icon(Icons.arrow_drop_down),
                                  ),
                                  prefixIconColor: AppColors.textMuted,
                                ),
                                validator: (value) {
                                  if (!_isSponsor) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return context.tr('Country is required.');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _companyController,
                                decoration: InputDecoration(
                                  labelText: context.tr('Company name'),
                                  prefixIcon: const Icon(Icons.business),
                                  prefixIconColor: AppColors.textMuted,
                                ),
                                validator: (value) {
                                  if (!_isSponsor) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return context.tr(
                                      'Company name is required.',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: context.tr('Password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                prefixIconColor: AppColors.textMuted,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: context.tr('Confirm password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                prefixIconColor: AppColors.textMuted,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr('Confirm your password.');
                                }
                                if (value != _passwordController.text) {
                                  return context.tr('Passwords do not match.');
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (value) {
                              setState(() => _acceptedTerms = value ?? false);
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                      text: context.tr(
                                        'I have read and agree to the ',
                                      ),
                                    ),
                                    TextSpan(
                                      text: context.tr('terms'),
                                      style: const TextStyle(
                                        color: AppColors.hotPink,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showAgreementModal,
                                    ),
                                    TextSpan(text: context.tr('.')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GradientButton(
                        label: _isLoading
                            ? context.tr('Creating...')
                            : (_isSponsor
                                  ? context.tr('Create Sponsor Account')
                                  : context.tr('Create Account')),
                        onPressed: _isLoading ? () {} : _handleRegister,
                      ),
                      const SizedBox(height: 10),
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.tr('Already have an account?'),
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Login')),
                      ),
                    ],
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

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.nebula, AppColors.deepSpace],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            bottom: -140,
            left: -60,
            child: _GlowOrb(size: 240, color: AppColors.magenta),
          ),
          Positioned(
            top: 40,
            right: -40,
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
          colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 72,
            height: 48,
            child: Image(
              image: AssetImage('assets/images/logo.png'),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr(
                'Compete in weekly contests and earn prizes with your 30-45s videos.',
              ),
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

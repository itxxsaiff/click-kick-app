import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../shared/legal_center_screen.dart';

const _kCreateAccount = 'Create Account';
const _kSelectAccountType = 'Select Account Type';
const _kPersonalAccount = 'Personal Account';
const _kBusinessAccount = 'Business Account';
const _kCreateBusinessAccount = 'Create Business Account';
const _kJoinTheContest = 'Join the Contest';
const _kFullName = 'Full name';
const _kEmail = 'Email';
const _kSearchCountry = 'Search country';
const _kCode = 'Code';
const _kPhoneNumber = 'Phone number';
const _kCountry = 'Country';
const _kCompanyName = 'Company name';
const _kPassword = 'Password';
const _kConfirmPassword = 'Confirm password';
const _kLegalPrivacy = 'Legal & Privacy';
const _kAlreadyHaveAccount = 'Already have an account?';
const _kLogin = 'Login';
const _kTermsPrefix = 'I have read and agree to the ';
const _kTerms = 'terms';
final _arabicScriptRegExp = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');

class AccountTypeSelectionScreen extends StatelessWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 220,
                    height: 170,
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _kCreateAccount,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _kSelectAccountType,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AccountTypeTile(
                    icon: Icons.person_outline_rounded,
                    title: _kPersonalAccount,
                    accent: AppColors.hotPink,
                    onTap: () => Navigator.pushNamed(context, '/register?type=user'),
                    showArrow: true,
                  ),
                  const SizedBox(height: 16),
                  _AccountTypeTile(
                    icon: Icons.business_center_outlined,
                    title: _kBusinessAccount,
                    accent: const Color(0xFF47C8FF),
                    onTap: () =>
                        Navigator.pushNamed(context, '/register?type=business'),
                    showArrow: true,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.isSponsor = false});

  final bool isSponsor;

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
  late final bool _isSponsor;
  bool _acceptedTerms = true;
  bool _isLoading = false;
  bool _autoValidate = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isSponsor = widget.isSponsor;
  }

  Future<void> _pickSponsorCountry() async {
    Country? selected;
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.card,
        textStyle: const TextStyle(color: AppColors.textLight),
        inputDecoration: InputDecoration(
          labelText: _kSearchCountry,
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
      _showMessage('Please accept the terms to continue.');
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
        _isSponsor ? 'Business account created.' : 'Account created.',
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
    final title = _isSponsor ? 'Sponsor Agreement' : 'User Agreement';
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('email-already-in-use')) {
      return 'Email already registered.';
    }
    if (text.contains('invalid-email')) {
      return 'Invalid email address.';
    }
    if (text.contains('weak-password')) {
      return 'Password is too weak.';
    }
    if (text.contains('operation-not-allowed')) {
      return 'Email/password sign-in not enabled in Firebase.';
    }
    if (text.contains('permission-denied')) {
      return 'Firestore permission denied. Check rules.';
    }
    if (text.contains('invalid-phone-number')) {
      return 'Phone number is required.';
    }
    return 'Registration failed. Please try again.';
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
                        _isSponsor
                            ? _kBusinessAccount
                            : _kPersonalAccount,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      const LanguageMenuButton(compact: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 8),
                  _AuthCard(
                    title: _isSponsor
                        ? _kCreateBusinessAccount
                        : _kJoinTheContest,
                    subtitle: '',
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
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(_arabicScriptRegExp),
                              ],
                              decoration: InputDecoration(
                                labelText: _kFullName,
                                prefixIcon: const Icon(Icons.person_outline),
                                prefixIconColor: AppColors.textMuted,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Full name is required.';
                                }
                                if (_arabicScriptRegExp.hasMatch(value)) {
                                  return 'Use English only.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: _kEmail,
                                prefixIcon: const Icon(Icons.email_outlined),
                                prefixIconColor: AppColors.textMuted,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required.';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                showCountryPicker(
                                  context: context,
                                  showPhoneCode: true,
                                  countryListTheme: CountryListThemeData(
                                    backgroundColor: AppColors.card,
                                    textStyle: const TextStyle(
                                      color: AppColors.textLight,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    bottomSheetHeight: 560,
                                    inputDecoration: InputDecoration(
                                      labelText: _kSearchCountry,
                                      prefixIcon: const Icon(Icons.search),
                                    ),
                                  ),
                                  onSelect: (country) {
                                    setState(() {
                                      _phoneCountryCode = '+${country.phoneCode}';
                                      _phoneCountryIso = country.countryCode;
                                    });
                                  },
                                );
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: _kCode,
                                  prefixIcon: const Icon(Icons.flag_outlined),
                                  prefixIconColor: AppColors.textMuted,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: _kPhoneNumber,
                                prefixIcon: const Icon(Icons.phone_outlined),
                                prefixIconColor: AppColors.textMuted,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 18,
                                ),
                              ),
                              validator: (value) {
                                final raw = (value ?? '').trim();
                                if (raw.isEmpty) {
                                  return 'Phone number is required.';
                                }
                                final digitsOnly = raw.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                if (digitsOnly.length < 7) {
                                  return 'Enter valid phone number.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_isSponsor) ...[
                              TextFormField(
                                controller: _countryController,
                                readOnly: true,
                                onTap: _pickSponsorCountry,
                                decoration: InputDecoration(
                                  labelText: _kCountry,
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
                                    return 'Country is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _companyController,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(_arabicScriptRegExp),
                                ],
                                decoration: InputDecoration(
                                  labelText: _kCompanyName,
                                  prefixIcon: const Icon(Icons.business),
                                  prefixIconColor: AppColors.textMuted,
                                ),
                                validator: (value) {
                                  if (!_isSponsor) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Company name is required.';
                                  }
                                  if (_arabicScriptRegExp.hasMatch(value)) {
                                    return 'Use English only.';
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
                                labelText: _kPassword,
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
                                  return 'Password is required.';
                                }
                                if (value.length < 6) {
                                  return 'Minimum 6 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: _kConfirmPassword,
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
                                  return 'Confirm your password.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
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
                        label: const Text(_kLegalPrivacy),
                      ),
                      const SizedBox(height: 8),
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
                                      text: _kTermsPrefix,
                                    ),
                                    TextSpan(
                                      text: _kTerms,
                                      style: const TextStyle(
                                        color: AppColors.hotPink,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showAgreementModal,
                                    ),
                                    const TextSpan(text: '.'),
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
                            ? 'Creating...'
                            : (_isSponsor
                                  ? _kCreateBusinessAccount
                                  : _kCreateAccount),
                        onPressed: _isLoading ? () {} : _handleRegister,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _kAlreadyHaveAccount,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(_kLogin),
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

class _AccountTypeTile extends StatelessWidget {
  const _AccountTypeTile({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
    this.showArrow = false,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.75)),
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showArrow)
              Icon(Icons.chevron_right_rounded, color: accent, size: 34),
          ],
        ),
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
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

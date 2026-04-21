import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.maskedPhone});

  final String maskedPhone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _authService = AuthService();
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  bool _isLoading = false;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
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

  Future<bool> _leaveOtp() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
    return false;
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage(context.tr('Enter the 6 digit code.'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.verifyLoginOtp(code: code);
      if (!mounted) return;
      _showMessage(context.tr('OTP verified.'));
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      _showMessage(_friendlyOtpError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _authService.sendLoginOtp();
      if (!mounted) return;
      _codeController.clear();
      _startTimer();
      _showMessage(context.tr('OTP sent on WhatsApp.'));
    } catch (e) {
      _showMessage(_friendlyOtpError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyOtpError(Object e) {
    final text = e.toString();
    if (text.contains('deadline-exceeded') || text.contains('OTP expired')) {
      return context.tr('OTP expired. Please request a new code.');
    }
    if (text.contains('permission-denied') || text.contains('Invalid OTP')) {
      return context.tr('Invalid OTP. Please try again.');
    }
    if (text.contains('resource-exhausted')) {
      return context.tr('Too many attempts. Please request a new OTP.');
    }
    if (text.contains('Please wait')) {
      return context.tr('Please wait before requesting another OTP.');
    }
    if (text.contains('No phone number')) {
      return context.tr('No phone number found for this account.');
    }
    return context.tr('Unable to send OTP. Please try again.');
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_leaveOtp());
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            const _OtpBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x552A0C43),
                          blurRadius: 26,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton(
                            onPressed: _leaveOtp,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: AppColors.hotPink.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.hotPink.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.hotPink,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          context.tr('Verify your phone'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textLight,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.tr('We sent a WhatsApp code to your registered number.')} ${widget.maskedPhone}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),
                        GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _codeController,
                                builder: (context, _) => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final text = _codeController.text;
                                    final digit = index < text.length
                                        ? text[index]
                                        : '';
                                    final active =
                                        index == text.length && text.length < 6;
                                    return _OtpBox(
                                      digit: digit,
                                      active: active,
                                    );
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 1,
                                height: 1,
                                child: TextField(
                                  controller: _codeController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    color: Colors.transparent,
                                    fontSize: 1,
                                  ),
                                  cursorColor: Colors.transparent,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                    if (value.length == 6 && !_isLoading) {
                                      _verify();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        GradientButton(
                          label: _isLoading
                              ? context.tr('Loading...')
                              : context.tr('Verify'),
                          onPressed: _isLoading ? () {} : _verify,
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: _secondsLeft == 0 && !_isLoading
                              ? _resend
                              : null,
                          child: Text(
                            _secondsLeft == 0
                                ? context.tr('Resend code')
                                : '${context.tr('Resend in')} ${_secondsLeft}s',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.hotPink : AppColors.border,
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
  }
}

class _OtpBackground extends StatelessWidget {
  const _OtpBackground();

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
            top: -110,
            left: -60,
            child: _OtpGlow(size: 240, color: AppColors.hotPink),
          ),
          Positioned(
            top: 170,
            right: -80,
            child: _OtpGlow(size: 220, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _OtpGlow extends StatelessWidget {
  const _OtpGlow({required this.size, required this.color});

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
          colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

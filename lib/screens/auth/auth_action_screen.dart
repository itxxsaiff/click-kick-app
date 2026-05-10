import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class AuthActionScreen extends StatefulWidget {
  const AuthActionScreen({
    super.key,
    required this.mode,
    required this.oobCode,
  });

  final String mode;
  final String oobCode;

  @override
  State<AuthActionScreen> createState() => _AuthActionScreenState();
}

class _AuthActionScreenState extends State<AuthActionScreen> {
  final _auth = FirebaseAuth.instance;
  final _authService = AuthService();
  bool _loading = true;
  bool _success = false;
  String _title = '';
  String _message = '';

  @override
  void initState() {
    super.initState();
    _handleAction();
  }

  Future<void> _handleAction() async {
    if (widget.oobCode.isEmpty) {
      setState(() {
        _loading = false;
        _title = 'Invalid link';
        _message = 'This verification link is missing required data.';
      });
      return;
    }

    try {
      final info = await _auth.checkActionCode(widget.oobCode);
      await _auth.applyActionCode(widget.oobCode);
      await _auth.currentUser?.reload();
      await _authService.syncCurrentUserDoc();

      final email = (info.data['email'] ?? '').toString();
      final previousEmail = (info.data['previousEmail'] ?? '').toString();

      setState(() {
        _loading = false;
        _success = true;
        if (widget.mode == 'verifyAndChangeEmail') {
          _title = 'Email Updated';
          _message = previousEmail.isNotEmpty && email.isNotEmpty
              ? 'Your email has been changed from $previousEmail to $email.'
              : 'Your email address has been updated successfully.';
        } else {
          _title = 'Email Verified';
          _message = email.isNotEmpty
              ? 'Your email $email has been verified successfully.'
              : 'Your email has been verified successfully.';
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _success = false;
        _title = 'Verification failed';
        if (e.code == 'invalid-action-code') {
          _message =
              'This verification link is invalid or has already been used.';
        } else if (e.code == 'expired-action-code') {
          _message = 'This verification link has expired.';
        } else {
          _message = 'Unable to complete this action (${e.code}).';
        }
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _success = false;
        _title = 'Verification failed';
        _message = 'Unable to complete this action.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.15,
            colors: [AppColors.cosmicPurple, AppColors.deepSpace],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 68,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_loading) ...[
                      const CircularProgressIndicator(
                        color: AppColors.hotPink,
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.tr('Processing...'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        _success
                            ? Icons.verified_rounded
                            : Icons.error_outline_rounded,
                        size: 70,
                        color: _success
                            ? AppColors.neonGreen
                            : AppColors.hotPink,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.tr(_title),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(_message),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      GradientButton(
                        label: context.tr('Back to Login'),
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

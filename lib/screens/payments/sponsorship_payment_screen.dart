import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../l10n/l10n.dart';
import '../../services/payment_service.dart';
import '../../theme/app_colors.dart';

class SponsorshipPaymentScreen extends StatefulWidget {
  const SponsorshipPaymentScreen({
    super.key,
    required this.applicationId,
    required this.amount,
    required this.title,
  });

  final String applicationId;
  final double amount;
  final String title;

  @override
  State<SponsorshipPaymentScreen> createState() =>
      _SponsorshipPaymentScreenState();
}

class _SponsorshipPaymentScreenState extends State<SponsorshipPaymentScreen> {
  final _paymentService = PaymentService();
  final _nameController = TextEditingController();
  final _cardController = CardFormEditController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_submitting) return;
    if (_nameController.text.trim().isEmpty) {
      _show(context.tr('Cardholder name is required.'));
      return;
    }
    if (!kIsWeb && !_cardController.details.complete) {
      _show(context.tr('Please complete your card details.'));
      return;
    }

    setState(() => _submitting = true);
    try {
      await _paymentService.confirmSponsorshipPaymentWithCard(
        applicationId: widget.applicationId,
        cardholderName: _nameController.text.trim(),
      );
      await _paymentService.waitForApplicationPaid(widget.applicationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Payment completed successfully.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _show(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('canceled')) return context.tr('Payment cancelled.');
    if (text.contains('Already paid')) return context.tr('This application is already paid.');
    if (text.contains('Failed to launch')) return context.tr('Unable to open Stripe checkout.');
    return context.tr('Payment failed. Please try again.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Secure Payment')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.tr('Amount')}: \$${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.sunset,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kIsWeb
                            ? context.tr('On web, Stripe checkout will open in a secure page.')
                            : context.tr('Enter your card details below to complete payment securely.'),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: context.tr('Cardholder name'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (kIsWeb)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            context.tr('Stripe will open a secure hosted card form for web payments.'),
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: CardFormField(
                            controller: _cardController,
                            style: CardFormStyle(
                              backgroundColor: AppColors.cardSoft,
                              textColor: Colors.white,
                              placeholderColor: AppColors.textMuted,
                              borderColor: AppColors.border,
                              borderRadius: 16,
                              cursorColor: AppColors.hotPink,
                              textErrorColor: AppColors.hotPink,
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _pay,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.hotPink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: const Icon(Icons.lock_outline),
                          label: Text(
                            _submitting
                                ? context.tr('Processing...')
                                : context.tr('Pay Securely'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          radius: 1.25,
          colors: [AppColors.cosmicPurple, AppColors.deepSpace],
        ),
      ),
    );
  }
}

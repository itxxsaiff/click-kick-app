import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../admin/admin_dashboard.dart';
import '../employee/employee_dashboard.dart';
import '../public/public_feed_screen.dart';
import '../auth/otp_verification_screen.dart';
import 'sponsor_home.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  String _maskedPhone(Map<String, dynamic> data) {
    final phoneE164 = (data['phoneE164'] as String?)?.trim() ?? '';
    final countryCode = (data['phoneCountryCode'] as String?)?.trim() ?? '';
    final phoneNumber = (data['phoneNumber'] as String?)?.trim() ?? '';
    final digits =
        (phoneE164.isNotEmpty ? phoneE164 : '$countryCode$phoneNumber')
            .replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    final suffix = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;
    return '****$suffix';
  }

  Future<Map<String, dynamic>> _loadUserData(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      return snap.data() ?? const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const PublicFeedScreen();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserData(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final role = (data['role'] as String?) ?? 'user';
        final displayName = (data['displayName'] as String?) ?? 'User';
        final accountStatus = (() {
          final status =
              (data['status'] as String?)?.trim().toLowerCase() ?? '';
          if (status.isNotEmpty) return status;
          return ((data['accountStatus'] as String?) ?? 'active')
              .trim()
              .toLowerCase();
        })();
        final isBlocked =
            accountStatus == 'disabled' ||
            accountStatus == 'removed' ||
            accountStatus == 'deleted';

        if (isBlocked &&
            (role == 'employee' ||
                role == 'participant' ||
                role == 'user' ||
                role == 'sponsor')) {
          return const _BlockedAccessScreen();
        }

        final authService = AuthService();
        if (authService.requiresOtpVerification(user: user, userData: data)) {
          return OtpVerificationScreen(maskedPhone: _maskedPhone(data));
        }

        if (role == 'superAdmin' || role == 'super_admin' || role == 'admin') {
          return AdminDashboard(displayName: displayName);
        }
        if (role == 'employee') {
          return EmployeeDashboard(displayName: displayName);
        }
        if (role == 'sponsor') {
          return SponsorHome(displayName: displayName);
        }
        return const PublicFeedScreen();
      },
    );
  }
}

class _BlockedAccessScreen extends StatelessWidget {
  const _BlockedAccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_rounded,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('Your account access has been disabled.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Please contact the administrator for further assistance.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: Text(context.tr('Logout')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../admin/admin_dashboard.dart';
import '../employee/employee_dashboard.dart';
import '../public/public_feed_screen.dart';
import 'sponsor_home.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const PublicFeedScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data() ?? {};
        final role = (data['role'] as String?) ?? 'user';
        final displayName = (data['displayName'] as String?) ?? 'User';
        final accountStatus = (data['accountStatus'] as String?) ?? 'active';
        final isBlocked =
            accountStatus == 'disabled' || accountStatus == 'removed';

        if (isBlocked &&
            (role == 'employee' ||
                role == 'participant' ||
                role == 'user' ||
                role == 'sponsor')) {
          return const _BlockedAccessScreen();
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
              const Icon(Icons.block_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                context.tr('Your account access has been disabled.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// This only handles the DEVICE side: asking for permission, keeping this
/// device's token saved on the user's profile, showing a banner while the app
/// is open, and opening the right screen when a notification is tapped. The
/// SENDING side lives in Cloud Functions (`functions/index.js`): a Firestore
/// trigger turns every `users/{uid}/notifications` write into a real push, so
/// every place that already writes one (video approved/rejected, a sponsor's
/// report, etc.) gets a push for free, plus dedicated triggers for new
/// contests, voting starting and results.
///
/// While the app is in the background or fully closed, Android/iOS show the
/// notification automatically — no code needed for that part.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// All devices are subscribed to this topic, used for broadcast-style
  /// announcements (e.g. "New contest is live!") sent to everyone at once
  /// instead of writing a document per user.
  static const String allUsersTopic = 'all_users';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance.subscribeToTopic(allUsersTopic);
    } catch (e) {
      debugPrint('Notification permission/topic setup failed: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _syncTokenForCurrentUser();
      }
    });
    if (FirebaseAuth.instance.currentUser != null) {
      await _syncTokenForCurrentUser();
    }

    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
    // App was fully closed and opened by tapping a notification.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _openFromMessage(initialMessage);
  }

  Future<void> _syncTokenForCurrentUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Could not read FCM token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not save FCM token: $e');
    }
  }

  /// Called on logout so a shared/borrowed device stops receiving this
  /// account's pushes.
  Future<void> removeTokenForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not remove FCM token: $e');
    }
  }

  void _showForegroundBanner(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        onVisible: () {},
      ),
    );
  }

  /// Opens the screen a notification points to, reusing the app's existing
  /// deep-link routes (built from the message's `data` payload — see
  /// `_buildRoute` in `functions/index.js`).
  void _openFromMessage(RemoteMessage message) {
    final route = message.data['route'];
    if (route is! String || route.isEmpty) return;
    rootNavigatorKey.currentState?.pushNamed(route);
  }
}

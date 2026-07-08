import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../firebase_options.dart';
import '../models/enums.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static AuthProvider? _pendingLinkProvider;
  static AuthCredential? _pendingLinkCredential;
  static String? _pendingLinkEmail;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const Set<String> _otpProtectedRoles = {
    'user',
    'participant',
    'sponsor',
  };

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  static ActionCodeSettings emailActionCodeSettings() {
    final authDomain =
        DefaultFirebaseOptions.web.authDomain ??
        'video-contest-show-b788b.firebaseapp.com';
    return ActionCodeSettings(
      url: 'https://$authDomain/auth-action',
      handleCodeInApp: false,
    );
  }

  String _normalizedPhone({
    required String phoneCountryCode,
    required String phoneNumber,
  }) {
    final code = phoneCountryCode.trim();
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.isEmpty || digits.length < 7) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'A valid phone number is required.',
      );
    }
    return digits;
  }

  String _phoneE164({
    required String phoneCountryCode,
    required String normalizedPhone,
  }) {
    return '${phoneCountryCode.trim()}$normalizedPhone';
  }

  Future<void> _assertRegistrationContactAvailable({
    required String email,
    required String phoneCountryCode,
    required String normalizedPhone,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final callable = FirebaseFunctions.instance.httpsCallable(
      'checkRegistrationAvailability',
    );
    final result = await callable.call<Map<String, dynamic>>({
      'email': normalizedEmail,
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': normalizedPhone,
    });
    final data = Map<String, dynamic>.from(result.data);
    final emailAvailable = data['emailAvailable'] == true;
    final phoneAvailable = data['phoneAvailable'] == true;

    if (!emailAvailable) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'This email is already linked to another account.',
      );
    }

    if (!phoneAvailable) {
      throw FirebaseAuthException(
        code: 'phone-number-already-in-use',
        message: 'This phone number is already linked to another account.',
      );
    }
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String phoneCountryCode,
    required String phoneNumber,
    required bool acceptedTerms,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhone = _normalizedPhone(
      phoneCountryCode: phoneCountryCode,
      phoneNumber: phoneNumber,
    );
    final phoneE164 = _phoneE164(
      phoneCountryCode: phoneCountryCode,
      normalizedPhone: normalizedPhone,
    );
    await _assertRegistrationContactAvailable(
      email: normalizedEmail,
      phoneCountryCode: phoneCountryCode,
      normalizedPhone: normalizedPhone,
    );
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);

    final now = DateTime.now().toUtc();
    final uid = credential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': normalizedEmail,
      'emailLower': normalizedEmail,
      'displayName': displayName,
      'role': enumToName(UserRole.user),
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': normalizedPhone,
      'phoneE164': phoneE164,
      'createdAt': now,
      'updatedAt': now,
      'termsAcceptedAt': acceptedTerms ? now : null,
    });

    return credential;
  }

  Future<UserCredential> registerSponsor({
    required String email,
    required String password,
    required String displayName,
    required String phoneCountryCode,
    required String phoneNumber,
    required String country,
    required String companyName,
    required bool acceptedTerms,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final normalizedPhone = _normalizedPhone(
      phoneCountryCode: phoneCountryCode,
      phoneNumber: phoneNumber,
    );
    final phoneE164 = _phoneE164(
      phoneCountryCode: phoneCountryCode,
      normalizedPhone: normalizedPhone,
    );
    await _assertRegistrationContactAvailable(
      email: normalizedEmail,
      phoneCountryCode: phoneCountryCode,
      normalizedPhone: normalizedPhone,
    );
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);

    final now = DateTime.now().toUtc();
    final uid = credential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': normalizedEmail,
      'emailLower': normalizedEmail,
      'displayName': displayName,
      'role': enumToName(UserRole.sponsor),
      'phoneCountryCode': phoneCountryCode,
      'phoneNumber': normalizedPhone,
      'phoneE164': phoneE164,
      'country': country,
      'companyName': companyName,
      'createdAt': now,
      'updatedAt': now,
      'termsAcceptedAt': acceptedTerms ? now : null,
    });

    return credential;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final credential = await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await _ensureUserDoc(credential.user!, roleIfMissing: UserRole.user);
    await _assertUserAccess(credential.user!.uid);
    await _linkPendingProviderIfNeeded(credential.user!);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    return _signInWithProvider(
      provider,
      roleIfMissing: UserRole.user,
      providerName: 'Google',
    );
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb) {
      final provider = AppleAuthProvider();
      return _signInWithProvider(
        provider,
        roleIfMissing: UserRole.user,
        providerName: 'Apple',
      );
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'apple-login-failed',
        message: 'Apple login failed. Please try again.',
      );
    }

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(
      idToken: idToken,
      rawNonce: rawNonce,
      accessToken: appleCredential.authorizationCode,
    );

    UserCredential credential;
    try {
      credential = await _auth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'email-already-in-use' ||
          e.code == 'credential-already-in-use') {
        final email = _normalizeEmail(appleCredential.email ?? e.email ?? '');
        _pendingLinkProvider = AppleAuthProvider();
        _pendingLinkCredential = oauthCredential;
        _pendingLinkEmail = email.isEmpty ? null : email;
        throw FirebaseAuthException(
          code: 'social-link-required',
          message:
              'This email already exists. Login with your password once to link Apple.',
        );
      }
      rethrow;
    }
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final resolvedDisplayName = _appleDisplayName(appleCredential);
    if ((user.displayName?.trim().isEmpty ?? true) &&
        resolvedDisplayName != null) {
      await user.updateDisplayName(resolvedDisplayName);
      await user.reload();
    }

    final refreshedUser = _auth.currentUser ?? user;
    await _assertNoSocialAccountConflict(
      refreshedUser,
      AppleAuthProvider(),
      'Apple',
      pendingCredential: oauthCredential,
    );
    await _ensureUserDoc(refreshedUser, roleIfMissing: UserRole.user);
    await _syncUserProviderMetadata(refreshedUser, provider: 'apple');
    await _assertUserAccess(refreshedUser.uid);
    return credential;
  }

  Future<UserCredential> signInWithFacebook() async {
    if (kIsWeb) {
      final provider = FacebookAuthProvider();
      return _signInWithProvider(
        provider,
        roleIfMissing: UserRole.user,
        providerName: 'Facebook',
      );
    }

    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );
    switch (result.status) {
      case LoginStatus.success:
        final accessToken = result.accessToken;
        if (accessToken == null) {
          throw FirebaseAuthException(
            code: 'facebook-access-token-missing',
            message: 'Facebook login failed. Please try again.',
          );
        }
        final credential = FacebookAuthProvider.credential(
          accessToken.tokenString,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) {
          throw FirebaseAuthException(code: 'user-not-found');
        }
        await _assertNoSocialAccountConflict(
          user,
          FacebookAuthProvider(),
          'Facebook',
        );
        await _ensureUserDoc(user, roleIfMissing: UserRole.user);
        await _assertUserAccess(user.uid);
        return userCredential;
      case LoginStatus.cancelled:
        throw FirebaseAuthException(
          code: 'web-context-cancelled',
          message: 'Login cancelled.',
        );
      case LoginStatus.failed:
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: result.message ?? 'Facebook login failed. Please try again.',
        );
      case LoginStatus.operationInProgress:
        throw FirebaseAuthException(
          code: 'operation-in-progress',
          message: 'Facebook login is already in progress.',
        );
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    final callable = FirebaseFunctions.instance.httpsCallable(
      'checkPasswordResetAvailability',
    );
    final result = await callable.call<Map<String, dynamic>>({
      'email': normalizedEmail,
    });
    final data = Map<String, dynamic>.from(result.data);
    if (data['emailExists'] != true) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user found for that email.',
      );
    }
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> incrementContestView(String contestId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'incrementContestView',
    );
    await callable.call<Map<String, dynamic>>({'contestId': contestId});
  }

  Future<void> incrementContestShare(String contestId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'incrementContestShare',
    );
    await callable.call<Map<String, dynamic>>({'contestId': contestId});
  }

  Future<void> incrementContestVote({
    required String contestId,
    required String submissionId,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'incrementContestVote',
    );
    await callable.call<Map<String, dynamic>>({
      'contestId': contestId,
      'submissionId': submissionId,
    });
  }

  Future<void> incrementAdminVideoView(String videoId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'incrementAdminVideoView',
    );
    await callable.call<Map<String, dynamic>>({'videoId': videoId});
  }

  Future<void> incrementAdminVideoShare(String videoId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'incrementAdminVideoShare',
    );
    await callable.call<Map<String, dynamic>>({'videoId': videoId});
  }

  Future<void> deleteUserAccountPermanently(String userId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'deleteUserAccountPermanently',
    );
    await callable.call<Map<String, dynamic>>({'userId': userId});
  }

  Future<UserCredential> _signInWithProvider(
    AuthProvider provider, {
    required UserRole roleIfMissing,
    required String providerName,
  }) async {
    final credential = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    await _assertNoSocialAccountConflict(user, provider, providerName);
    await _ensureUserDoc(user, roleIfMissing: roleIfMissing);
    await _syncUserProviderMetadata(
      user,
      provider: provider.providerId.replaceAll('.com', ''),
    );
    await _assertUserAccess(user.uid);
    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> syncCurrentUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _ensureUserDoc(user, roleIfMissing: UserRole.user);
  }

  Future<Map<String, dynamic>> sendLoginOtp() async {
    final callable = FirebaseFunctions.instance.httpsCallable('sendLoginOtp');
    final result = await callable.call<Map<String, dynamic>>();
    return Map<String, dynamic>.from(result.data);
  }

  Future<void> verifyLoginOtp({required String code}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('verifyLoginOtp');
    final result = await callable.call<Map<String, dynamic>>({'code': code});
    final data = Map<String, dynamic>.from(result.data);
    if (data['verified'] != true) {
      throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Invalid OTP.',
      );
    }
  }

  bool requiresOtpVerification({
    required User user,
    required Map<String, dynamic> userData,
  }) {
    final role = (userData['role'] ?? 'user').toString().trim().toLowerCase();
    if (!_otpProtectedRoles.contains(role)) {
      return false;
    }

    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (!hasPasswordProvider) {
      return false;
    }

    final verifiedAt = _parseUserDateTime(userData['lastOtpVerifiedAt']);
    return verifiedAt == null;
  }

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteCurrentUserAccount',
      );
      await callable.call<Map<String, dynamic>>();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw FirebaseAuthException(
          code: 'operation-not-allowed',
          message: e.message ?? 'Account deletion is not allowed.',
        );
      }
      rethrow;
    }

    await _auth.signOut();
  }

  Future<void> createEmployeeAccount({
    required String email,
    required String password,
    required String displayName,
    required String phoneCountryCode,
    required String phoneNumber,
  }) async {
    final adminUser = _auth.currentUser;
    if (adminUser == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }

    final appName = 'employee-${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(displayName);

      final now = DateTime.now().toUtc();
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'displayName': displayName,
        'role': 'employee',
        'accountStatus': 'active',
        'phoneCountryCode': phoneCountryCode,
        'phoneNumber': phoneNumber,
        'phoneE164': '$phoneCountryCode$phoneNumber',
        'createdAt': now,
        'updatedAt': now,
        'createdBy': adminUser.uid,
      });
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDocByEmail(
    String email,
  ) async {
    final normalizedEmail = _normalizeEmail(email);
    final byLower = await _firestore
        .collection('users')
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byLower.docs.isNotEmpty) {
      return byLower.docs.first;
    }

    final byEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byEmail.docs.isNotEmpty) {
      return byEmail.docs.first;
    }

    return null;
  }

  Future<void> _assertNoSocialAccountConflict(
    User user,
    AuthProvider provider,
    String providerName, {
    AuthCredential? pendingCredential,
  }) async {
    final email = user.email;
    if (email == null || email.trim().isEmpty) return;

    final existingDoc = await _findUserDocByEmail(email);
    if (existingDoc == null || existingDoc.id == user.uid) {
      return;
    }

    try {
      await user.delete();
    } catch (_) {
      // Best-effort cleanup only; the sign-in is still rejected below.
    }
    await _auth.signOut();
    _pendingLinkProvider = provider;
    _pendingLinkCredential = pendingCredential;
    _pendingLinkEmail = _normalizeEmail(email);
    throw FirebaseAuthException(
      code: 'social-link-required',
      message:
          'This email already exists. Login with your password once to link $providerName.',
    );
  }

  Future<void> _linkPendingProviderIfNeeded(User user) async {
    final provider = _pendingLinkProvider;
    final credential = _pendingLinkCredential;
    final pendingEmail = _pendingLinkEmail;
    if (provider == null && credential == null) return;

    final currentEmail = _normalizeEmail(user.email ?? '');
    if (pendingEmail != null && currentEmail != pendingEmail) {
      return;
    }

    try {
      if (credential != null) {
        await user.linkWithCredential(credential);
      } else if (kIsWeb) {
        await user.linkWithPopup(provider!);
      } else {
        await user.linkWithProvider(provider!);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
    } finally {
      _pendingLinkProvider = null;
      _pendingLinkCredential = null;
      _pendingLinkEmail = null;
    }
  }

  Future<void> _ensureUserDoc(
    User user, {
    required UserRole roleIfMissing,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    final now = DateTime.now().toUtc();
    final existingData = snap.data() ?? const <String, dynamic>{};
    await docRef.set({
      'uid': user.uid,
      'email': (user.email ?? '').trim().toLowerCase(),
      'emailLower': (user.email ?? '').trim().toLowerCase(),
      'displayName': (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (existingData['displayName'] ?? 'User').toString(),
      'role': (existingData['role'] ?? enumToName(roleIfMissing)).toString(),
      if (!snap.exists) 'createdAt': now,
      'pendingEmail': FieldValue.delete(),
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _assertUserAccess(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? const <String, dynamic>{};
    final status = _effectiveAccountStatus(data);
    if (status == 'disabled' || status == 'removed') {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'account-disabled-by-admin',
        message: 'Your access has been disabled by an administrator.',
      );
    }
  }

  String _effectiveAccountStatus(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    if (status.isNotEmpty) return status;
    return (data['accountStatus'] ?? 'active').toString().trim().toLowerCase();
  }

  DateTime? _parseUserDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  Future<void> _syncUserProviderMetadata(
    User user, {
    required String provider,
  }) async {
    final now = DateTime.now().toUtc();
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': (user.email ?? '').trim().toLowerCase(),
      'emailLower': (user.email ?? '').trim().toLowerCase(),
      'displayName': (user.displayName ?? '').trim(),
      'provider': provider,
      'lastLogin': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  String? _appleDisplayName(AuthorizationCredentialAppleID credential) {
    final parts = <String>[
      credential.givenName?.trim() ?? '',
      credential.familyName?.trim() ?? '',
    ].where((value) => value.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}

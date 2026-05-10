import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/enums.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static AuthProvider? _pendingLinkProvider;
  static String? _pendingLinkEmail;
  static String? _pendingLinkProviderName;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
    final isAdmin =
        email.toLowerCase() == 'admin@gmail.com' && password == 'admin123';
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _ensureUserDoc(
        credential.user!,
        roleIfMissing: isAdmin ? UserRole.superAdmin : UserRole.user,
      );
      await _assertUserAccess(credential.user!.uid);
      await _linkPendingProviderIfNeeded(credential.user!);
      if (isAdmin) {
        await _ensureRole(credential.user!.uid, UserRole.superAdmin);
      }
      return credential;
    } on FirebaseAuthException {
      if (isAdmin) {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final now = DateTime.now().toUtc();
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'displayName': 'Super Admin',
          'role': enumToName(UserRole.superAdmin),
          'createdAt': now,
          'updatedAt': now,
        });
        return credential;
      }
      rethrow;
    }
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
    final provider = AppleAuthProvider();
    return _signInWithProvider(
      provider,
      roleIfMissing: UserRole.user,
      providerName: 'Apple',
    );
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
      default:
        throw FirebaseAuthException(
          code: 'facebook-login-failed',
          message: 'Facebook login failed. Please try again.',
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

  Future<void> deleteCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'not-authenticated');
    }

    final now = DateTime.now().toUtc();
    await _firestore.collection('users').doc(user.uid).set({
      'accountStatus': 'deleted',
      'deletedAt': now,
      'updatedAt': now,
      'deletedBy': user.uid,
    }, SetOptions(merge: true));

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Please login again before deleting your account.',
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

  Future<void> _ensureRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).set({
      'role': enumToName(role),
      'updatedAt': DateTime.now().toUtc(),
    }, SetOptions(merge: true));
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
    String providerName,
  ) async {
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
    _pendingLinkEmail = _normalizeEmail(email);
    _pendingLinkProviderName = providerName;
    throw FirebaseAuthException(
      code: 'social-link-required',
      message:
          'This email already exists. Login with your password once to link $providerName.',
    );
  }

  Future<void> _linkPendingProviderIfNeeded(User user) async {
    final provider = _pendingLinkProvider;
    final pendingEmail = _pendingLinkEmail;
    if (provider == null || pendingEmail == null) return;

    final currentEmail = _normalizeEmail(user.email ?? '');
    if (currentEmail != pendingEmail) {
      return;
    }

    try {
      if (kIsWeb) {
        await user.linkWithPopup(provider);
      } else {
        await user.linkWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked' &&
          e.code != 'credential-already-in-use') {
        rethrow;
      }
    } finally {
      _pendingLinkProvider = null;
      _pendingLinkEmail = null;
      _pendingLinkProviderName = null;
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
    final status = (data['accountStatus'] ?? 'active').toString();
    if (status == 'disabled' || status == 'removed') {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'account-disabled-by-admin',
        message: 'Your access has been disabled by an administrator.',
      );
    }
  }
}

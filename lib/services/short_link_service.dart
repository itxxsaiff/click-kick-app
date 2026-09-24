import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Short, shareable links (`.../s/AbC1234`) that resolve back to a contest,
/// a general video, an admin feed video or a profile.
///
/// This only makes the link itself short — see `docs/deep_linking.md` for how
/// tapping such a link can also open the app directly (like Instagram/TikTok)
/// instead of the browser, which needs a one-time native setup this service
/// does not handle.
class ShortLinkService {
  ShortLinkService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Update this if/when the app moves to a custom domain (see
  /// `docs/deep_linking.md`) — every short link is built from it.
  static const String shareBaseUrl =
      'https://video-contest-show-b788b.firebaseapp.com';

  static const int _codeLength = 7;
  static const String _codeChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('short_links');

  String _randomCode() {
    final rand = Random.secure();
    return List.generate(
      _codeLength,
      (_) => _codeChars[rand.nextInt(_codeChars.length)],
    ).join();
  }

  /// Creates a new short code for [type]/[params] and returns the full link.
  /// A fresh code is created on every call (simpler and avoids needing a
  /// composite index to look up an existing one); collisions are vanishingly
  /// rare at 7 mixed-case + digit characters but are still checked for.
  Future<String> _createLink(String type, Map<String, String> params) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _randomCode();
      final ref = _collection.doc(code);
      if ((await ref.get()).exists) continue;
      try {
        await ref.set({
          'type': type,
          'params': params,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return '$shareBaseUrl/s/$code';
      } on FirebaseException {
        // Another share created this exact code in the same instant; retry
        // with a new random code.
        continue;
      }
    }
    throw Exception('Could not create a share link. Please try again.');
  }

  Future<String> contestShareLink({
    required String contestId,
    String? submissionId,
  }) {
    return _createLink('contest_share', {
      'contestId': contestId,
      if (submissionId != null && submissionId.isNotEmpty)
        'submissionId': submissionId,
    });
  }

  Future<String> generalVideoLink(String videoId) {
    return _createLink('general_video', {'videoId': videoId});
  }

  Future<String> adminVideoLink(String adminVideoId) {
    return _createLink('feed_video', {'videoId': adminVideoId});
  }

  Future<String> profileLink(String userId) {
    return _createLink('profile', {'userId': userId});
  }

  /// Looks up what [code] points to, or null when the link is unknown.
  Future<({String type, Map<String, String> params})?> resolve(
    String code,
  ) async {
    final snap = await _collection.doc(code).get();
    final data = snap.data();
    if (data == null) return null;
    final rawParams = data['params'];
    return (
      type: (data['type'] ?? '').toString(),
      params: rawParams is Map
          ? rawParams.map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{},
    );
  }
}

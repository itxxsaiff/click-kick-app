import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles user-to-user blocking of contest participants, required by
/// App Store Guideline 1.2 (User-Generated Content).
///
/// The source of truth is `users/{uid}.blockedUserIds` on the blocker's own
/// document (readable/writable by the owner), which drives instant client-side
/// filtering of the blocked participant's videos everywhere. Blocking also
/// creates a `video_reports` record (`type: block`) so moderators are notified
/// and can act on the offending content.
class BlockService {
  BlockService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Live set of participant ids the current user has blocked.
  /// Emits an empty set when signed out.
  Stream<Set<String>> blockedUserIdsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream<Set<String>>.value(<String>{});
    }
    return _firestore.collection('users').doc(user.uid).snapshots().map((snap) {
      return _readBlocked(snap.data());
    });
  }

  Future<Set<String>> fetchBlockedUserIds() async {
    final user = _auth.currentUser;
    if (user == null) return <String>{};
    final snap = await _firestore.collection('users').doc(user.uid).get();
    return _readBlocked(snap.data());
  }

  Set<String> _readBlocked(Map<String, dynamic>? data) {
    final list = (data?['blockedUserIds'] as List?) ?? const <dynamic>[];
    return list.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
  }

  /// Blocks [blockedUserId]. Persists the block on the current user's doc and
  /// files a moderation record. Throws:
  ///  - `login-required` when signed out.
  ///  - `cannot-block-self` when blocking own account.
  Future<void> blockParticipant({
    required String blockedUserId,
    String? contestId,
    String? submissionId,
    String? participantName,
    String? contestTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('login-required');
    }
    if (blockedUserId.isEmpty) {
      throw Exception('invalid-user');
    }
    if (blockedUserId == user.uid) {
      throw Exception('cannot-block-self');
    }

    final now = Timestamp.fromDate(DateTime.now().toUtc());

    // 1) Source of truth for instant client-side filtering.
    await _firestore.collection('users').doc(user.uid).set({
      'blockedUserIds': FieldValue.arrayUnion([blockedUserId]),
      'updatedAt': now,
    }, SetOptions(merge: true));

    // 2) Notify moderators through the existing report pipeline.
    await _firestore.collection('video_reports').add({
      'type': 'block',
      'videoType': 'participant_video',
      'reason': 'User blocked this participant for inappropriate content',
      'reasonCategory': 'Blocked participant',
      'blockerUserId': user.uid,
      'blockedUserId': blockedUserId,
      'reporterId': user.uid,
      'reporterUserId': user.uid,
      'reporterEmail': user.email ?? '',
      'targetUserId': blockedUserId,
      'reportedParticipantUserId': blockedUserId,
      'contestId': contestId,
      'submissionId': submissionId,
      'reportedVideoId': submissionId,
      'contestTitle': contestTitle,
      'participantName': participantName,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> unblockParticipant(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('login-required');
    }
    await _firestore.collection('users').doc(user.uid).set({
      'blockedUserIds': FieldValue.arrayRemove([blockedUserId]),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    }, SetOptions(merge: true));
  }
}

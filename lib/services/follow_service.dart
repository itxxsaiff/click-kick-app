import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Follow / unfollow and follower lists.
///
/// A follow is a doc `follows/{followerId}_{followingId}` holding
/// `followerId`, `followingId` and `createdAt`. Counts are read with Firestore
/// aggregate queries, so there are no denormalised counters to keep in sync.
class FollowService {
  FollowService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _follows =>
      _firestore.collection('follows');

  String? get currentUserId => _auth.currentUser?.uid;

  /// Live "does the current user follow [targetUserId]" flag.
  Stream<bool> isFollowingStream(String targetUserId) {
    final me = currentUserId;
    if (me == null || me == targetUserId) return Stream<bool>.value(false);
    return _follows.doc('${me}_$targetUserId').snapshots().map((s) => s.exists);
  }

  /// Throws `login-required` when signed out and `cannot-follow-self`.
  Future<void> follow(String targetUserId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    if (targetUserId.isEmpty || targetUserId == me) {
      throw Exception('cannot-follow-self');
    }
    await _follows.doc('${me}_$targetUserId').set({
      'followerId': me,
      'followingId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollow(String targetUserId) async {
    final me = currentUserId;
    if (me == null) throw Exception('login-required');
    await _follows.doc('${me}_$targetUserId').delete();
  }

  Future<int> followersCount(String userId) async {
    final agg = await _follows
        .where('followingId', isEqualTo: userId)
        .count()
        .get();
    return agg.count ?? 0;
  }

  Future<int> followingCount(String userId) async {
    final agg = await _follows
        .where('followerId', isEqualTo: userId)
        .count()
        .get();
    return agg.count ?? 0;
  }

  /// Ids of the users who follow [userId], newest first.
  Future<List<String>> followerIds(String userId) => _relatedIds(
    _follows.where('followingId', isEqualTo: userId),
    'followerId',
  );

  /// Ids of the users [userId] follows, newest first.
  Future<List<String>> followingIds(String userId) => _relatedIds(
    _follows.where('followerId', isEqualTo: userId),
    'followingId',
  );

  Future<List<String>> _relatedIds(
    Query<Map<String, dynamic>> query,
    String field,
  ) async {
    final snap = await query.get();
    // Sorted client-side to avoid needing a composite index.
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final at =
            (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt =
            (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
    return docs
        .map((d) => (d.data()[field] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }
}

/// Small in-memory cache of the public bits of a user profile (name, photo,
/// country), so feed cards and follower lists do not re-read the same doc.
class UserDirectory {
  UserDirectory._();

  static final Map<String, Future<UserBrief>> _cache =
      <String, Future<UserBrief>>{};

  static Future<UserBrief> get(String userId) {
    if (userId.isEmpty) return Future<UserBrief>.value(UserBrief.empty(userId));
    return _cache.putIfAbsent(userId, () async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        return UserBrief.fromMap(userId, snap.data());
      } catch (_) {
        // Do not cache failures.
        _cache.remove(userId);
        return UserBrief.empty(userId);
      }
    });
  }

  /// Loads many users at once (Firestore `whereIn` limit is 30 per query).
  static Future<Map<String, UserBrief>> getMany(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.where((e) => e.isNotEmpty).toSet().toList();
    final out = <String, UserBrief>{};
    final missing = <String>[];
    for (final id in ids) {
      final cached = _cache[id];
      if (cached != null) {
        out[id] = await cached;
      } else {
        missing.add(id);
      }
    }
    for (var i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(
        i,
        i + 30 > missing.length ? missing.length : i + 30,
      );
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final brief = UserBrief.fromMap(doc.id, doc.data());
          _cache[doc.id] = Future<UserBrief>.value(brief);
          out[doc.id] = brief;
        }
      } catch (_) {}
    }
    return out;
  }

  /// Drops a cached profile, e.g. after the user changes their photo.
  static void invalidate(String userId) => _cache.remove(userId);
}

class UserBrief {
  const UserBrief({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.country,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final String country;

  factory UserBrief.empty(String uid) =>
      UserBrief(uid: uid, name: '', photoUrl: '', country: '');

  factory UserBrief.fromMap(String uid, Map<String, dynamic>? data) {
    return UserBrief(
      uid: uid,
      name: (data?['displayName'] ?? '').toString().trim(),
      photoUrl: (data?['photoUrl'] ?? '').toString().trim(),
      country: (data?['country'] ?? '').toString().trim(),
    );
  }
}

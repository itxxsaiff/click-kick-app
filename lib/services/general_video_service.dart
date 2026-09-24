import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// A "General Video": a normal video a user posts to their profile, with no
/// competition attached. Stored in `general_videos/{id}` and moderated by
/// admins (`pending` -> `approved` / `rejected`) like competition entries.
class GeneralVideo {
  const GeneralVideo({
    required this.id,
    required this.userId,
    required this.userName,
    required this.videoUrl,
    required this.caption,
    required this.status,
    required this.viewCount,
    required this.shareCount,
    required this.likeCount,
    required this.createdAt,
    this.rejectionReason = '',
  });

  final String id;
  final String userId;
  final String userName;
  final String videoUrl;
  final String caption;
  final String status;
  final int viewCount;
  final int shareCount;
  final int likeCount;
  final DateTime createdAt;
  final String rejectionReason;

  bool get isApproved => status == 'approved';

  factory GeneralVideo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return GeneralVideo(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      caption: (data['caption'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      viewCount: ((data['viewCount'] ?? 0) as num).toInt(),
      shareCount: ((data['shareCount'] ?? 0) as num).toInt(),
      likeCount: ((data['likeCount'] ?? 0) as num).toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      rejectionReason: (data['rejectionReason'] ?? '').toString(),
    );
  }
}

class GeneralVideoService {
  GeneralVideoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String shareBaseUrl =
      'https://video-contest-show-b788b.firebaseapp.com';

  static String shareLink(String videoId) =>
      '$shareBaseUrl/general-video?videoId=$videoId';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get collection =>
      _firestore.collection('general_videos');

  /// Live "does the current user like this video" flag.
  Stream<bool> isLikedStream(String videoId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);
    return collection
        .doc(videoId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Videos of [userId], newest first. The owner sees every status (so they can
  /// follow their pending / rejected uploads); everyone else only sees approved
  /// videos, which is also what the security rules allow.
  Future<List<GeneralVideo>> loadForUser(
    String userId, {
    required bool isOwner,
  }) async {
    Query<Map<String, dynamic>> query = collection.where(
      'userId',
      isEqualTo: userId,
    );
    if (!isOwner) {
      query = query.where('status', isEqualTo: 'approved');
    }
    final snap = await query.get();
    // Sorted client-side to avoid needing a composite index.
    return snap.docs.map(GeneralVideo.fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<GeneralVideo?> loadById(String videoId) async {
    final doc = await collection.doc(videoId).get();
    if (!doc.exists) return null;
    return GeneralVideo.fromDoc(doc);
  }

  /// Deletes the video document and, best-effort, its file in Storage.
  Future<void> delete(GeneralVideo video) async {
    await collection.doc(video.id).delete();
    try {
      await FirebaseStorage.instance.refFromURL(video.videoUrl).delete();
    } catch (_) {}
  }
}

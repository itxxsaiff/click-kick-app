import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Objectionable-content report reasons required by App Store Guideline 1.2.
/// Each entry is an English string key that is also localized in the i18n files.
const List<String> kReportReasons = <String>[
  'Nudity or sexual content',
  'Violence',
  'Hate or harassment',
  'Spam',
  'Fraud or misleading content',
  'Other',
];

class VideoReportService {
  VideoReportService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Submits a content report.
  ///
  /// [reason] is one of [kReportReasons]. [details] is optional free text.
  /// Throws:
  ///  - `login-required` when there is no signed-in user.
  ///  - `duplicate-report` when this user already reported the same video.
  Future<void> submitReport({
    required String reason,
    String? details,
    required String videoType,
    String? contestId,
    String? submissionId,
    String? adminVideoId,
    String? targetUserId,
    String? contestTitle,
    String? participantName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('login-required');
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    final reportedVideoId = submissionId ?? adminVideoId ?? '';

    // Duplicate guard. Users cannot read `video_reports` (staff-only), so we
    // track already-reported video ids on the reporter's own user document.
    if (reportedVideoId.isNotEmpty) {
      final userSnap = await userRef.get();
      final reported =
          (userSnap.data()?['reportedVideoIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};
      if (reported.contains(reportedVideoId)) {
        throw Exception('duplicate-report');
      }
    }

    final now = Timestamp.fromDate(DateTime.now().toUtc());
    final trimmedDetails = (details ?? '').trim();

    await _firestore.collection('video_reports').add({
      'type': 'report',
      'reason': reason.trim(),
      'reasonCategory': reason.trim(),
      'details': trimmedDetails,
      'optionalDetails': trimmedDetails,
      'videoType': videoType,
      'contestId': contestId,
      'submissionId': submissionId,
      'adminVideoId': adminVideoId,
      'reportedVideoId': reportedVideoId.isEmpty ? null : reportedVideoId,
      'targetUserId': targetUserId,
      'reportedParticipantUserId': targetUserId,
      'contestTitle': contestTitle,
      'participantName': participantName,
      'reporterId': user.uid,
      'reporterUserId': user.uid,
      'reporterEmail': user.email ?? '',
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
    });

    if (reportedVideoId.isNotEmpty) {
      await userRef.set({
        'reportedVideoIds': FieldValue.arrayUnion([reportedVideoId]),
        'updatedAt': now,
      }, SetOptions(merge: true));
    }
  }
}

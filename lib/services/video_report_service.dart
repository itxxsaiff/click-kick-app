import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReport({
    required String reason,
    required String videoType,
    String? contestId,
    String? submissionId,
    String? adminVideoId,
    String? targetUserId,
    String? contestTitle,
    String? participantName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('login-required');
    }

    await _firestore.collection('video_reports').add({
      'reason': reason.trim(),
      'videoType': videoType,
      'contestId': contestId,
      'submissionId': submissionId,
      'adminVideoId': adminVideoId,
      'targetUserId': targetUserId,
      'contestTitle': contestTitle,
      'participantName': participantName,
      'reporterId': user.uid,
      'reporterEmail': user.email ?? '',
      'status': 'open',
      'createdAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
    });
  }
}

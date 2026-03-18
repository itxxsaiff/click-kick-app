import 'enums.dart';

class VideoSubmission {
  const VideoSubmission({
    required this.id,
    required this.contestId,
    required this.userId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
    this.allowReupload = false,
    this.voteCount = 0,
    this.viewCount = 0,
  });

  final String id;
  final String contestId;
  final String userId;
  final String videoUrl;
  final String thumbnailUrl;
  final int durationSeconds;
  final VideoStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;
  final bool allowReupload;
  final int voteCount;
  final int viewCount;

  Map<String, dynamic> toMap() => {
        'contestId': contestId,
        'userId': userId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'status': enumToName(status),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'rejectionReason': rejectionReason,
        'allowReupload': allowReupload,
        'voteCount': voteCount,
        'viewCount': viewCount,
      };
}

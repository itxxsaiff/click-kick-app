class Vote {
  const Vote({
    required this.id,
    required this.contestId,
    required this.videoId,
    required this.voterId,
    required this.createdAt,
  });

  final String id;
  final String contestId;
  final String videoId;
  final String voterId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'contestId': contestId,
        'videoId': videoId,
        'voterId': voterId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

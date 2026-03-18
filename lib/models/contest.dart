import 'enums.dart';

class Contest {
  const Contest({
    required this.id,
    required this.title,
    required this.description,
    required this.region,
    required this.submissionStart,
    required this.submissionEnd,
    required this.votingStart,
    required this.votingEnd,
    required this.prizeAmount,
    required this.status,
    this.bannerUrl,
  });

  final String id;
  final String title;
  final String description;
  final String region;
  final DateTime submissionStart;
  final DateTime submissionEnd;
  final DateTime votingStart;
  final DateTime votingEnd;
  final double prizeAmount;
  final ContestStatus status;
  final String? bannerUrl;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'region': region,
        'submissionStart': submissionStart.toUtc().toIso8601String(),
        'submissionEnd': submissionEnd.toUtc().toIso8601String(),
        'votingStart': votingStart.toUtc().toIso8601String(),
        'votingEnd': votingEnd.toUtc().toIso8601String(),
        'prizeAmount': prizeAmount,
        'status': enumToName(status),
        'bannerUrl': bannerUrl,
      };
}

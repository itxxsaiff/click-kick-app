import 'enums.dart';

class SponsorCampaign {
  const SponsorCampaign({
    required this.id,
    required this.sponsorId,
    required this.title,
    required this.region,
    required this.startDate,
    required this.endDate,
    required this.assetUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contestQuestion,
    this.invoiceId,
    this.revisionNotes,
  });

  final String id;
  final String sponsorId;
  final String title;
  final String region;
  final DateTime startDate;
  final DateTime endDate;
  final String assetUrl;
  final SponsorCampaignStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? contestQuestion;
  final String? invoiceId;
  final String? revisionNotes;

  Map<String, dynamic> toMap() => {
        'sponsorId': sponsorId,
        'title': title,
        'region': region,
        'startDate': startDate.toUtc().toIso8601String(),
        'endDate': endDate.toUtc().toIso8601String(),
        'assetUrl': assetUrl,
        'status': enumToName(status),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'contestQuestion': contestQuestion,
        'invoiceId': invoiceId,
        'revisionNotes': revisionNotes,
      };
}

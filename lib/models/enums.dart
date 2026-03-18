enum UserRole { user, participant, sponsor, adminVideo, adminSponsorship, adminFinance, superAdmin }

enum ContestStatus { upcoming, submissionOpen, votingOpen, completed }

enum VideoStatus { pending, approved, rejected }

enum SponsorCampaignStatus { draft, paid, pendingReview, needsRevision, approved, rejected }

String enumToName(Object e) => e.toString().split('.').last;

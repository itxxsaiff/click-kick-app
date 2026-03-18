import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ContestReportParticipantRow {
  const ContestReportParticipantRow({
    required this.participantName,
    required this.status,
    required this.votes,
    required this.shares,
    required this.submittedAtText,
    required this.rejectionReason,
  });

  final String participantName;
  final String status;
  final int votes;
  final int shares;
  final String submittedAtText;
  final String rejectionReason;
}

class ContestWinnerRow {
  const ContestWinnerRow({
    required this.participantName,
    required this.votes,
  });

  final String participantName;
  final int votes;
}

class ContestReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Uint8List> buildContestReportFromFirestore({
    required String contestId,
    required Map<String, dynamic> contestData,
  }) async {
    final submissionsSnap = await _firestore
        .collection('contests')
        .doc(contestId)
        .collection('submissions')
        .get();
    final votesSnap = await _firestore
        .collection('contests')
        .doc(contestId)
        .collection('votes')
        .get();

    final submissions = submissionsSnap.docs;
    final participants = <ContestReportParticipantRow>[];
    final uniqueParticipantIds = <String>{};
    final userNameCache = <String, String>{};
    var approved = 0;
    var rejected = 0;
    var pending = 0;
    var totalVotes = 0;
    var totalShares = 0;
    var maxVotes = -1;
    final votingEnd = _readDate(contestData['votingEnd']);
    final isCompletedByDate =
        votingEnd != null && DateTime.now().isAfter(votingEnd);
    final contestStatus = (contestData['status'] ?? '').toString();
    final shouldShowWinners =
        isCompletedByDate || contestStatus == 'completed' || contestStatus == 'winner_announced';

    for (final doc in submissions) {
      final data = doc.data();
      final userId = (data['userId'] ?? '').toString();
      var name = ((data['userName'] ?? data['participantName']) ?? '')
          .toString()
          .trim();
      if (name.isEmpty && userId.isNotEmpty) {
        if (userNameCache.containsKey(userId)) {
          name = userNameCache[userId]!;
        } else {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          name = (userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? '')
              .toString()
              .trim();
          userNameCache[userId] = name;
        }
      }
      final status = (data['status'] ?? 'pending').toString();
      final votes = ((data['voteCount'] ?? 0) as num).toInt();
      final shares = ((data['shareCount'] ?? 0) as num).toInt();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      if (userId.isNotEmpty) uniqueParticipantIds.add(userId);
      totalVotes += votes;
      totalShares += shares;
      if (votes > maxVotes) maxVotes = votes;
      switch (status) {
        case 'approved':
        case 'winner':
          approved += 1;
          break;
        case 'rejected':
          rejected += 1;
          break;
        default:
          pending += 1;
      }
      participants.add(
        ContestReportParticipantRow(
          participantName: name.isEmpty ? 'Participant' : name,
          status: status,
          votes: votes,
          shares: shares,
          submittedAtText: _fmt(createdAt),
          rejectionReason: (data['rejectionReason'] ?? '').toString(),
        ),
      );
    }

    final winners = <ContestWinnerRow>[];
    if (shouldShowWinners) {
      for (final doc in submissions.where((doc) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        final votes = ((data['voteCount'] ?? 0) as num).toInt();
        return status == 'winner' || (maxVotes >= 0 && votes == maxVotes);
      })) {
        final data = doc.data();
        final userId = (data['userId'] ?? '').toString();
        var name = ((data['userName'] ?? data['participantName']) ?? '')
            .toString()
            .trim();
        if (name.isEmpty && userId.isNotEmpty) {
          if (userNameCache.containsKey(userId)) {
            name = userNameCache[userId]!;
          } else {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            name =
                (userDoc.data()?['displayName'] ?? userDoc.data()?['email'] ?? '')
                    .toString()
                    .trim();
            userNameCache[userId] = name;
          }
        }
        if (name.isEmpty) continue;
        winners.add(
          ContestWinnerRow(
            participantName: name,
            votes: ((data['voteCount'] ?? 0) as num).toInt(),
          ),
        );
      }
    }

    return buildContestReport(
      contestTitle: (contestData['title'] ?? contestId).toString(),
      contestType: (contestData['contestType'] ?? 'video_contest').toString(),
      sponsorName: (contestData['sponsorName'] ?? 'Platform').toString(),
      region: (contestData['region'] ?? '-').toString(),
      status: (contestData['status'] ?? '-').toString(),
      winnerPrize: '\$${(((contestData['winnerPrize'] ?? 0) as num).toDouble()).toStringAsFixed(0)}',
      shouldShowWinners: shouldShowWinners,
      totalParticipants: uniqueParticipantIds.length,
      approvedCount: approved,
      rejectedCount: rejected,
      pendingCount: pending,
      totalVotes: totalVotes,
      totalVoters: votesSnap.docs.length,
      totalShares: totalShares,
      winners: winners,
      participants: participants,
    );
  }

  Future<Uint8List> buildContestReport({
    required String contestTitle,
    required String contestType,
    required String sponsorName,
    required String region,
    required String status,
    required String winnerPrize,
    required bool shouldShowWinners,
    required int totalParticipants,
    required int approvedCount,
    required int rejectedCount,
    required int pendingCount,
    required int totalVotes,
    required int totalVoters,
    required int totalShares,
    required List<ContestWinnerRow> winners,
    required List<ContestReportParticipantRow> participants,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Contest Performance Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          _section(
            'Contest Summary',
            [
              _line('Contest', contestTitle),
              _line('Type', contestType),
              _line('Sponsor', sponsorName),
              _line('Region', region),
              _line('Status', status),
              _line('Winner Prize', winnerPrize),
            ],
          ),
          pw.SizedBox(height: 12),
          _section(
            'Performance',
            [
              _line('Total Participants', totalParticipants.toString()),
              _line('Approved', approvedCount.toString()),
              _line('Rejected', rejectedCount.toString()),
              _line('Pending', pendingCount.toString()),
              _line('Total Votes', totalVotes.toString()),
              _line('Total Voters', totalVoters.toString()),
              _line('Total Shares', totalShares.toString()),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Winners',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (shouldShowWinners)
            ...(winners.isEmpty
                ? [pw.Text('No winner data available yet.')]
                : [
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              headers: const ['Participant', 'Votes'],
              data: winners
                  .map((w) => [w.participantName, w.votes.toString()])
                  .toList(),
            ),
          ])
          else
            pw.Text('Winners will appear after voting is completed.'),
          pw.SizedBox(height: 14),
          pw.Text(
            'Participants Activity',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (participants.isEmpty)
            pw.Text('No participant activity found.')
          else
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Participant',
                'Status',
                'Votes',
                'Shares',
                'Submitted At',
                'Rejection Reason',
              ],
              data: participants
                  .map(
                    (row) => [
                      row.participantName,
                      row.status,
                      row.votes.toString(),
                      row.shares.toString(),
                      row.submittedAtText,
                      row.rejectionReason,
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _line(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(flex: 6, child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.PageTheme _theme() {
    return pw.PageTheme(
      margin: const pw.EdgeInsets.all(24),
      pageFormat: PdfPageFormat.a4,
    );
  }

  String _fmt(DateTime? date) {
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

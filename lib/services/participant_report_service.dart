import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ParticipantSummaryRow {
  const ParticipantSummaryRow({
    required this.name,
    required this.email,
    required this.phone,
    required this.joinedContests,
    required this.approvedCount,
    required this.rejectedCount,
    required this.pendingCount,
  });

  final String name;
  final String email;
  final String phone;
  final int joinedContests;
  final int approvedCount;
  final int rejectedCount;
  final int pendingCount;
}

class ParticipantContestRow {
  const ParticipantContestRow({
    required this.contestName,
    required this.status,
    required this.rejectionReason,
    required this.createdAtText,
  });

  final String contestName;
  final String status;
  final String rejectionReason;
  final String createdAtText;
}

class ParticipantReportService {
  Future<Uint8List> buildAllParticipantsReport({
    required List<ParticipantSummaryRow> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Participants Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Total participants: ${rows.length}'),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Name',
              'Email',
              'Phone',
              'Joined Contests',
              'Approved',
              'Rejected',
              'Pending',
            ],
            data: rows
                .map(
                  (r) => [
                    r.name,
                    r.email,
                    r.phone,
                    r.joinedContests.toString(),
                    r.approvedCount.toString(),
                    r.rejectedCount.toString(),
                    r.pendingCount.toString(),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildSingleParticipantReport({
    required String participantName,
    required String participantEmail,
    required String participantPhone,
    required int joinedContests,
    required int approvedCount,
    required int rejectedCount,
    required int pendingCount,
    required List<ParticipantContestRow> contests,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Participant Detail Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Name: $participantName'),
          pw.Text('Email: $participantEmail'),
          pw.Text('Phone: $participantPhone'),
          pw.SizedBox(height: 8),
          pw.Text('Joined Contests: $joinedContests'),
          pw.Text('Approved Videos: $approvedCount'),
          pw.Text('Rejected Videos: $rejectedCount'),
          pw.Text('Pending Videos: $pendingCount'),
          pw.SizedBox(height: 14),
          if (contests.isEmpty)
            pw.Text('No contest activity found.')
          else
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Contest',
                'Status',
                'Rejection Reason',
                'Created At',
              ],
              data: contests
                  .map(
                    (row) => [
                      row.contestName,
                      row.status,
                      row.rejectionReason,
                      row.createdAtText,
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );
    return doc.save();
  }

  pw.PageTheme _theme() {
    return pw.PageTheme(
      margin: const pw.EdgeInsets.all(24),
      pageFormat: PdfPageFormat.a4,
    );
  }
}

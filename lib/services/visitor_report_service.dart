import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class VisitorSummaryRow {
  const VisitorSummaryRow({
    required this.name,
    required this.email,
    required this.phone,
    required this.totalContestsVoted,
    required this.totalVotes,
  });

  final String name;
  final String email;
  final String phone;
  final int totalContestsVoted;
  final int totalVotes;
}

class VisitorVoteRow {
  const VisitorVoteRow({
    required this.contestName,
    required this.participantName,
    required this.createdAtText,
  });

  final String contestName;
  final String participantName;
  final String createdAtText;
}

class VisitorReportService {
  Future<Uint8List> buildAllVisitorsReport({
    required List<VisitorSummaryRow> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Visitors Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Total visitors: ${rows.length}'),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Name',
              'Email',
              'Phone',
              'Contests Voted',
              'Total Votes',
            ],
            data: rows
                .map(
                  (r) => [
                    r.name,
                    r.email,
                    r.phone,
                    r.totalContestsVoted.toString(),
                    r.totalVotes.toString(),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildSingleVisitorReport({
    required String visitorName,
    required String visitorEmail,
    required String visitorPhone,
    required int totalContestsVoted,
    required int totalVotes,
    required List<VisitorVoteRow> votes,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Visitor Detail Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Name: $visitorName'),
          pw.Text('Email: $visitorEmail'),
          pw.Text('Phone: $visitorPhone'),
          pw.SizedBox(height: 8),
          pw.Text('Contests Voted: $totalContestsVoted'),
          pw.Text('Total Votes: $totalVotes'),
          pw.SizedBox(height: 14),
          if (votes.isEmpty)
            pw.Text('No voting activity found.')
          else
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headers: const [
                'Contest',
                'Participant',
                'Voted At',
              ],
              data: votes
                  .map(
                    (row) => [
                      row.contestName,
                      row.participantName,
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

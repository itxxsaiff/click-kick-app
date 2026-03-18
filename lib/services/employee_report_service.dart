import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class EmployeeSummaryRow {
  const EmployeeSummaryRow({
    required this.name,
    required this.email,
    required this.phone,
    required this.approvedCount,
    required this.rejectedCount,
  });

  final String name;
  final String email;
  final String phone;
  final int approvedCount;
  final int rejectedCount;
}

class EmployeeVideoRow {
  const EmployeeVideoRow({
    required this.contestName,
    required this.participantName,
    required this.status,
    required this.rejectionReason,
    required this.createdAtText,
  });

  final String contestName;
  final String participantName;
  final String status;
  final String rejectionReason;
  final String createdAtText;
}

class EmployeeReportService {
  Future<Uint8List> buildAllEmployeesReport({
    required List<EmployeeSummaryRow> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Employees Moderation Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Total employees: ${rows.length}'),
          pw.SizedBox(height: 14),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            headers: const [
              'Name',
              'Email',
              'Phone',
              'Approved Videos',
              'Rejected Videos',
            ],
            data: rows
                .map(
                  (r) => [
                    r.name,
                    r.email,
                    r.phone,
                    r.approvedCount.toString(),
                    r.rejectedCount.toString(),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> buildSingleEmployeeReport({
    required String employeeName,
    required String employeeEmail,
    required String employeePhone,
    required int approvedCount,
    required int rejectedCount,
    required List<EmployeeVideoRow> videos,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (context) => [
          pw.Text(
            'Employee Moderation Detail Report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Name: $employeeName'),
          pw.Text('Email: $employeeEmail'),
          pw.Text('Phone: $employeePhone'),
          pw.SizedBox(height: 8),
          pw.Text('Approved Videos: $approvedCount'),
          pw.Text('Rejected Videos: $rejectedCount'),
          pw.SizedBox(height: 14),
          if (videos.isEmpty)
            pw.Text('No moderated videos found.')
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
                'Status',
                'Rejection Reason',
                'Created At',
              ],
              data: videos
                  .map(
                    (v) => [
                      v.contestName,
                      v.participantName,
                      v.status,
                      v.rejectionReason,
                      v.createdAtText,
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


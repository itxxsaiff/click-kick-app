import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

class PdfBranding {
  static Future<Uint8List> loadLogoBytes() async {
    final data = await rootBundle.load('assets/images/logo.png');
    return data.buffer.asUint8List();
  }

  static pw.ThemeData? _cachedTheme;

  /// A PDF theme that covers both Latin and Arabic glyphs. The `pdf`
  /// package's built-in default font is Latin-only, so any Arabic text
  /// (contest titles, participant names, ...) silently renders as empty
  /// boxes without this. The reverse is also true: Noto Sans Arabic on its
  /// own does NOT cover plain Latin letters, so it must be added as a
  /// *fallback* alongside a Latin base font rather than replacing it —
  /// otherwise English text breaks instead. Pass this to every
  /// `pw.Document(theme: ...)` used for a report that might contain either.
  static Future<pw.ThemeData> arabicTheme() async {
    final cached = _cachedTheme;
    if (cached != null) return cached;
    final latinRegular = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();
    final arabicRegular = await PdfGoogleFonts.notoSansArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoSansArabicBold();
    final theme = pw.ThemeData.withFont(
      base: latinRegular,
      bold: latinBold,
      fontFallback: [arabicRegular, arabicBold],
    );
    _cachedTheme = theme;
    return theme;
  }

  static pw.Widget brandedHeader({
    required pw.MemoryImage logo,
    required String title,
    String? subtitle,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F3FC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        border: pw.Border.all(
          color: const PdfColor.fromInt(0xFFE6DBF4),
          width: 1,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 58,
            height: 58,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              border: pw.Border.all(
                color: const PdfColor.fromInt(0xFFE6DBF4),
                width: 1,
              ),
            ),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1C1232),
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: const PdfColor.fromInt(0xFF7A2CA0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

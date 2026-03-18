import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.bytes,
    required this.filename,
  });

  final String title;
  final Uint8List bytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('Download'),
            onPressed: () => Printing.sharePdf(bytes: bytes, filename: filename),
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: filename,
      ),
    );
  }
}

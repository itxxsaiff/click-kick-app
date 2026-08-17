import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/video_report_service.dart';
import '../theme/app_colors.dart';

Future<void> showReportVideoDialog({
  required BuildContext context,
  required String videoType,
  String? contestId,
  String? submissionId,
  String? adminVideoId,
  String? targetUserId,
  String? contestTitle,
  String? participantName,
}) async {
  final detailsController = TextEditingController();
  String? selectedReason;
  String? error;
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> submit() async {
            final reason = selectedReason;
            if (reason == null || reason.isEmpty) {
              setState(
                () => error = dialogContext.tr('Please select a reason.'),
              );
              return;
            }
            setState(() {
              submitting = true;
              error = null;
            });
            final loginMsg = dialogContext.tr('Please login to report videos.');
            final dupMsg = dialogContext.tr('You already reported this video.');
            final failMsg = dialogContext.tr('Failed to submit report.');
            final successMsg = dialogContext.tr(
              'Report submitted. Our team will review it within 24 hours.',
            );
            try {
              await VideoReportService().submitReport(
                reason: reason,
                details: detailsController.text.trim(),
                videoType: videoType,
                contestId: contestId,
                submissionId: submissionId,
                adminVideoId: adminVideoId,
                targetUserId: targetUserId,
                contestTitle: contestTitle,
                participantName: participantName,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(successMsg),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              final text = e.toString();
              String message;
              if (text.contains('login-required')) {
                message = loginMsg;
              } else if (text.contains('duplicate-report')) {
                message = dupMsg;
              } else {
                message = failMsg;
              }
              setState(() {
                submitting = false;
                error = message;
              });
            }
          }

          return AlertDialog(
            title: Text(dialogContext.tr('Report Video')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dialogContext.tr('Why are you reporting this video?'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('Reason'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(dialogContext.tr('Select a reason')),
                    items: [
                      for (final reason in kReportReasons)
                        DropdownMenuItem<String>(
                          value: reason,
                          child: Text(dialogContext.tr(reason)),
                        ),
                    ],
                    onChanged: submitting
                        ? null
                        : (value) => setState(() => selectedReason = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    minLines: 2,
                    maxLines: 4,
                    enabled: !submitting,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('Additional details (optional)'),
                      hintText: dialogContext.tr(
                        'Explain why this video should be reviewed.',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.hotPink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                child: Text(dialogContext.tr('Cancel')),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: Text(
                  submitting
                      ? dialogContext.tr('Submitting...')
                      : dialogContext.tr('Submit Report'),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

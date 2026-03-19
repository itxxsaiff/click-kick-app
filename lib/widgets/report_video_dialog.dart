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
  final reasonController = TextEditingController();
  String? error;
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> submit() async {
            final reason = reasonController.text.trim();
            if (reason.isEmpty) {
              setState(() => error = dialogContext.tr('Report reason is required.'));
              return;
            }
            setState(() {
              submitting = true;
              error = null;
            });
            try {
              await VideoReportService().submitReport(
                reason: reason,
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
                    content: Text(dialogContext.tr('Report submitted.')),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              final message = e.toString().contains('login-required')
                  ? dialogContext.tr('Please login to report videos.')
                  : dialogContext.tr('Failed to submit report.');
              setState(() {
                submitting = false;
                error = message;
              });
            }
          }

          return AlertDialog(
            title: Text(dialogContext.tr('Report Video')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: dialogContext.tr('Report reason'),
                    hintText: dialogContext.tr('Explain why this video should be reviewed.'),
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

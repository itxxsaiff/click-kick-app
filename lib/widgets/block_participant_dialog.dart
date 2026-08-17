import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/block_service.dart';
import '../theme/app_colors.dart';

/// Confirms and performs blocking of a contest participant.
/// Returns true when the participant was blocked.
Future<bool> showBlockParticipantDialog({
  required BuildContext context,
  required String blockedUserId,
  String? contestId,
  String? submissionId,
  String? participantName,
  String? contestTitle,
}) async {
  final displayName = (participantName ?? '').trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('Block Participant')),
      content: Text(
        displayName.isEmpty
            ? dialogContext.tr(
                'You will no longer see videos from this participant, and our team will be notified to review their content.',
              )
            : '${dialogContext.tr('Block')} $displayName?\n\n${dialogContext.tr('You will no longer see videos from this participant, and our team will be notified to review their content.')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.hotPink),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.tr('Block')),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  if (!context.mounted) return false;
  final successMsg = context.tr(
    'Participant blocked. Their videos are now hidden.',
  );
  final selfMsg = context.tr('You cannot block yourself.');
  final loginMsg = context.tr('Please login to block users.');
  final failMsg = context.tr('Failed to block. Please try again.');

  try {
    await BlockService().blockParticipant(
      blockedUserId: blockedUserId,
      contestId: contestId,
      submissionId: submissionId,
      participantName: participantName,
      contestTitle: contestTitle,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } catch (e) {
    final text = e.toString();
    String message;
    if (text.contains('cannot-block-self')) {
      message = selfMsg;
    } else if (text.contains('login-required')) {
      message = loginMsg;
    } else {
      message = failMsg;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

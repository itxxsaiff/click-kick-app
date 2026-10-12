import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../screens/chat/inbox_screen.dart';
import '../services/chat_service.dart';
import '../theme/app_colors.dart';

/// Chat bubble icon with an unread-count badge, opening the direct message
/// inbox. Lives on the Profile page (not Home), per the client's request.
class ChatInboxButton extends StatefulWidget {
  const ChatInboxButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  State<ChatInboxButton> createState() => _ChatInboxButtonState();
}

class _ChatInboxButtonState extends State<ChatInboxButton> {
  // Created once so a parent rebuild doesn't keep re-subscribing this
  // listener (see the matching notification-bell comment elsewhere).
  late final Stream<int> _unreadStream = ChatService().totalUnreadStream();

  void _open(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Please login to send a message.'))),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InboxScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: context.tr('Messages'),
          onPressed: () => _open(context),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.chat_bubble_rounded, color: widget.color),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.hotPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

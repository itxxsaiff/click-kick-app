import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/short_link_service.dart';
import '../profile/general_video_player_screen.dart';
import '../profile/user_profile_screen.dart';
import '../public/public_feed_screen.dart';

/// Opened from a short share link (`/s/{code}`): looks up what the code
/// points to and shows the matching screen.
class ShortLinkScreen extends StatelessWidget {
  const ShortLinkScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String type, Map<String, String> params})?>(
      future: ShortLinkService().resolve(code).catchError((_) => null),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data;
        if (result == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.tr('This link is not available.'))),
          );
        }
        final params = result.params;
        switch (result.type) {
          case 'contest_share':
            final contestId = params['contestId'] ?? '';
            if (contestId.isEmpty) break;
            return PublicFeedScreen(
              initialTabIndex: 1,
              sharedContestId: contestId,
            );
          case 'general_video':
            final videoId = params['videoId'] ?? '';
            if (videoId.isEmpty) break;
            return GeneralVideoLinkScreen(videoId: videoId);
          case 'feed_video':
            final videoId = params['videoId'] ?? '';
            if (videoId.isEmpty) break;
            return PublicFeedScreen(
              initialTabIndex: 0,
              sharedAdminVideoId: videoId,
            );
          case 'profile':
            final userId = params['userId'] ?? '';
            if (userId.isEmpty) break;
            return UserProfileScreen(userId: userId);
        }
        return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(context.tr('This link is not available.'))),
        );
      },
    );
  }
}

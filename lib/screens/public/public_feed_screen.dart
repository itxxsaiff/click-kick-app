import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/report_video_dialog.dart';
import '../../widgets/settings_action_tile.dart';
import '../../widgets/password_change_layout.dart';
import '../../main.dart';
import '../shared/legal_center_screen.dart';
import '../shared/support_chat_screen.dart';
import '../user/contest_detail_screen.dart';
import '../auth/login_screen.dart';

class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({super.key});

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  int _tabIndex = 0;

  String _headerTitle(
    BuildContext context,
    List<String> labels,
    int safeIndex,
  ) {
    return context.tr(labels[safeIndex]);
  }

  Future<_PublicNavConfig> _loadNavConfig(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 8));
      final role = (userDoc.data()?['role'] ?? 'user').toString().toLowerCase();
      final isParticipant = role == 'participant';
      if (!isParticipant) {
        return const _PublicNavConfig(isParticipant: false, hasUploads: false);
      }

      try {
        final uploadSnap = await FirebaseFirestore.instance
            .collectionGroup('submissions')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        return _PublicNavConfig(
          isParticipant: true,
          hasUploads: uploadSnap.docs.isNotEmpty,
        );
      } catch (_) {
        return const _PublicNavConfig(isParticipant: true, hasUploads: false);
      }
    } catch (_) {
      return const _PublicNavConfig(isParticipant: false, hasUploads: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final isLoggedIn = authSnapshot.data != null;
        if (!isLoggedIn) {
          return _buildShell(
            context: context,
            labels: const <String>['Home', 'Contests', 'Sign'],
            icons: const <IconData>[
              Icons.home_outlined,
              Icons.local_fire_department_outlined,
              Icons.person_outline,
            ],
            activeIcons: const <IconData>[
              Icons.home,
              Icons.local_fire_department,
              Icons.person,
            ],
            pages: <Widget>[
              _HomeFeedTab(isVisible: _tabIndex == 0),
              _PublicContestsTab(isVisible: _tabIndex == 1),
              const _LoginRequiredCard(),
            ],
          );
        }

        final userId = authSnapshot.data!.uid;
        return FutureBuilder<_PublicNavConfig>(
          future: _loadNavConfig(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Scaffold(
                body: Stack(
                  children: [
                    _SpaceBackground(),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }

            final nav =
                snapshot.data ??
                const _PublicNavConfig(isParticipant: false, hasUploads: false);
            final labels = nav.isParticipant
                ? (nav.hasUploads
                      ? const <String>[
                          'Dashboard',
                          'Contests',
                          'Prizes',
                          'Dashboard',
                          'Profile',
                        ]
                      : const <String>[
                          'Dashboard',
                          'Contests',
                          'Dashboard',
                          'Profile',
                        ])
                : const <String>['Dashboard', 'Contests', 'Profile'];

            final icons = nav.isParticipant
                ? (nav.hasUploads
                      ? const <IconData>[
                          Icons.dashboard_outlined,
                          Icons.local_fire_department_outlined,
                          Icons.card_giftcard_outlined,
                          Icons.dashboard_outlined,
                          Icons.person_outline,
                        ]
                      : const <IconData>[
                          Icons.dashboard_outlined,
                          Icons.local_fire_department_outlined,
                          Icons.dashboard_outlined,
                          Icons.person_outline,
                        ])
                : const <IconData>[
                    Icons.dashboard_outlined,
                    Icons.local_fire_department_outlined,
                    Icons.person_outline,
                  ];

            final activeIcons = nav.isParticipant
                ? (nav.hasUploads
                      ? const <IconData>[
                          Icons.dashboard_customize,
                          Icons.local_fire_department,
                          Icons.card_giftcard,
                          Icons.dashboard_customize,
                          Icons.person,
                        ]
                      : const <IconData>[
                          Icons.dashboard_customize,
                          Icons.local_fire_department,
                          Icons.dashboard_customize,
                          Icons.person,
                        ])
                : const <IconData>[
                    Icons.dashboard_customize,
                    Icons.local_fire_department,
                    Icons.person,
                  ];

            final pages = nav.isParticipant
                ? (nav.hasUploads
                      ? <Widget>[
                          _HomeFeedTab(isVisible: _tabIndex == 0),
                          _PublicContestsTab(isVisible: _tabIndex == 1),
                          const _WinnersFeedTab(),
                          const _DashboardGateTab(),
                          const _ProfileGateTab(),
                        ]
                      : <Widget>[
                          _HomeFeedTab(isVisible: _tabIndex == 0),
                          _PublicContestsTab(isVisible: _tabIndex == 1),
                          const _DashboardGateTab(),
                          const _ProfileGateTab(),
                        ])
                : <Widget>[
                    _HomeFeedTab(isVisible: _tabIndex == 0),
                    _PublicContestsTab(isVisible: _tabIndex == 1),
                    const _ProfileGateTab(),
                  ];

            return _buildShell(
              context: context,
              labels: labels,
              icons: icons,
              activeIcons: activeIcons,
              pages: pages,
            );
          },
        );
      },
    );
  }

  Widget _buildShell({
    required BuildContext context,
    required List<String> labels,
    required List<IconData> icons,
    required List<IconData> activeIcons,
    required List<Widget> pages,
  }) {
    final safeIndex = _tabIndex.clamp(0, labels.length - 1);
    final isImmersiveFeed = safeIndex == 0 || labels[safeIndex] == 'Contests';
    if (_tabIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = safeIndex);
      });
    }

    final bodyContent = Column(
      children: [
        if (!isImmersiveFeed)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(activeIcons[safeIndex], color: AppColors.hotPink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _headerTitle(context, labels, safeIndex),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: IndexedStack(index: safeIndex, children: pages),
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          if (isImmersiveFeed) bodyContent else SafeArea(child: bodyContent),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x221B1033), Color(0xCC130B25)],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A1847), Color(0xFF1C1232)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border.withOpacity(0.9)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BottomNavigationBar(
              currentIndex: safeIndex,
              onTap: (v) => setState(() => _tabIndex = v),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.hotPink,
              unselectedItemColor: AppColors.textMuted.withOpacity(0.95),
              selectedFontSize: 13,
              unselectedFontSize: 12,
              items: List.generate(labels.length, (i) {
                return BottomNavigationBarItem(
                  icon: Icon(icons[i]),
                  activeIcon: Icon(activeIcons[i]),
                  label: context.tr(labels[i]),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicNavConfig {
  const _PublicNavConfig({
    required this.isParticipant,
    required this.hasUploads,
  });

  final bool isParticipant;
  final bool hasUploads;
}

class _HomeFeedTab extends StatefulWidget {
  const _HomeFeedTab({required this.isVisible});

  final bool isVisible;

  @override
  State<_HomeFeedTab> createState() => _HomeFeedTabState();
}

class _HomeFeedTabState extends State<_HomeFeedTab> with RouteAware {
  final _pageController = PageController();
  int _activeIndex = 0;
  VideoPlayerController? _videoController;
  String _currentVideoUrl = '';
  String? _pendingVideoUrl;
  bool _pendingAutoplay = false;
  bool _isVideoLoading = false;
  int _videoRequestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant _HomeFeedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _clearActiveVideo();
  }

  @override
  void didPopNext() {
    _handleVisibilityChange();
  }

  Future<void> _handleVisibilityChange() async {
    if (!widget.isVisible) {
      await _clearActiveVideo();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActiveVideo(String url, {bool autoplay = true}) async {
    if (url.isEmpty) return;
    final requestId = ++_videoRequestId;
    if (mounted) {
      setState(() => _isVideoLoading = true);
    }
    if (url == _currentVideoUrl && _videoController != null) {
      final controller = _videoController!;
      await controller.setVolume(1);
      if (autoplay) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (mounted && requestId == _videoRequestId) {
        setState(() => _isVideoLoading = false);
      }
      return;
    }

    final previous = _videoController;
    _videoController = null;
    _currentVideoUrl = url;
    await previous?.pause();
    await previous?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      controller.addListener(() {
        if (!mounted ||
            _currentVideoUrl != url ||
            controller != _videoController) {
          return;
        }
        setState(() {});
      });
      if (requestId != _videoRequestId || !mounted) {
        await controller.pause();
        await controller.dispose();
        return;
      }
      if (autoplay) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _isVideoLoading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _videoController = controller;
      _isVideoLoading = false;
    });
  }

  Future<void> _clearActiveVideo() async {
    if (_currentVideoUrl.isEmpty && _videoController == null) return;
    _videoRequestId++;
    _currentVideoUrl = '';
    final controller = _videoController;
    _videoController = null;
    await controller?.pause();
    await controller?.dispose();
    if (mounted) {
      setState(() => _isVideoLoading = false);
    }
  }

  void _scheduleActiveVideoSync(_FeedItem item, {required bool autoplay}) {
    final desiredUrl = item.hasVideo && item.videoUrl.isNotEmpty
        ? item.videoUrl
        : '';
    if (_pendingVideoUrl == desiredUrl && _pendingAutoplay == autoplay) return;
    _pendingVideoUrl = desiredUrl;
    _pendingAutoplay = autoplay;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final url = _pendingVideoUrl ?? '';
      final shouldAutoplay = _pendingAutoplay;
      _pendingVideoUrl = null;
      if (url.isEmpty) {
        await _clearActiveVideo();
        return;
      }
      if (url == _currentVideoUrl) return;
      await _setActiveVideo(url, autoplay: shouldAutoplay);
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, newsSnapshot) {
        if (newsSnapshot.hasError) {
          return Center(
            child: Text(
              context.tr('Unable to load news.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        if (!newsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('admin_videos')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, adminVideosSnapshot) {
            if (adminVideosSnapshot.hasError) {
              return Center(
                child: Text(
                  context.tr('Unable to load feed videos.'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            if (!adminVideosSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final newsDocs = newsSnapshot.data!.docs;
            final adminVideoDocs = adminVideosSnapshot.data!.docs;
            final feedItems = _buildFeedItems(newsDocs, adminVideoDocs);

            if (feedItems.isEmpty) {
              return Center(
                child: Text(
                  context.tr('No updates available right now.'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              );
            }

            final safeIndex = _activeIndex.clamp(0, feedItems.length - 1);
            final activeItem = feedItems[safeIndex];
            if (widget.isVisible) {
              _scheduleActiveVideoSync(activeItem, autoplay: true);
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              itemCount: feedItems.length,
              onPageChanged: (i) async {
                setState(() => _activeIndex = i);
                if (!widget.isVisible) return;
                final item = feedItems[i];
                if (item.hasVideo && item.videoUrl.isNotEmpty) {
                  await _setActiveVideo(item.videoUrl, autoplay: true);
                } else {
                  await _clearActiveVideo();
                }
              },
              itemBuilder: (context, index) {
                final item = feedItems[index];
                if (item.isNews) {
                  return _NewsFeedCard(item: item);
                }
                final isActive = index == safeIndex;
                final isShowingActiveVideo =
                    isActive &&
                    _videoController != null &&
                    _videoController!.value.isInitialized &&
                    _currentVideoUrl == item.videoUrl;
                final shouldShowLoading =
                    isActive &&
                    item.hasVideo &&
                    (_isVideoLoading || !isShowingActiveVideo);
                final isPlaying =
                    isShowingActiveVideo && _videoController!.value.isPlaying;
                return _AdminVideoFeedCard(
                  item: item,
                  isShowingActiveVideo: isShowingActiveVideo,
                  isPlaying: isPlaying,
                  isLoading: shouldShowLoading,
                  controller: isShowingActiveVideo ? _videoController : null,
                  onTapVideo: isShowingActiveVideo ? _togglePlayback : null,
                );
              },
            );
          },
        );
      },
    );
  }

  List<_FeedItem> _buildFeedItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> newsDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> adminVideoDocs,
  ) {
    final items = <_FeedItem>[
      ...newsDocs.map(_FeedItem.fromNews),
      ...adminVideoDocs.map(_FeedItem.fromAdminVideo),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

class _PublicContestsTab extends StatefulWidget {
  const _PublicContestsTab({required this.isVisible});

  final bool isVisible;

  @override
  State<_PublicContestsTab> createState() => _PublicContestsTabState();
}

class _PublicContestsTabState extends State<_PublicContestsTab>
    with RouteAware {
  final _pageController = PageController();
  int _activeIndex = 0;
  VideoPlayerController? _videoController;
  String _currentVideoUrl = '';
  String? _pendingVideoUrl;
  bool _isVideoLoading = false;
  int _videoRequestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant _PublicContestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _handleVisibilityChange();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _clearActiveVideo();
  }

  @override
  void didPopNext() {
    _handleVisibilityChange();
  }

  Future<void> _handleVisibilityChange() async {
    if (!widget.isVisible) {
      await _clearActiveVideo();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActiveVideo(String url) async {
    if (url.isEmpty) return;
    final requestId = ++_videoRequestId;
    if (mounted) {
      setState(() => _isVideoLoading = true);
    }
    if (url == _currentVideoUrl && _videoController != null) {
      final controller = _videoController!;
      await controller.setVolume(1);
      await controller.play();
      if (mounted && requestId == _videoRequestId) {
        setState(() => _isVideoLoading = false);
      }
      return;
    }

    final previous = _videoController;
    _videoController = null;
    _currentVideoUrl = url;
    await previous?.pause();
    await previous?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      controller.addListener(() {
        if (!mounted ||
            _currentVideoUrl != url ||
            controller != _videoController) {
          return;
        }
        setState(() {});
      });
      if (requestId != _videoRequestId || !mounted) {
        await controller.pause();
        await controller.dispose();
        return;
      }
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _isVideoLoading = false);
      return;
    }
    if (!mounted) return;
    setState(() {
      _videoController = controller;
      _isVideoLoading = false;
    });
  }

  Future<void> _clearActiveVideo() async {
    _videoRequestId++;
    _currentVideoUrl = '';
    final controller = _videoController;
    _videoController = null;
    await controller?.pause();
    await controller?.dispose();
    if (mounted) {
      setState(() => _isVideoLoading = false);
    }
  }

  void _scheduleActiveVideoSync(_ContestFeedItem item) {
    final desiredUrl = item.videoUrl;
    if (_pendingVideoUrl == desiredUrl) return;
    _pendingVideoUrl = desiredUrl;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final url = _pendingVideoUrl ?? '';
      _pendingVideoUrl = null;
      if (url.isEmpty) {
        await _clearActiveVideo();
        return;
      }
      if (url == _currentVideoUrl) return;
      await _setActiveVideo(url);
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final contestType = (data['contestType'] ?? 'video_contest')
              .toString();
          final status = (data['status'] ?? '').toString();
          final videoUrl = (data['contestVideoUrl'] ?? '').toString();
          if (videoUrl.isEmpty) return false;
          if (contestType == 'sponsor_contest') {
            return status == 'live';
          }
          return true;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              context.tr('No contests available right now.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final items = docs.map(_ContestFeedItem.fromDoc).toList();
        final safeIndex = _activeIndex.clamp(0, items.length - 1);
        final activeItem = items[safeIndex];
        if (widget.isVisible) {
          _scheduleActiveVideoSync(activeItem);
        }

        return PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: items.length,
          onPageChanged: (index) async {
            setState(() => _activeIndex = index);
            if (!widget.isVisible) return;
            await _setActiveVideo(items[index].videoUrl);
          },
          itemBuilder: (context, index) {
            final item = items[index];
            final isActive = index == safeIndex;
            final isShowingActiveVideo =
                isActive &&
                _videoController != null &&
                _videoController!.value.isInitialized &&
                _currentVideoUrl == item.videoUrl;
            final shouldShowLoading =
                isActive && (_isVideoLoading || !isShowingActiveVideo);
            final isPlaying =
                isShowingActiveVideo && _videoController!.value.isPlaying;
            return _ContestFeedCard(
              item: item,
              controller: isShowingActiveVideo ? _videoController : null,
              isShowingActiveVideo: isShowingActiveVideo,
              isPlaying: isPlaying,
              isLoading: shouldShowLoading,
              onTapVideo: isShowingActiveVideo ? _togglePlayback : null,
            );
          },
        );
      },
    );
  }
}

class _ContestFeedItem {
  const _ContestFeedItem({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.logoUrl,
    required this.contestType,
    required this.sponsorId,
    required this.winnerPrize,
    required this.data,
  });

  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String logoUrl;
  final String contestType;
  final String sponsorId;
  final double winnerPrize;
  final Map<String, dynamic> data;

  factory _ContestFeedItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _ContestFeedItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      videoUrl: (data['contestVideoUrl'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? '').toString(),
      contestType: (data['contestType'] ?? 'video_contest').toString(),
      sponsorId: (data['sponsorId'] ?? '').toString(),
      winnerPrize: ((data['winnerPrize'] ?? 100) as num).toDouble(),
      data: Map<String, dynamic>.from(data),
    );
  }
}

class _ContestFeedCard extends StatelessWidget {
  const _ContestFeedCard({
    required this.item,
    required this.controller,
    required this.isShowingActiveVideo,
    required this.isPlaying,
    required this.isLoading,
    this.onTapVideo,
  });

  final _ContestFeedItem item;
  final VideoPlayerController? controller;
  final bool isShowingActiveVideo;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTapVideo;

  Future<void> _requireAuth(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
  }

  void _openContest(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _requireAuth(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ContestDetailScreen(contestId: item.id, data: item.data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapVideo,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isShowingActiveVideo && controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            )
          else if (isShowingActiveVideo && isLoading)
            Container(
              color: AppColors.card,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.hotPink,
                  strokeWidth: 4.6,
                ),
              ),
            )
          else
            Container(
              color: AppColors.card,
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.hotPink,
                  size: 72,
                ),
              ),
            ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.hotPink,
                strokeWidth: 4.6,
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD0100A1E)],
                stops: [0.42, 1],
              ),
            ),
          ),
          if (isShowingActiveVideo)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (isPlaying || isLoading) ? 0 : 1,
                child: Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.hotPink,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 128,
            child: _FeedActionRail(
              children: [
                _FeedActionButton(
                  icon: Icons.share_rounded,
                  label: context.tr('Share'),
                  onTap: () async {
                    if (FirebaseAuth.instance.currentUser == null) {
                      await _requireAuth(context);
                      return;
                    }
                    final text =
                        '${item.title}\n${item.description}\n${context.tr('Winner Prize')}: \$${item.winnerPrize.toStringAsFixed(0)}';
                    await Share.share(text, subject: item.title);
                  },
                ),
                _FeedActionButton(
                  icon: Icons.flag_outlined,
                  label: context.tr('Report'),
                  onTap: () => showReportVideoDialog(
                    context: context,
                    videoType: 'contest_video',
                    contestId: item.id,
                    targetUserId: item.sponsorId,
                    contestTitle: item.title,
                  ),
                ),
                _FeedInfoBadge(
                  icon: Icons.card_giftcard_rounded,
                  title: '\$${item.winnerPrize.toStringAsFixed(0)}',
                  subtitle: context.tr('gift'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 86,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.logoUrl.isNotEmpty
                          ? Image.network(
                              item.logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.emoji_events,
                                color: AppColors.hotPink,
                              ),
                            )
                          : const Icon(
                              Icons.emoji_events,
                              color: AppColors.hotPink,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _openContest(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.hotPink,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.hotPink.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr('Join Contest'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  const _FeedItem({
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.imageUrl = '',
    this.videoUrl = '',
    this.adminName = '',
    this.adminVideoId = '',
  });

  final String type;
  final String title;
  final String description;
  final DateTime createdAt;
  final String imageUrl;
  final String videoUrl;
  final String adminName;
  final String adminVideoId;

  bool get isNews => type == 'news';
  bool get isAdminVideo => type == 'admin_video';
  bool get hasVideo => isAdminVideo;

  factory _FeedItem.fromNews(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _FeedItem(
      type: 'news',
      title: (data['title'] ?? '').toString(),
      description: ((data['details'] ?? data['body']) ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      imageUrl: (data['imageUrl'] ?? '').toString(),
    );
  }

  factory _FeedItem.fromAdminVideo(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _FeedItem(
      type: 'admin_video',
      title: (data['adminName'] ?? 'Admin').toString(),
      description: (data['caption'] ?? '').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      videoUrl: (data['videoUrl'] ?? '').toString(),
      adminName: (data['adminName'] ?? 'Admin').toString(),
      adminVideoId: doc.id,
    );
  }
}

class _NewsFeedCard extends StatefulWidget {
  const _NewsFeedCard({required this.item});

  final _FeedItem item;

  @override
  State<_NewsFeedCard> createState() => _NewsFeedCardState();
}

class _AdminVideoFeedCard extends StatelessWidget {
  const _AdminVideoFeedCard({
    required this.item,
    required this.isShowingActiveVideo,
    required this.isPlaying,
    required this.isLoading,
    required this.controller,
    this.onTapVideo,
  });

  final _FeedItem item;
  final bool isShowingActiveVideo;
  final bool isPlaying;
  final bool isLoading;
  final VideoPlayerController? controller;
  final VoidCallback? onTapVideo;

  Future<void> _requireAuth(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapVideo,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isShowingActiveVideo && controller != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.size.width,
                height: controller!.value.size.height,
                child: VideoPlayer(controller!),
              ),
            )
          else if (isShowingActiveVideo && isLoading)
            Container(
              color: AppColors.card,
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.hotPink,
                  strokeWidth: 4.6,
                ),
              ),
            )
          else
            Container(
              color: AppColors.card,
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.hotPink,
                  size: 72,
                ),
              ),
            ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.hotPink,
                strokeWidth: 4.6,
              ),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD0100A1E)],
                stops: [0.42, 1],
              ),
            ),
          ),
          if (isShowingActiveVideo)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (isPlaying || isLoading) ? 0 : 1,
                child: Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.hotPink,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 14,
            bottom: 132,
            child: _FeedActionRail(
              children: [
                _FeedActionButton(
                  icon: Icons.share_rounded,
                  label: context.tr('Share'),
                  onTap: () async {
                    if (FirebaseAuth.instance.currentUser == null) {
                      await _requireAuth(context);
                      return;
                    }
                    final text =
                        '${item.adminName}\n${item.description}\n${item.videoUrl}';
                    await Share.share(text, subject: item.adminName);
                  },
                ),
                _FeedActionButton(
                  icon: Icons.flag_outlined,
                  label: context.tr('Report'),
                  onTap: () => showReportVideoDialog(
                    context: context,
                    videoType: 'admin_video',
                    adminVideoId: item.adminVideoId,
                    contestTitle: item.adminName,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 82,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedActionRail extends StatelessWidget {
  const _FeedActionRail({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 58,
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedInfoBadge extends StatelessWidget {
  const _FeedInfoBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 58,
          child: Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 58,
          child: Text(
            subtitle,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsFeedCardState extends State<_NewsFeedCard> {
  bool _expanded = false;

  Future<void> _requireAuth(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Sign Up / Login first')),
        content: Text(context.tr('Please sign up or login first to continue.')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/register');
            },
            child: Text(context.tr('Sign Up')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/login');
            },
            child: Text(context.tr('Login')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          color: AppColors.card,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF0E0818)),
              Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.22),
                    child: item.imageUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.newspaper_rounded,
                              color: AppColors.hotPink,
                              size: 70,
                            ),
                          )
                        : Image.network(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppColors.textMuted,
                                size: 52,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xD0100A1E)],
                    stops: [0.48, 1],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 138,
                child: _FeedActionRail(
                  children: [
                    _FeedActionButton(
                      icon: Icons.share_rounded,
                      label: context.tr('Share'),
                      onTap: () async {
                        if (FirebaseAuth.instance.currentUser == null) {
                          await _requireAuth(context);
                          return;
                        }
                        final text = '${item.title}\n${item.description}';
                        await Share.share(text, subject: item.title);
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 84,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hotPink.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.hotPink.withOpacity(0.45),
                        ),
                      ),
                      child: Text(
                        context.tr('News Update'),
                        style: const TextStyle(
                          color: AppColors.hotPink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.cardSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.newspaper_rounded,
                            color: AppColors.hotPink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    if (item.description.trim().length > 120) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Text(
                          context.tr(_expanded ? 'Read less' : 'Read more'),
                          style: const TextStyle(
                            color: AppColors.hotPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardGateTab extends StatelessWidget {
  const _DashboardGateTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _LoginRequiredCard();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final role = (snapshot.data!.data()?['role'] ?? 'user').toString();
        if (role == 'user' || role == 'participant') {
          return _ParticipantDashboardTab(userId: user.uid);
        }
        return Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.dashboard_customize,
                  size: 44,
                  color: AppColors.hotPink,
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr('Open your role dashboard.'),
                  style: const TextStyle(color: AppColors.textLight),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/home'),
                  child: Text(context.tr('Open Dashboard')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ParticipantDashboardTab extends StatefulWidget {
  const _ParticipantDashboardTab({required this.userId});

  final String userId;

  @override
  State<_ParticipantDashboardTab> createState() =>
      _ParticipantDashboardTabState();
}

class _ParticipantDashboardTabState extends State<_ParticipantDashboardTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final firestore = FirebaseFirestore.instance;
    try {
      final snap = await firestore
          .collectionGroup('submissions')
          .where('userId', isEqualTo: widget.userId)
          .get()
          .timeout(const Duration(seconds: 15));

      final docs = snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['_docId'] = doc.id;
        data['contestId'] =
            (data['contestId'] ?? doc.reference.parent.parent?.id ?? '')
                .toString();
        data['isWinner'] = false;
        return data;
      }).toList();
      return _markOwnWinners(docs, firestore);
    } catch (_) {
      final contests = await firestore
          .collection('contests')
          .get()
          .timeout(const Duration(seconds: 15));
      final out = <Map<String, dynamic>>[];
      for (final contest in contests.docs) {
        final subSnap = await contest.reference
            .collection('submissions')
            .where('userId', isEqualTo: widget.userId)
            .get()
            .timeout(const Duration(seconds: 15));
        for (final sub in subSnap.docs) {
          final data = Map<String, dynamic>.from(sub.data());
          data['contestId'] = contest.id;
          data['contestName'] = (contest.data()['title'] ?? '').toString();
          data['_docId'] = sub.id;
          data['isWinner'] = false;
          out.add(data);
        }
      }
      return _markOwnWinners(out, firestore);
    }
  }

  Future<List<Map<String, dynamic>>> _markOwnWinners(
    List<Map<String, dynamic>> docs,
    FirebaseFirestore firestore,
  ) async {
    if (docs.isEmpty) return docs;
    final now = DateTime.now();
    final contestIds = docs
        .map((d) => (d['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final contestId in contestIds) {
      final contestDoc = await firestore
          .collection('contests')
          .doc(contestId)
          .get();
      if (!contestDoc.exists) continue;
      final votingEnd = (contestDoc.data()?['votingEnd'] as Timestamp?)
          ?.toDate();
      if (votingEnd == null || now.isBefore(votingEnd)) continue;

      final submissionsSnap = await contestDoc.reference
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get()
          .timeout(const Duration(seconds: 15));
      if (submissionsSnap.docs.isEmpty) continue;

      var maxVotes = 0;
      for (final sub in submissionsSnap.docs) {
        final votes = ((sub.data()['voteCount'] ?? 0) as num).toInt();
        if (votes > maxVotes) maxVotes = votes;
      }
      final winnerIds = submissionsSnap.docs
          .where(
            (sub) =>
                ((sub.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
          )
          .map((sub) => sub.id)
          .toSet();

      for (final doc in docs) {
        if ((doc['contestId'] ?? '').toString() != contestId) continue;
        if ((doc['status'] ?? '').toString() != 'approved') continue;
        final docId = (doc['_docId'] ?? '').toString();
        if (winnerIds.contains(docId)) {
          doc['isWinner'] = true;
        }
      }
    }
    return docs;
  }

  Future<void> _refresh() async {
    setState(() {
      _errorMessage = null;
      _future = _load();
    });
    try {
      await _future;
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Dashboard request timed out. Check internet and retry.',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('Unable to load dashboard data. Tap retry.');
      });
    }
  }

  String _t(BuildContext context, String key, String arFallback) {
    final value = context.tr(key);
    if (context.isArabic &&
        (value == key || RegExp(r'^[A-Za-z]').hasMatch(value))) {
      return arFallback;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return Center(child: Text(context.tr('Please login.')));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            _errorMessage == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_errorMessage != null || snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 36,
                    color: AppColors.hotPink,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ??
                        context.tr('Unable to load dashboard data. Tap retry.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: Text(context.tr('Retry')),
                  ),
                ],
              ),
            ),
          );
        }

        final docs =
            List<Map<String, dynamic>>.from(
              snapshot.data ?? <Map<String, dynamic>>[],
            )..sort((a, b) {
              final at =
                  (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bt =
                  (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });
        final approved = docs
            .where((e) => (e['status'] ?? '') == 'approved')
            .length;
        final winners = docs.where((e) => e['isWinner'] == true).length;
        final authUser = FirebaseAuth.instance.currentUser;
        final fallbackName = docs.isNotEmpty
            ? ((docs.first['userName'] ??
                          docs.first['participantName'] ??
                          docs.first['displayName']) ??
                      '')
                  .toString()
            : '';
        final profileName = (authUser?.displayName?.trim().isNotEmpty ?? false)
            ? authUser!.displayName!.trim()
            : (fallbackName.isNotEmpty
                  ? fallbackName
                  : context.tr('Participant'));
        final profileEmail = (authUser?.email ?? '').trim();
        final profilePhotoUrl = (authUser?.photoURL ?? '').trim();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardSoft,
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profilePhotoUrl.isNotEmpty
                              ? Image.network(
                                  profilePhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.hotPink,
                                    size: 38,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.hotPink,
                                  size: 38,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profileName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (profileEmail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            profileEmail,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _ProfileStatBlock(
                                value: docs.length.toString(),
                                label: _t(
                                  context,
                                  'Total Videos',
                                  'إجمالي الفيديوهات',
                                ),
                              ),
                            ),
                            Expanded(
                              child: _ProfileStatBlock(
                                value: approved.toString(),
                                label: _t(context, 'Approved', 'مقبول'),
                              ),
                            ),
                            Expanded(
                              child: _ProfileStatBlock(
                                value: winners.toString(),
                                label: _t(context, 'Winner', 'الفائز'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (docs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr('No videos found for selected filter.'),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = docs[index];
                      final status = (data['isWinner'] == true)
                          ? 'winner'
                          : (data['status'] ?? 'pending').toString();
                      final videoUrl = (data['videoUrl'] ?? '').toString();
                      final contestName =
                          (data['contestName'] ??
                                  data['contestTitle'] ??
                                  data['contestId'] ??
                                  '')
                              .toString();
                      final votes = ((data['voteCount'] ?? 0) as num).toInt();
                      final reason = (data['rejectionReason'] ?? '').toString();

                      Color badge = AppColors.sunset;
                      String badgeLabel = _t(
                        context,
                        'Pending',
                        'قيد الانتظار',
                      );
                      if (status == 'approved') {
                        badge = const Color(0xFF2DAF6F);
                        badgeLabel = _t(context, 'Approved', 'مقبول');
                      } else if (status == 'rejected') {
                        badge = const Color(0xFFC53D5D);
                        badgeLabel = _t(context, 'Rejected', 'مرفوض');
                      } else if (status == 'winner') {
                        badge = AppColors.hotPink;
                        badgeLabel = _t(context, 'Winner', 'الفائز');
                      }

                      return GestureDetector(
                        onTap: videoUrl.isEmpty
                            ? null
                            : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _DashboardVideoPlayerScreen(
                                      videoUrl: videoUrl,
                                      title: contestName,
                                    ),
                                  ),
                                );
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.cardSoft,
                                        AppColors.card,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: AppColors.hotPink,
                                      size: 38,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badge.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: badge,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 10,
                                right: 10,
                                bottom: 10,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contestName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.how_to_vote_rounded,
                                          color: AppColors.hotPink,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${_t(context, 'Votes', 'الأصوات')}: $votes',
                                            style: const TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (status == 'rejected' &&
                                        reason.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        reason,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: docs.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
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

class _ProfileStatBlock extends StatelessWidget {
  const _ProfileStatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashboardVideoPlayerScreen extends StatefulWidget {
  const _DashboardVideoPlayerScreen({
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;

  @override
  State<_DashboardVideoPlayerScreen> createState() =>
      _DashboardVideoPlayerScreenState();
}

class _DashboardVideoPlayerScreenState
    extends State<_DashboardVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) async {
        if (!mounted) return;
        await _controller?.setLooping(true);
        await _controller?.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: controller != null && controller.value.isInitialized
                    ? GestureDetector(
                        onTap: () =>
                            setState(() => _showControls = !_showControls),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: controller.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: _showControls ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.18),
                                child: Column(
                                  children: [
                                    const Spacer(),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _togglePlayback,
                                        child: Container(
                                          width: 78,
                                          height: 78,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.42,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            controller.value.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 42,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          VideoProgressIndicator(
                                            controller,
                                            allowScrubbing: true,
                                            colors: const VideoProgressColors(
                                              playedColor: AppColors.hotPink,
                                              bufferedColor:
                                                  AppColors.textMuted,
                                              backgroundColor: AppColors.border,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                controller.value.isPlaying
                                                    ? context.tr('Pause')
                                                    : context.tr('Play'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                widget.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.textLight,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnersFeedTab extends StatelessWidget {
  const _WinnersFeedTab();

  Future<List<Map<String, dynamic>>> _load() async {
    final contests = await FirebaseFirestore.instance
        .collection('contests')
        .orderBy('createdAt', descending: true)
        .get();
    final now = DateTime.now();
    final winners = <Map<String, dynamic>>[];
    for (final contest in contests.docs) {
      final c = contest.data();
      final votingEnd = (c['votingEnd'] as Timestamp?)?.toDate();
      if (votingEnd == null || votingEnd.isAfter(now)) continue;

      final subs = await FirebaseFirestore.instance
          .collection('contests')
          .doc(contest.id)
          .collection('submissions')
          .where('status', isEqualTo: 'approved')
          .get();
      if (subs.docs.isEmpty) continue;
      int maxVotes = -1;
      for (final s in subs.docs) {
        final v = ((s.data()['voteCount'] ?? 0) as num).toInt();
        if (v > maxVotes) maxVotes = v;
      }
      if (maxVotes <= 0) continue;
      final top = subs.docs.firstWhere(
        (s) => ((s.data()['voteCount'] ?? 0) as num).toInt() == maxVotes,
      );
      final t = top.data();
      winners.add({
        'contestTitle': (c['title'] ?? '').toString(),
        'logoUrl': (c['logoUrl'] ?? '').toString(),
        'winnerName': (t['userName'] ?? '').toString(),
        'videoUrl': (t['videoUrl'] ?? '').toString(),
        'votes': maxVotes,
      });
    }
    return winners;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              context.tr('No winners yet.'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final w = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (w['logoUrl'] as String).isNotEmpty
                        ? Image.network(
                            w['logoUrl'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.workspace_premium,
                              color: AppColors.hotPink,
                            ),
                          )
                        : const Icon(
                            Icons.workspace_premium,
                            color: AppColors.hotPink,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (w['contestTitle'] ?? '').toString(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${context.tr('Winner')}: ${(w['winnerName'] ?? '').toString()}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(w['votes'] ?? 0).toString()} ${context.tr('votes')}',
                          style: const TextStyle(
                            color: AppColors.hotPink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProfileGateTab extends StatelessWidget {
  const _ProfileGateTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _LoginRequiredCard();
    return _PublicUserProfileTab(user: user);
  }
}

class _PublicUserProfileTab extends StatelessWidget {
  const _PublicUserProfileTab({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final displayName =
            (data['displayName'] ?? user.displayName ?? context.tr('User'))
                .toString();
        final email = (data['email'] ?? user.email ?? '').toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.hotPink,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsActionTile(
              icon: Icons.badge_outlined,
              title: context.tr('Profile Info'),
              subtitle: context.tr('View your account information.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PublicUserProfileInfoScreen(user: user),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.edit_outlined,
              title: context.tr('Profile Update'),
              subtitle: context.tr('Update your name, email, and phone.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PublicUserProfileUpdateScreen(user: user),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.lock_outline,
              title: context.tr('Change Password'),
              subtitle: context.tr('Update your account password securely.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PublicUserPasswordScreen(user: user),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.language_outlined,
              title: context.tr('Language'),
              subtitle: context.tr('Choose language'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LanguageSelectionScreen(),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.support_agent_outlined,
              title: context.tr('Support'),
              subtitle: context.tr('Chat with support team.'),
              onTap: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatScreen(
                      threadId: user.uid,
                      title: context.tr('Support'),
                      subtitle: user.email,
                    ),
                  ),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.privacy_tip_outlined,
              title: context.tr('Legal & Privacy'),
              subtitle: context.tr('Terms, guidelines, and privacy policy.'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalCenterScreen()),
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.delete_outline_rounded,
              title: context.tr('Delete Account'),
              subtitle: context.tr('Permanently remove your account.'),
              isDanger: true,
              onTap: () async {
                final confirmed = await showDeleteAccountDialog(context);
                if (confirmed != true) return;
                try {
                  await AuthService().deleteCurrentAccount();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr('Account deleted successfully.'),
                      ),
                    ),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  final message = e.toString().contains('requires-recent-login')
                      ? context.tr(
                          'Please login again before deleting your account.',
                        )
                      : context.tr(
                          'Unable to delete account right now. Please try again.',
                        );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                }
              },
            ),
            SettingsActionTile(
              icon: Icons.logout,
              title: context.tr('Logout'),
              subtitle: context.tr('Sign out from your account.'),
              isDanger: true,
              onTap: () async {
                await AuthService().signOut();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
              },
            ),
          ],
        );
      },
    );
  }
}

class _PublicUserProfileInfoScreen extends StatelessWidget {
  const _PublicUserProfileInfoScreen({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? <String, dynamic>{};
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ScreenHeader(title: context.tr('Profile Info')),
                    const SizedBox(height: 16),
                    _ReadOnlyInfoCard(
                      rows: [
                        _InfoRow(
                          context.tr('Full Name'),
                          (data['displayName'] ?? user.displayName ?? '')
                              .toString(),
                        ),
                        _InfoRow(
                          context.tr('Email'),
                          (data['email'] ?? user.email ?? '').toString(),
                        ),
                        _InfoRow(
                          context.tr('Phone number'),
                          (() {
                            final code = (data['phoneCountryCode'] ?? '')
                                .toString();
                            final phone = (data['phoneNumber'] ?? '')
                                .toString();
                            final direct = '$code $phone'.trim();
                            if (direct.isNotEmpty) return direct;
                            return (data['phoneE164'] ?? '').toString();
                          })(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicUserProfileUpdateScreen extends StatefulWidget {
  const _PublicUserProfileUpdateScreen({required this.user});

  final User user;

  @override
  State<_PublicUserProfileUpdateScreen> createState() =>
      _PublicUserProfileUpdateScreenState();
}

class _PublicUserProfileUpdateScreenState
    extends State<_PublicUserProfileUpdateScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _phoneCodeController = TextEditingController(
    text: '+1',
  );
  final TextEditingController _phoneNumberController = TextEditingController();
  String _phoneIso = 'US';
  bool _loading = true;
  bool _saving = false;
  Uint8List? _photoBytes;
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _photoUrl = widget.user.photoURL ?? '';
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    if (!mounted) return;
    final data = snap.data() ?? <String, dynamic>{};
    _nameController.text = (data['displayName'] ?? _nameController.text)
        .toString();
    _emailController.text = (data['email'] ?? _emailController.text).toString();
    _phoneCodeController.text = (data['phoneCountryCode'] ?? '+1').toString();
    _phoneIso = (data['phoneCountryIso'] ?? 'US').toString();
    _phoneNumberController.text = (data['phoneNumber'] ?? '').toString();
    _photoUrl = (data['photoUrl'] ?? _photoUrl).toString();
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneCodeController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final rawBytes = await file.readAsBytes();
    final compressed = await compute(_compressProfilePhotoBytes, rawBytes);
    if (!mounted) return;
    setState(() => _photoBytes = compressed);
  }

  Future<String> _uploadProfilePhoto(String uid) async {
    if (_photoBytes == null) return _photoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'profile_photos/$uid/profile.jpg',
    );
    await ref.putData(
      _photoBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim().toLowerCase();
      final willUpdateEmail =
          newEmail.isNotEmpty && newEmail != (user.email ?? '');
      if (willUpdateEmail) {
        await user.verifyBeforeUpdateEmail(
          newEmail,
          AuthService.emailActionCodeSettings(),
        );
      }
      final uploadedPhotoUrl = await _uploadProfilePhoto(user.uid);
      await user.updateDisplayName(newName);
      if (uploadedPhotoUrl.isNotEmpty) {
        await user.updatePhotoURL(uploadedPhotoUrl);
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': newName,
        'email': (user.email ?? '').trim().toLowerCase(),
        'emailLower': (user.email ?? '').trim().toLowerCase(),
        'phoneCountryCode': _phoneCodeController.text.trim(),
        'phoneCountryIso': _phoneIso,
        'phoneNumber': _phoneNumberController.text.trim(),
        'phoneE164':
            '${_phoneCodeController.text.trim()}${_phoneNumberController.text.trim()}',
        'photoUrl': uploadedPhotoUrl,
        if (willUpdateEmail) 'pendingEmail': newEmail,
        'updatedAt': DateTime.now().toUtc(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _photoUrl = uploadedPhotoUrl;
      _photoBytes = null;
      _show(
        context,
        willUpdateEmail
            ? context.tr(
                'Verification email sent. Confirm it to complete email change.',
              )
            : context.tr('Profile updated.'),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, context.tr('Current password is incorrect.'));
      } else if (e.code == 'email-already-in-use') {
        _show(context, context.tr('This email is already in use.'));
      } else if (e.code == 'requires-recent-login') {
        _show(
          context,
          context.tr('Please login again before changing your email.'),
        );
      } else {
        _show(context, context.tr('Profile update failed (${e.code}).'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _SpaceBackground(),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ScreenHeader(title: context.tr('Profile Update')),
                      const SizedBox(height: 16),
                      _FormCard(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickProfilePhoto,
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.cardSoft,
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _photoBytes != null
                                            ? Image.memory(
                                                _photoBytes!,
                                                fit: BoxFit.cover,
                                              )
                                            : _photoUrl.isNotEmpty
                                            ? Image.network(
                                                _photoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.person_rounded,
                                                      color: AppColors.hotPink,
                                                      size: 42,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person_rounded,
                                                color: AppColors.hotPink,
                                                size: 42,
                                              ),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.hotPink,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.deepSpace,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr('Upload profile photo'),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: context.tr('Full Name'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: context.tr('Email'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: () {
                                      showCountryPicker(
                                        context: context,
                                        showPhoneCode: true,
                                        onSelect: (country) {
                                          setState(() {
                                            _phoneCodeController.text =
                                                '+${country.phoneCode}';
                                            _phoneIso = country.countryCode;
                                          });
                                        },
                                      );
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: context.tr('Country code'),
                                      ),
                                      child: Text(
                                        '$_phoneIso ${_phoneCodeController.text}',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 7,
                                  child: TextField(
                                    controller: _phoneNumberController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: context.tr('Phone number'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.hotPink,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _saving
                                      ? context.tr('Saving...')
                                      : context.tr('Update Profile'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PublicUserPasswordScreen extends StatefulWidget {
  const _PublicUserPasswordScreen({required this.user});

  final User user;

  @override
  State<_PublicUserPasswordScreen> createState() =>
      _PublicUserPasswordScreenState();
}

class _PublicUserPasswordScreenState extends State<_PublicUserPasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _saving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    setState(() => _submitted = true);
    if (_currentPasswordController.text.trim().isEmpty) {
      _show(context, context.tr('Current password is required.'));
      return;
    }
    if (_newPasswordController.text.trim().isEmpty) {
      _show(context, context.tr('New password is required.'));
      return;
    }
    if (_newPasswordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _show(
        context,
        context.tr('New password and confirm password do not match.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text.trim());
      if (!mounted) return;
      _show(context, context.tr('Password updated successfully.'));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _show(context, context.tr('Current password is incorrect.'));
      } else if (e.code == 'weak-password') {
        _show(context, context.tr('New password is too weak.'));
      } else {
        _show(context, context.tr('Password update failed. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordChangeLayout(
      title: context.tr('Change Password'),
      currentController: _currentPasswordController,
      newController: _newPasswordController,
      confirmController: _confirmPasswordController,
      currentObscure: _obscureCurrentPassword,
      newObscure: _obscureNewPassword,
      confirmObscure: _obscureConfirmPassword,
      onToggleCurrent: () =>
          setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
      onToggleNew: () =>
          setState(() => _obscureNewPassword = !_obscureNewPassword),
      onToggleConfirm: () =>
          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
      onSubmit: _changePassword,
      saving: _saving,
      currentError: _submitted && _currentPasswordController.text.trim().isEmpty
          ? context.tr('Current password is required.')
          : null,
      newError: _submitted
          ? (_newPasswordController.text.trim().isEmpty
                ? context.tr('New password is required.')
                : null)
          : null,
      confirmError: _submitted
          ? (_confirmPasswordController.text.trim().isEmpty
                ? context.tr('Confirm password is required.')
                : _newPasswordController.text.trim() !=
                      _confirmPasswordController.text.trim()
                ? context.tr('New password and confirm password do not match.')
                : null)
          : null,
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _ReadOnlyInfoCard extends StatelessWidget {
  const _ReadOnlyInfoCard({required this.rows});

  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      row.value.isEmpty ? '-' : row.value,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

class _LoginRequiredCard extends StatelessWidget {
  const _LoginRequiredCard();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.card.withOpacity(0.96),
              AppColors.cardSoft.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.hotPink, AppColors.magenta],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.hotPink.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('Sign In'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              user == null
                  ? context.tr(
                      'Login to manage your profile, contests and much more.',
                    )
                  : (user.email ?? context.tr('Logged in user')),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            if (user == null) ...[
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.hotPink, AppColors.magenta],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.hotPink.withOpacity(0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      context.tr('Login'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.42)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(
                    context.tr('Create Account'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Expanded(
                    child: _GuestBenefit(
                      icon: Icons.verified_user_outlined,
                      title: 'Secure',
                      subtitle: '100% Safe',
                    ),
                  ),
                  Expanded(
                    child: _GuestBenefit(
                      icon: Icons.emoji_events_outlined,
                      title: 'Contests',
                      subtitle: 'Join & Win',
                    ),
                  ),
                  Expanded(
                    child: _GuestBenefit(
                      icon: Icons.person_outline_rounded,
                      title: 'Personalized',
                      subtitle: 'Just for you',
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                context.tr('You are already signed in.'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuestBenefit extends StatelessWidget {
  const _GuestBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.hotPink, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineVideoDialog extends StatefulWidget {
  const _InlineVideoDialog({required this.videoUrl});

  final String videoUrl;

  @override
  State<_InlineVideoDialog> createState() => _InlineVideoDialogState();
}

class _InlineVideoDialogState extends State<_InlineVideoDialog> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _controller != null && _controller!.value.isInitialized
            ? VideoPlayer(_controller!)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

Uint8List _compressProfilePhotoBytes(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return input;

  img.Image processed = decoded;
  const maxDimension = 640;
  if (processed.width > maxDimension || processed.height > maxDimension) {
    processed = img.copyResize(
      processed,
      width: processed.width >= processed.height ? maxDimension : null,
      height: processed.height > processed.width ? maxDimension : null,
      interpolation: img.Interpolation.average,
    );
  }

  var quality = 85;
  Uint8List bytes = Uint8List.fromList(
    img.encodeJpg(processed, quality: quality),
  );
  while (bytes.lengthInBytes > 100 * 1024 && quality > 35) {
    quality -= 10;
    bytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }

  while (bytes.lengthInBytes > 100 * 1024 &&
      (processed.width > 240 || processed.height > 240)) {
    processed = img.copyResize(
      processed,
      width: (processed.width * 0.85).round(),
      height: (processed.height * 0.85).round(),
      interpolation: img.Interpolation.average,
    );
    bytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
  }
  return bytes;
}

class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [AppColors.cosmicPurple, AppColors.deepSpace],
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 160,
            right: -80,
            child: _GlowOrb(size: 220, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.55), color.withOpacity(0)],
        ),
      ),
    );
  }
}

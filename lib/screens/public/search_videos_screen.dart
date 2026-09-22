import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

const _shareBaseUrl = 'https://video-contest-show-b788b.firebaseapp.com';

/// Lets any user find a specific contestant's video by name, video number, or
/// nationality, then watch / vote / share it (e.g. to promote it on social
/// media so friends can vote).
class SearchVideosScreen extends StatefulWidget {
  const SearchVideosScreen({super.key, this.embedded = false});

  /// When true, renders without its own Scaffold/AppBar so it can be hosted
  /// inside the public feed's tab shell.
  final bool embedded;

  @override
  State<SearchVideosScreen> createState() => _SearchVideosScreenState();
}

class _SearchVideosScreenState extends State<SearchVideosScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _all = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('submissions')
          .where('status', isEqualTo: 'approved')
          .limit(500)
          .get();
      if (!mounted) return;
      setState(() {
        _all = snap.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _all.where((doc) {
      final d = doc.data();
      final code = (d['videoCode'] ?? '').toString().toLowerCase();
      final name = (d['participantNameLower'] ?? d['participantName'] ?? d['userName'] ?? '')
          .toString()
          .toLowerCase();
      final country = (d['country'] ?? '').toString().toLowerCase();
      final countryCode = (d['countryCode'] ?? '').toString().toLowerCase();
      return code == q ||
          code.contains(q) ||
          name.contains(q) ||
          country.contains(q) ||
          countryCode == q;
    }).toList()
      ..sort((a, b) {
        final av = ((a.data()['voteCount'] ?? 0) as num).toInt();
        final bv = ((b.data()['voteCount'] ?? 0) as num).toInt();
        return bv.compareTo(av);
      });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final inner = Column(
      children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('Search by name, number, or country'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(results)),
      ],
    );
    if (widget.embedded) return inner;
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      appBar: AppBar(
        backgroundColor: AppColors.deepSpace,
        title: Text(context.tr('Search Videos')),
      ),
      body: inner,
    );
  }

  Widget _buildBody(List<QueryDocumentSnapshot<Map<String, dynamic>>> results) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _CenteredHint(
        icon: Icons.error_outline,
        text: context.tr('Could not load videos. Please try again.'),
        detail: _error,
        actionLabel: context.tr('Retry'),
        onAction: _load,
      );
    }
    if (_query.trim().isEmpty) {
      return _CenteredHint(
        icon: Icons.search,
        text: context.tr(
          'Search for a contestant by name, video number, or country.',
        ),
      );
    }
    if (results.isEmpty) {
      return _CenteredHint(
        icon: Icons.sentiment_dissatisfied,
        text: context.tr('No videos found. Try a different search.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final doc = results[index];
        return _SearchResultCard(
          data: doc.data(),
          submissionId: doc.id,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _SearchVideoDetailScreen(
                data: doc.data(),
                submissionId: doc.id,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.data,
    required this.submissionId,
    required this.onOpen,
  });

  final Map<String, dynamic> data;
  final String submissionId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name =
        (data['participantName'] ?? data['userName'] ?? context.tr('Participant'))
            .toString();
    final code = (data['videoCode'] ?? '').toString();
    final country = (data['country'] ?? '').toString();
    final votes = ((data['voteCount'] ?? 0) as num).toInt();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.play_circle_fill, color: AppColors.hotPink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (code.isNotEmpty) ...[
                        Text(
                          '#$code',
                          style: const TextStyle(
                            color: AppColors.hotPink,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (country.isNotEmpty)
                        Flexible(
                          child: Text(
                            country,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$votes ${context.tr('votes')}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SearchVideoDetailScreen extends StatefulWidget {
  const _SearchVideoDetailScreen({
    required this.data,
    required this.submissionId,
  });

  final Map<String, dynamic> data;
  final String submissionId;

  @override
  State<_SearchVideoDetailScreen> createState() =>
      _SearchVideoDetailScreenState();
}

class _SearchVideoDetailScreenState extends State<_SearchVideoDetailScreen> {
  VideoPlayerController? _controller;
  bool _voting = false;

  String get _contestId => (widget.data['contestId'] ?? '').toString();
  String get _videoUrl => (widget.data['videoUrl'] ?? '').toString();
  String get _code => (widget.data['videoCode'] ?? '').toString();
  String get _name =>
      (widget.data['participantName'] ?? widget.data['userName'] ?? 'Participant')
          .toString();

  @override
  void initState() {
    super.initState();
    if (_videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller?.setLooping(true);
          _controller?.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _vote() async {
    if (_voting) return;
    final successMsg = context.tr('Vote submitted. Thank you!');
    final loginMsg = context.tr('Please login to vote.');
    final alreadyMsg = context.tr('You already voted for this video.');
    final closedMsg = context.tr('Voting is not open for this contest.');
    final failMsg = context.tr('Could not vote. Please try again.');
    setState(() => _voting = true);
    try {
      await AuthService().incrementContestVote(
        contestId: _contestId,
        submissionId: widget.submissionId,
      );
      if (mounted) _show(successMsg);
    } catch (e) {
      final text = e.toString();
      String message;
      if (text.contains('login') || text.contains('unauthenticated')) {
        message = loginMsg;
      } else if (text.contains('already')) {
        message = alreadyMsg;
      } else if (text.contains('voting') ||
          text.contains('closed') ||
          text.contains('window')) {
        message = closedMsg;
      } else {
        message = failMsg;
      }
      if (mounted) _show(message);
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _share() async {
    final link =
        '$_shareBaseUrl/contest-share?contestId=$_contestId&submissionId=${widget.submissionId}';
    final code = _code.isEmpty ? '' : ' #$_code';
    final text =
        '${context.tr('Vote for my video')}$code — $_name\n$link';
    await Share.share(text);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = (widget.data['country'] ?? '').toString();
    final votes = ((widget.data['voteCount'] ?? 0) as num).toInt();
    final controller = _controller;
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      appBar: AppBar(
        backgroundColor: AppColors.deepSpace,
        title: Text(_name),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                width: double.infinity,
                child: controller != null && controller.value.isInitialized
                    ? GestureDetector(
                        onTap: () => setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        }),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.hotPink.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '#$_code',
                            style: const TextStyle(
                              color: AppColors.hotPink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (country.isNotEmpty)
                        Text(
                          country,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$votes ${context.tr('votes')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _voting ? null : _vote,
                          icon: const Icon(Icons.how_to_vote),
                          label: Text(
                            _voting
                                ? context.tr('Voting...')
                                : context.tr('Vote'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.hotPink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share),
                          label: Text(context.tr('Share')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.text,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

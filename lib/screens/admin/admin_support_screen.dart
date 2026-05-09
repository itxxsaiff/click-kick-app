import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../shared/support_chat_screen.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _status = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('support_threads')
        .orderBy('lastMessageAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Support Admin')),
            Text(
              context.tr('Manage user support tickets'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.68),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.icon(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6D42F5),
                disabledBackgroundColor: const Color(0xFF6D42F5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('New Ticket')),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1222), Color(0xFF09111E)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allDocs = snapshot.data!.docs.toList();
            final allCount = allDocs.length;
            final openCount = allDocs
                .where((doc) => _ticketStatus(doc.data()) == 'open')
                .length;
            final progressCount = allDocs
                .where((doc) => _ticketStatus(doc.data()) == 'in_progress')
                .length;
            final resolvedCount = allDocs
                .where((doc) => _ticketStatus(doc.data()) == 'resolved')
                .length;
            final closedCount = allDocs
                .where((doc) => _ticketStatus(doc.data()) == 'closed')
                .length;

            final filtered = allDocs.where((doc) {
              final data = doc.data();
              final status = _ticketStatus(data);
              if (_status != 'all' && status != _status) return false;
              if (_query.isEmpty) return true;
              final haystack = [
                (data['userName'] ?? '').toString(),
                (data['userEmail'] ?? '').toString(),
                (data['inquiryType'] ?? '').toString(),
                (data['lastMessage'] ?? '').toString(),
              ].join(' ').toLowerCase();
              return haystack.contains(_query);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                _SupportTabs(
                  selected: _status,
                  allCount: allCount,
                  openCount: openCount,
                  progressCount: progressCount,
                  resolvedCount: resolvedCount,
                  closedCount: closedCount,
                  onChanged: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: context.tr('Search tickets'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFF101A2B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.hotPink,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      color: const Color(0xFF151E31),
                      onSelected: (value) => setState(() => _status = value),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'all',
                          child: Text(context.tr('All')),
                        ),
                        PopupMenuItem(
                          value: 'open',
                          child: Text(context.tr('Open')),
                        ),
                        PopupMenuItem(
                          value: 'in_progress',
                          child: Text(context.tr('In Progress')),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Text(context.tr('Resolved')),
                        ),
                        PopupMenuItem(
                          value: 'closed',
                          child: Text(context.tr('Closed')),
                        ),
                      ],
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF101A2B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  _EmptySupportCard(message: context.tr('No matching tickets.'))
                else ...[
                  for (final doc in filtered) ...[
                    _SupportTicketCard(
                      data: doc.data(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupportChatScreen(
                              threadId: doc.id,
                              title:
                                  (doc.data()['userName'] ?? context.tr('User'))
                                      .toString(),
                              subtitle: (doc.data()['userEmail'] ?? '')
                                  .toString(),
                              isAdmin: true,
                            ),
                          ),
                        );
                      },
                      onMenuSelected: (action) =>
                          _handleAction(doc.reference, action),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(
                        context.tr('No more tickets'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.58),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction(
    DocumentReference<Map<String, dynamic>> ref,
    _SupportAction action,
  ) async {
    switch (action) {
      case _SupportAction.open:
        await _setStatus(ref, 'open');
        break;
      case _SupportAction.progress:
        await _setStatus(ref, 'in_progress');
        break;
      case _SupportAction.resolve:
        await _setStatus(ref, 'resolved');
        break;
      case _SupportAction.close:
        await _setStatus(ref, 'closed');
        break;
    }
  }

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) async {
    await ref.set({
      'status': status,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }
}

class _SupportTabs extends StatelessWidget {
  const _SupportTabs({
    required this.selected,
    required this.allCount,
    required this.openCount,
    required this.progressCount,
    required this.resolvedCount,
    required this.closedCount,
    required this.onChanged,
  });

  final String selected;
  final int allCount;
  final int openCount;
  final int progressCount;
  final int resolvedCount;
  final int closedCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('all', '${context.tr('All')} ($allCount)'),
      ('open', '${context.tr('Open')} ($openCount)'),
      ('in_progress', '${context.tr('In Progress')} ($progressCount)'),
      ('resolved', '${context.tr('Resolved')} ($resolvedCount)'),
      ('closed', '${context.tr('Closed')} ($closedCount)'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (value, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? const Color(0xFF6D42F5)
                        : const Color(0xFF101A2B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.data,
    required this.onTap,
    required this.onMenuSelected,
  });

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final ValueChanged<_SupportAction> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final name = (data['userName'] ?? context.tr('User')).toString();
    final email = (data['userEmail'] ?? '').toString();
    final topic = (data['inquiryType'] ?? context.tr('General Inquiry'))
        .toString();
    final preview = (data['lastMessage'] ?? '').toString();
    final status = _ticketStatus(data);
    final timeText = _relativeTime(_threadDate(data));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10192A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TicketAvatar(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.58),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.56),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          preview.isEmpty
                              ? context.tr('No messages yet.')
                              : preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withOpacity(0.58),
                                height: 1.3,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TicketStatusPill(status: status),
                      PopupMenuButton<_SupportAction>(
                        onSelected: onMenuSelected,
                        color: const Color(0xFF151E31),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withOpacity(0.75),
                        ),
                        itemBuilder: (context) => [
                          if (status != 'open')
                            PopupMenuItem(
                              value: _SupportAction.open,
                              child: Text(context.tr('Mark open')),
                            ),
                          if (status != 'in_progress')
                            PopupMenuItem(
                              value: _SupportAction.progress,
                              child: Text(context.tr('Mark in progress')),
                            ),
                          if (status != 'resolved')
                            PopupMenuItem(
                              value: _SupportAction.resolve,
                              child: Text(context.tr('Mark resolved')),
                            ),
                          if (status != 'closed')
                            PopupMenuItem(
                              value: _SupportAction.close,
                              child: Text(context.tr('Close ticket')),
                            ),
                        ],
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

class _TicketAvatar extends StatelessWidget {
  const _TicketAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C45F5), Color(0xFF345DFF)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TicketStatusPill extends StatelessWidget {
  const _TicketStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => const Color(0xFF24B05F),
      'closed' => const Color(0xFF6B7280),
      'in_progress' => const Color(0xFFF0A43A),
      _ => const Color(0xFFD85454),
    };
    final label = switch (status) {
      'resolved' => context.tr('Resolved'),
      'closed' => context.tr('Closed'),
      'in_progress' => context.tr('In Progress'),
      _ => context.tr('Open'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptySupportCard extends StatelessWidget {
  const _EmptySupportCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.8)),
      ),
    );
  }
}

enum _SupportAction { open, progress, resolve, close }

String _ticketStatus(Map<String, dynamic> data) {
  final raw = (data['status'] ?? 'open').toString().trim().toLowerCase();
  switch (raw) {
    case 'resolved':
      return 'resolved';
    case 'closed':
      return 'closed';
    case 'in_progress':
    case 'progress':
      return 'in_progress';
    default:
      return 'open';
  }
}

DateTime _threadDate(Map<String, dynamic> data) {
  final value = data['lastMessageAt'] ?? data['updatedAt'] ?? data['createdAt'];
  if (value is Timestamp) return value.toDate();
  return DateTime.now();
}

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1)
    return parts.first.characters.take(2).toString().toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

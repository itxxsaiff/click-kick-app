import 'package:cloud_firestore/cloud_firestore.dart';

class ClickKickStarEntry {
  ClickKickStarEntry({
    required this.userId,
    required this.rank,
    required this.displayName,
    required this.country,
    required this.photoUrl,
    required this.totalVotes,
    required this.totalUploadedVideos,
    required this.totalContestWins,
    required this.levelKey,
    required this.levelLabel,
    required this.verified,
    required this.approved,
    required this.hidden,
    required this.removed,
  });

  final String userId;
  final int rank;
  final String displayName;
  final String country;
  final String photoUrl;
  final int totalVotes;
  final int totalUploadedVideos;
  final int totalContestWins;
  final String levelKey;
  final String levelLabel;
  final bool verified;
  final bool approved;
  final bool hidden;
  final bool removed;
}

class ClickKickStarStats {
  const ClickKickStarStats({
    required this.totalCreators,
    required this.visibleCreators,
    required this.hiddenCreators,
    required this.unapprovedCreators,
    required this.totalVotes,
    required this.totalVideos,
    required this.totalWins,
  });

  final int totalCreators;
  final int visibleCreators;
  final int hiddenCreators;
  final int unapprovedCreators;
  final int totalVotes;
  final int totalVideos;
  final int totalWins;
}

class ClickKickStarService {
  ClickKickStarService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<Map<String, dynamic>> levelDefinitions = [
    {'key': 'infinity', 'label': 'Infinity Creators', 'minVotes': 10000000},
    {'key': 'platinum', 'label': 'Platinum Creators', 'minVotes': 7000000},
    {'key': 'diamond', 'label': 'Diamond Creators', 'minVotes': 5000000},
    {'key': 'gold', 'label': 'Gold Creators', 'minVotes': 3000000},
    {'key': 'silver', 'label': 'Silver Creators', 'minVotes': 2000000},
    {'key': 'bronze', 'label': 'Bronze Creators', 'minVotes': 1000000},
    {'key': 'rising', 'label': 'Rising Creators', 'minVotes': 0},
  ];

  static Map<String, dynamic> levelForVotes(int votes) {
    for (final level in levelDefinitions) {
      if (votes >= (level['minVotes'] as int)) {
        return level;
      }
    }
    return levelDefinitions.last;
  }

  Future<List<ClickKickStarEntry>> loadEntries({bool publicOnly = true}) async {
    final now = DateTime.now();
    final contestsSnap = await _firestore.collection('contests').get();
    final moderationSnap = await _firestore.collection('click_kick_star').get();
    final submissionsSnap = await _firestore
        .collectionGroup('submissions')
        .where('status', isEqualTo: 'approved')
        .get();

    final moderationByUser = <String, Map<String, dynamic>>{
      for (final doc in moderationSnap.docs) doc.id: doc.data(),
    };

    final finalizedContests = <String>{};
    for (final doc in contestsSnap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toLowerCase();
      final votingEnd = (data['votingEnd'] as Timestamp?)?.toDate();
      final finalized =
          status == 'winner_announced' ||
          status == 'completed' ||
          status == 'ended' ||
          (votingEnd != null && !votingEnd.isAfter(now));
      if (finalized) {
        finalizedContests.add(doc.id);
      }
    }

    final aggregateByUser = <String, _CreatorAggregate>{};
    final approvedByContest =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in submissionsSnap.docs) {
      final data = doc.data();
      final userId = (data['userId'] ?? '').toString();
      if (userId.isEmpty) continue;
      final votes = ((data['voteCount'] ?? 0) as num).toInt();
      final contestId = doc.reference.parent.parent?.id ?? '';

      final aggregate = aggregateByUser.putIfAbsent(
        userId,
        () => _CreatorAggregate(
          fallbackName: (data['userName'] ?? '').toString(),
          fallbackCountry: (data['country'] ?? '').toString(),
          fallbackPhotoUrl: (data['photoUrl'] ?? '').toString(),
        ),
      );
      aggregate.totalVotes += votes;
      aggregate.totalUploadedVideos += 1;

      if (contestId.isNotEmpty) {
        approvedByContest.putIfAbsent(contestId, () => []).add(doc);
      }
    }

    for (final entry in approvedByContest.entries) {
      if (!finalizedContests.contains(entry.key)) continue;
      var maxVotes = -1;
      for (final doc in entry.value) {
        final votes = ((doc.data()['voteCount'] ?? 0) as num).toInt();
        if (votes > maxVotes) maxVotes = votes;
      }
      if (maxVotes < 0) continue;
      for (final doc in entry.value) {
        final data = doc.data();
        final votes = ((data['voteCount'] ?? 0) as num).toInt();
        if (votes != maxVotes) continue;
        final userId = (data['userId'] ?? '').toString();
        if (userId.isEmpty) continue;
        aggregateByUser[userId]?.totalContestWins += 1;
      }
    }

    final userIds = aggregateByUser.keys.toList(growable: false);
    final userDataById = <String, Map<String, dynamic>>{};
    for (var i = 0; i < userIds.length; i += 10) {
      final chunk = userIds.sublist(
        i,
        i + 10 > userIds.length ? userIds.length : i + 10,
      );
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        userDataById[doc.id] = doc.data();
      }
    }

    final entries = <ClickKickStarEntry>[];
    for (final userId in userIds) {
      final aggregate = aggregateByUser[userId]!;
      final userData = userDataById[userId] ?? const <String, dynamic>{};
      final moderation = moderationByUser[userId] ?? const <String, dynamic>{};
      final approved = moderation['approved'] != false;
      final hidden = moderation['hidden'] == true;
      final removed = moderation['removed'] == true;

      if (publicOnly && (!approved || hidden || removed)) {
        continue;
      }

      final displayName =
          (userData['displayName'] ??
                  userData['name'] ??
                  aggregate.fallbackName)
              .toString()
              .trim();
      final country =
          (userData['country'] ??
                  userData['region'] ??
                  aggregate.fallbackCountry)
              .toString()
              .trim();
      final photoUrl =
          (userData['photoUrl'] ??
                  userData['avatarUrl'] ??
                  aggregate.fallbackPhotoUrl)
              .toString()
              .trim();
      final verified =
          userData['verified'] == true || userData['lastOtpVerifiedAt'] != null;

      final level = levelForVotes(aggregate.totalVotes);
      entries.add(
        ClickKickStarEntry(
          userId: userId,
          rank: 0,
          displayName: displayName.isEmpty ? 'Creator' : displayName,
          country: country,
          photoUrl: photoUrl,
          totalVotes: aggregate.totalVotes,
          totalUploadedVideos: aggregate.totalUploadedVideos,
          totalContestWins: aggregate.totalContestWins,
          levelKey: (level['key'] ?? 'rising').toString(),
          levelLabel: (level['label'] ?? 'Rising Creators').toString(),
          verified: verified,
          approved: approved,
          hidden: hidden,
          removed: removed,
        ),
      );
    }

    entries.sort((a, b) {
      final voteCompare = b.totalVotes.compareTo(a.totalVotes);
      if (voteCompare != 0) return voteCompare;
      final winCompare = b.totalContestWins.compareTo(a.totalContestWins);
      if (winCompare != 0) return winCompare;
      return b.totalUploadedVideos.compareTo(a.totalUploadedVideos);
    });

    return [
      for (var i = 0; i < entries.length; i++)
        ClickKickStarEntry(
          userId: entries[i].userId,
          rank: i + 1,
          displayName: entries[i].displayName,
          country: entries[i].country,
          photoUrl: entries[i].photoUrl,
          totalVotes: entries[i].totalVotes,
          totalUploadedVideos: entries[i].totalUploadedVideos,
          totalContestWins: entries[i].totalContestWins,
          levelKey: entries[i].levelKey,
          levelLabel: entries[i].levelLabel,
          verified: entries[i].verified,
          approved: entries[i].approved,
          hidden: entries[i].hidden,
          removed: entries[i].removed,
        ),
    ];
  }

  ClickKickStarStats buildStats(List<ClickKickStarEntry> entries) {
    var visibleCreators = 0;
    var hiddenCreators = 0;
    var unapprovedCreators = 0;
    var totalVotes = 0;
    var totalVideos = 0;
    var totalWins = 0;
    for (final entry in entries) {
      if (entry.hidden || entry.removed) {
        hiddenCreators += 1;
      } else {
        visibleCreators += 1;
      }
      if (!entry.approved) unapprovedCreators += 1;
      totalVotes += entry.totalVotes;
      totalVideos += entry.totalUploadedVideos;
      totalWins += entry.totalContestWins;
    }
    return ClickKickStarStats(
      totalCreators: entries.length,
      visibleCreators: visibleCreators,
      hiddenCreators: hiddenCreators,
      unapprovedCreators: unapprovedCreators,
      totalVotes: totalVotes,
      totalVideos: totalVideos,
      totalWins: totalWins,
    );
  }

  Future<void> updateModeration(
    String userId, {
    bool? approved,
    bool? hidden,
    bool? removed,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (approved != null) data['approved'] = approved;
    if (hidden != null) data['hidden'] = hidden;
    if (removed != null) data['removed'] = removed;
    await _firestore
        .collection('click_kick_star')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }
}

class _CreatorAggregate {
  _CreatorAggregate({
    required this.fallbackName,
    required this.fallbackCountry,
    required this.fallbackPhotoUrl,
  });

  final String fallbackName;
  final String fallbackCountry;
  final String fallbackPhotoUrl;
  int totalVotes = 0;
  int totalUploadedVideos = 0;
  int totalContestWins = 0;
}

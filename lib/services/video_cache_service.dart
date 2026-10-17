import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared on-disk cache for feed/contest video files, so a video that was
/// already watched plays back instantly instead of re-downloading from
/// Firebase Storage every single time it's shown again. Also used to
/// preload the next video in a swipeable feed while the current one plays.
///
/// Not available on web (no local filesystem to cache into) — callers must
/// fall back to a plain network player there.
class VideoCacheService {
  VideoCacheService._();

  static final CacheManager instance = CacheManager(
    Config(
      'clickKickVideoCache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 40,
    ),
  );

  /// Starts downloading [url] into the cache in the background, if it isn't
  /// already cached or already downloading. Errors are swallowed — this is
  /// a best-effort preload, not something playback should ever block on or
  /// fail because of.
  static void preload(String url) {
    if (kIsWeb || url.isEmpty) return;
    // ignore: discarded_futures
    instance.downloadFile(url).then((_) {}, onError: (_) {});
  }

  /// Returns the on-disk cached file for [url] if one already exists
  /// (regardless of freshness) — synchronous-ish, no network wait.
  static Future<FileInfo?> getCachedFile(String url) async {
    if (kIsWeb || url.isEmpty) return null;
    try {
      return await instance.getFileFromCache(url);
    } catch (_) {
      return null;
    }
  }
}

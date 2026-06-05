import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoDownloadResult {
  const VideoDownloadResult({required this.success, required this.messageKey});

  final bool success;
  final String messageKey;
}

class VideoDownloadService {
  VideoDownloadService._();

  static final Dio _dio = Dio();

  static Future<VideoDownloadResult> saveVideo({
    required String videoUrl,
    required String fileName,
  }) async {
    final url = videoUrl.trim();
    if (url.isEmpty) {
      return const VideoDownloadResult(
        success: false,
        messageKey: 'Video download failed. Please try again.',
      );
    }

    if (kIsWeb) {
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      return VideoDownloadResult(
        success: launched,
        messageKey: launched
            ? 'Download opened in browser.'
            : 'Video download failed. Please try again.',
      );
    }

    try {
      var hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }
      if (!hasAccess) {
        return const VideoDownloadResult(
          success: false,
          messageKey: 'Gallery permission is required to save videos.',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = fileName
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final outputPath =
          '${tempDir.path}/${safeName.isEmpty ? 'click_kick_video' : safeName}.mp4';

      await _dio.download(url, outputPath);
      await Gal.putVideo(outputPath, album: 'Click Kick');

      return const VideoDownloadResult(
        success: true,
        messageKey: 'Video saved to your gallery.',
      );
    } catch (_) {
      return const VideoDownloadResult(
        success: false,
        messageKey: 'Video download failed. Please try again.',
      );
    }
  }
}

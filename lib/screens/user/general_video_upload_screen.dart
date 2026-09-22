import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/gradient_button.dart';

/// Uploads a General Video (no competition). The video is saved as `pending`
/// and appears on the profile / feed once an admin approves it.
class GeneralVideoUploadScreen extends StatefulWidget {
  const GeneralVideoUploadScreen({super.key});

  @override
  State<GeneralVideoUploadScreen> createState() =>
      _GeneralVideoUploadScreenState();
}

class _GeneralVideoUploadScreenState extends State<GeneralVideoUploadScreen> {
  static const int _maxBytes = 200 * 1024 * 1024; // Matches storage.rules.
  static const int _maxCaptionLength = 150;

  static const List<String> _videoRequirements = <String>[
    'The video must be free from any watermark, logo, or username from other platforms such as TikTok, Instagram, Snapchat, or any other social media platform.',
    'The video must have clear video and audio quality and must not be blurry or of poor quality.',
    'The video should be in vertical 9:16 format, suitable for Click Kick’s video feed. Recommended resolution: 1080 × 1920.',
    'The video must not contain nudity, violence, hate, harassment, or any other objectionable content.',
    'You confirm that the people appearing in the video agree to the video being published.',
  ];

  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  XFile? _videoFile;
  Uint8List? _videoBytes;
  bool _agreedToRequirements = false;
  bool _saving = false;
  double? _uploadProgress;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Translates [key] and shows it, but only while the screen is still mounted
  /// (safe to call after an `await`).
  void _showTr(String key) {
    if (!mounted) return;
    _show(context.tr(key));
  }

  Future<bool?> _showRequirementsDialog() {
    var agreed = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text(dialogContext.tr('Video Requirements')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dialogContext.tr(
                    'Please read the video requirements before uploading:',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final req in _videoRequirements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3, right: 8),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.hotPink,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            dialogContext.tr(req),
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                InkWell(
                  onTap: () => setLocal(() => agreed = !agreed),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: agreed,
                        onChanged: (v) => setLocal(() => agreed = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            dialogContext.tr(
                              'I agree to the video requirements and confirm that my video is ready for submission.',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton(
              onPressed: agreed
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(dialogContext.tr('Agree & Continue to Upload')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    if (!_agreedToRequirements) {
      final agreed = await _showRequirementsDialog();
      if (agreed != true || !mounted) return;
      setState(() => _agreedToRequirements = true);
    }
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final size = await file.length();
    if (size > _maxBytes) {
      _showTr('This video is too large. The maximum size is 200 MB.');
      return;
    }
    final bytes = kIsWeb ? await file.readAsBytes() : null;
    if (!mounted) return;
    setState(() {
      _videoFile = file;
      _videoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showTr('Please login first.');
      return;
    }
    if (_videoFile == null) {
      _showTr('Please select a video.');
      return;
    }

    setState(() => _saving = true);
    Reference? storageRef;
    try {
      final firestore = FirebaseFirestore.instance;
      final userSnap = await firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 20));
      final userName =
          (userSnap.data()?['displayName'] ?? user.displayName ?? '')
              .toString();

      final doc = firestore.collection('general_videos').doc();
      storageRef = FirebaseStorage.instance.ref().child(
        'general_videos/${user.uid}/${doc.id}.mp4',
      );
      final metadata = SettableMetadata(contentType: 'video/mp4');
      final UploadTask task = kIsWeb
          ? storageRef.putData(
              _videoBytes ?? await _videoFile!.readAsBytes(),
              metadata,
            )
          : storageRef.putFile(File(_videoFile!.path), metadata);
      task.snapshotEvents.listen((snapshot) {
        if (!mounted || snapshot.totalBytes <= 0) return;
        setState(
          () =>
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes,
        );
      });
      await task.timeout(
        const Duration(minutes: 5),
        onTimeout: () async {
          await task.cancel();
          throw TimeoutException('Upload timeout');
        },
      );
      final url = await storageRef.getDownloadURL();

      final now = Timestamp.fromDate(DateTime.now());
      await doc.set({
        'userId': user.uid,
        'userName': userName,
        'caption': _captionController.text.trim(),
        'videoUrl': url,
        'thumbnailUrl': '',
        'status': 'pending',
        'videoType': 'general',
        'viewCount': 0,
        'shareCount': 0,
        'rejectionReason': null,
        'createdAt': now,
        'updatedAt': now,
      });

      _showTr('Video submitted. Pending review.');
      if (mounted) Navigator.pop(context, true);
    } on TimeoutException {
      _showTr('Upload timed out. Check internet and retry.');
    } on FirebaseException catch (e) {
      // The file may have been uploaded before the document write failed.
      if (e.plugin == 'cloud_firestore') {
        try {
          await storageRef?.delete();
        } catch (_) {}
      }
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        _showTr('Permission denied. Check Firestore/Storage rules.');
      } else if (e.code == 'canceled') {
        _showTr('Upload canceled. Please retry.');
      } else {
        if (mounted) {
          _show(
            '${context.tr('Upload failed. Please try again.')} (${e.code})',
          );
        }
      }
    } on SocketException {
      _showTr('Network error. Check internet connection and retry.');
    } catch (_) {
      _showTr('Upload failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _videoFile == null
        ? ''
        : _videoFile!.name.isNotEmpty
        ? _videoFile!.name
        : _videoFile!.path.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Add Video')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          'Share a video on your profile. No competition needed.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textLight,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickVideo,
                        icon: const Icon(Icons.video_library_outlined),
                        label: Text(
                          _videoFile == null
                              ? context.tr('Select Video')
                              : context.tr('Change Video'),
                        ),
                      ),
                      if (_videoFile != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2DAF6F),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _captionController,
                        enabled: !_saving,
                        maxLength: _maxCaptionLength,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          labelText: context.tr('Caption (optional)'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_uploadProgress != null) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    color: AppColors.hotPink,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                ],
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : GradientButton(
                        label: context.tr('Submit Video'),
                        onPressed: _submit,
                      ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'Your video will be visible after an admin approves it.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
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

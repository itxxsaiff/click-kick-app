import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({
    super.key,
    required this.contestId,
    required this.contestTitle,
  });

  final String contestId;
  final String contestTitle;

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _picker = ImagePicker();
  XFile? _videoFile;
  Uint8List? _videoBytes;
  bool _acceptedTerms = false;
  bool _saving = false;
  double? _uploadProgress;

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    Uint8List? bytes;
    if (kIsWeb) {
      bytes = await file.readAsBytes();
    }
    setState(() {
      _videoFile = file;
      _videoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _show(context.tr('Please login first.'));
      return;
    }
    if (_videoFile == null) {
      _show(context.tr('Please select a video.'));
      return;
    }
    if (!_acceptedTerms) {
      _show(context.tr('Please accept contest terms.'));
      return;
    }

    setState(() => _saving = true);

    try {
      final contestRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId);
      final submissionsRef = FirebaseFirestore.instance
          .collection('contests')
          .doc(widget.contestId)
          .collection('submissions');

      final contestSnap = await contestRef.get().timeout(
        const Duration(seconds: 20),
      );
      final maxVideos = ((contestSnap.data()?['maxVideos'] ?? 0) as num)
          .toInt();
      final contestAdminId = (contestSnap.data()?['contestAdminId'] ?? '')
          .toString();
      final contestAdminName = (contestSnap.data()?['contestAdminName'] ?? '')
          .toString();
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 20));
      final participantName =
          (userSnap.data()?['displayName'] ?? user.displayName ?? '')
              .toString();
      if (maxVideos > 0) {
        final approvedSnap = await submissionsRef
            .where('status', isEqualTo: 'approved')
            .get()
            .timeout(const Duration(seconds: 20));
        if (approvedSnap.docs.length >= maxVideos) {
          _show(
            context.tr('Contest upload limit reached. Voting is now active.'),
          );
          setState(() => _saving = false);
          return;
        }
      }

      final existing = await submissionsRef
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 20));
      if (existing.docs.isNotEmpty) {
        _show(context.tr('You already submitted for this contest.'));
        setState(() => _saving = false);
        return;
      }

      final doc = submissionsRef.doc();
      final storageRef = FirebaseStorage.instance.ref().child(
        'videos/${user.uid}/${widget.contestId}/${doc.id}.mp4',
      );

      final UploadTask task;
      if (kIsWeb) {
        final bytes = _videoBytes ?? await _videoFile!.readAsBytes();
        task = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'video/mp4'),
        );
      } else {
        task = storageRef.putFile(
          File(_videoFile!.path),
          SettableMetadata(contentType: 'video/mp4'),
        );
      }
      task.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        setState(() => _uploadProgress = snapshot.bytesTransferred / total);
      });
      await task.timeout(
        const Duration(minutes: 3),
        onTimeout: () async {
          await task.cancel();
          throw TimeoutException('Upload timeout');
        },
      );
      final url = await storageRef.getDownloadURL();
      final now = Timestamp.fromDate(DateTime.now());

      await doc.set({
        'contestId': widget.contestId,
        'userId': user.uid,
        'userName': participantName,
        'participantName': participantName,
        'contestAdminId': contestAdminId,
        'contestAdminName': contestAdminName,
        'videoUrl': url,
        'thumbnailUrl': '',
        'durationSeconds': 0,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
        'rejectionReason': null,
        'allowReupload': false,
        'voteCount': 0,
        'viewCount': 0,
        'termsAcceptedAt': now,
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': 'participant',
        'updatedAt': now,
      }, SetOptions(merge: true));

      _show(context.tr('Video submitted. Pending review.'));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      _show(context.tr('Upload timed out. Check internet and retry.'));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _show(context.tr('Permission denied. Check Firestore/Storage rules.'));
      } else if (e.code == 'canceled') {
        _show(context.tr('Upload canceled. Please retry.'));
      } else {
        _show('Upload failed (${e.code}). Please retry.');
      }
    } on SocketException {
      _show(context.tr('Network error. Check internet connection and retry.'));
    } on UnsupportedError {
      _show(
        context.tr('Video upload is not supported on this platform build.'),
      );
    } catch (e) {
      _show(context.tr('Upload failed. Please try again.'));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2B1B44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _showAgreementModal() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Participant Upload Agreement')),
        content: SingleChildScrollView(
          child: Text(
            context.tr('Participant Upload Agreement Content'),
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Submit Video')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contestTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickVideo,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _videoFile != null
                        ? const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: AppColors.neonGreen,
                              size: 48,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.video_file,
                                color: AppColors.hotPink,
                                size: 44,
                              ),
                              const SizedBox(height: 10),
                              Text(context.tr('Tap to select a 30–45s video')),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      onChanged: (value) =>
                          setState(() => _acceptedTerms = value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: context.tr(
                                  'I have read and agree to the contest ',
                                ),
                              ),
                              TextSpan(
                                text: context.tr('terms'),
                                style: const TextStyle(
                                  color: AppColors.hotPink,
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w700,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = _showAgreementModal,
                              ),
                              TextSpan(text: context.tr('.')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_saving && _uploadProgress != null) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: AppColors.cardSoft,
                    color: AppColors.hotPink,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.tr('Uploading')} ${(100 * (_uploadProgress ?? 0)).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                ],
                GradientButton(
                  label: _saving
                      ? context.tr('Uploading...')
                      : context.tr('Submit Video'),
                  onPressed: _saving ? () {} : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    );
  }
}

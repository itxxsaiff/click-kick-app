import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminFeedVideoForm extends StatefulWidget {
  const AdminFeedVideoForm({super.key});

  @override
  State<AdminFeedVideoForm> createState() => _AdminFeedVideoFormState();
}

class _AdminFeedVideoFormState extends State<AdminFeedVideoForm> {
  final _formKey = GlobalKey<FormState>();
  final _caption = TextEditingController();
  Uint8List? _videoBytes;
  String _videoName = '';
  bool _saving = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _videoBytes = bytes;
      _videoName = file.name;
    });
  }

  Future<String> _uploadVideo(String docId) async {
    if (_videoBytes == null) return '';
    final ref = FirebaseStorage.instance.ref().child(
      'admin_videos/$docId/${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    if (kIsWeb) {
      final task = ref.putData(
        _videoBytes!,
        SettableMetadata(contentType: 'video/mp4'),
      );
      task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0 || !mounted) return;
        setState(() => _uploadProgress = snapshot.bytesTransferred / total);
      });
      await task;
    } else {
      final temp = File('${Directory.systemTemp.path}/admin_feed_$docId.mp4');
      await temp.writeAsBytes(_videoBytes!, flush: true);
      final task = ref.putFile(
        temp,
        SettableMetadata(contentType: 'video/mp4'),
      );
      task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0 || !mounted) return;
        setState(() => _uploadProgress = snapshot.bytesTransferred / total);
      });
      await task;
      await temp.delete();
    }
    if (mounted) setState(() => _uploadProgress = 1);
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_videoBytes == null) {
      _show(context.tr('Please upload a video.'));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _show(context.tr('Please login again.'));
      return;
    }

    setState(() => _saving = true);
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnap.data() ?? <String, dynamic>{};
      final adminName =
          (userData['displayName'] ?? user.displayName ?? user.email ?? '')
              .toString();

      final doc = FirebaseFirestore.instance.collection('admin_videos').doc();
      final videoUrl = await _uploadVideo(doc.id);
      final now = Timestamp.now();

      await doc.set({
        'caption': _caption.text.trim(),
        'videoUrl': videoUrl,
        'adminId': user.uid,
        'adminName': adminName,
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      debugPrint('Admin feed video upload failed: ${e.code} ${e.message}');
      _show(
        '${context.tr('Failed to save video.')} (${e.code}${e.message == null ? '' : ': ${e.message}'})',
      );
    } catch (e) {
      debugPrint('Admin feed video upload failed: $e');
      _show('${context.tr('Failed to save video.')} ($e)');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Add Feed Video')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickVideo,
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.video_library_rounded,
                            color: AppColors.hotPink,
                            size: 42,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _videoName.isEmpty
                                ? context.tr('Upload feed video (MP4)')
                                : _videoName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_saving) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Uploading video...'),
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: _uploadProgress > 0 ? _uploadProgress : null,
                            minHeight: 10,
                            backgroundColor: AppColors.cardSoft,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.hotPink,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _uploadProgress > 0
                                ? '${(_uploadProgress * 100).toStringAsFixed(0)}%'
                                : context.tr('Preparing upload...'),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _caption,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.tr('Video caption'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.tr('Caption is required.');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: _saving
                        ? context.tr('Saving...')
                        : context.tr('Save Video'),
                    onPressed: _saving ? () {} : _save,
                  ),
                ],
              ),
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

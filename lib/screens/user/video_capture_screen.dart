import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import 'general_video_upload_screen.dart';

/// Opened from the bottom nav's "+" button: record a video with the camera,
/// or pick an existing one from the gallery, then continue to the caption /
/// submit screen — the same flow TikTok and Instagram use for their "+".
class VideoCaptureScreen extends StatefulWidget {
  const VideoCaptureScreen({super.key});

  @override
  State<VideoCaptureScreen> createState() => _VideoCaptureScreenState();
}

enum _CaptureStatus { loading, ready, unavailable }

class _VideoCaptureScreenState extends State<VideoCaptureScreen>
    with WidgetsBindingObserver {
  static const _maxSeconds = 60;

  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  _CaptureStatus _status = _CaptureStatus.loading;
  String _errorMessage = '';
  bool _isRecording = false;
  bool _busy = false;
  Timer? _timer;
  int _seconds = 0;

  // Bumped on every _setUpCamera/_openCamera call. A pending call whose
  // generation no longer matches the current one was superseded (e.g. by a
  // second lifecycle event firing before the first finished) and must not
  // touch `_controller` or call setState — that's what was throwing "used
  // after being disposed" on web, where visibility/focus changes can fire
  // AppLifecycleState transitions in quick, spurious succession.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUpCamera();
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Releasing/reacquiring the camera on background/foreground matters on
    // mobile (another app may need the hardware); the browser already owns
    // that lifecycle for a web camera stream, and reacting here only on web
    // was itself the source of the crash — visibility/focus changes fire far
    // more often and less meaningfully there.
    if (kIsWeb) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _generation++;
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setUpCamera();
    }
  }

  Future<void> _setUpCamera() async {
    final myGeneration = ++_generation;
    if (mounted) setState(() => _status = _CaptureStatus.loading);
    try {
      final cameras = await availableCameras();
      if (myGeneration != _generation) return;
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _status = _CaptureStatus.unavailable;
            _errorMessage = context.tr('No camera was found on this device.');
          });
        }
        return;
      }
      _cameras = cameras;
      // Prefer the back camera, matching TikTok/Instagram's default.
      var index = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (index < 0) index = 0;
      await _openCamera(index, generation: myGeneration);
    } catch (e) {
      debugPrint('Camera setup failed: $e');
      if (myGeneration != _generation || !mounted) return;
      setState(() {
        _status = _CaptureStatus.unavailable;
        _errorMessage = context.tr(
          'Camera access was denied. You can still upload a video from your library.',
        );
      });
    }
  }

  Future<void> _openCamera(int index, {int? generation}) async {
    final myGeneration = generation ?? ++_generation;
    final previous = _controller;
    if (previous != null) {
      _controller = null;
      await previous.dispose();
      if (myGeneration != _generation) return;
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    try {
      await controller.initialize();
      if (myGeneration != _generation || !mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraIndex = index;
        _status = _CaptureStatus.ready;
      });
    } catch (e) {
      debugPrint('Camera initialize failed: $e');
      await controller.dispose();
      if (myGeneration != _generation || !mounted) return;
      setState(() {
        _status = _CaptureStatus.unavailable;
        _errorMessage = context.tr(
          'Camera access was denied. You can still upload a video from your library.',
        );
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _busy) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(next);
  }

  void _startTimer() {
    _seconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _seconds += 1);
      if (_seconds >= _maxSeconds) _stopRecording();
    });
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) {
      return;
    }
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    setState(() => _busy = true);
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _busy = false;
      });
      _startTimer();
    } on CameraException catch (e) {
      debugPrint('startVideoRecording failed: $e');
      if (mounted) {
        setState(() => _busy = false);
        _showMessage(
          context.tr('Could not start recording. Please try again.'),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) return;
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _busy = true;
    });
    try {
      final file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() => _busy = false);
      if (_seconds < 1) {
        _showMessage(context.tr('Recording was too short.'));
        return;
      }
      await _continueWith(file);
    } on CameraException catch (e) {
      debugPrint('stopVideoRecording failed: $e');
      if (mounted) {
        setState(() => _busy = false);
        _showMessage(
          context.tr('Could not save the recording. Please try again.'),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    await _continueWith(file);
  }

  Future<void> _continueWith(XFile file) async {
    // Free the camera before handing off, so the next screen's own video
    // player is not competing with a live camera session.
    await _controller?.dispose();
    _controller = null;
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GeneralVideoUploadScreen(initialVideo: file),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildPreview(),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            if (_status == _CaptureStatus.ready && _cameras.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: _isRecording ? null : _flipCamera,
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                  icon: const Icon(
                    Icons.cameraswitch_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            if (_isRecording)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDuration(_seconds)} / ${_formatDuration(_maxSeconds)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: _isRecording
                        ? const SizedBox.shrink()
                        : IconButton(
                            onPressed: _busy ? null : _pickFromGallery,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black38,
                            ),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                  ),
                  GestureDetector(
                    onTap: _status == _CaptureStatus.ready
                        ? _toggleRecording
                        : null,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: AppColors.hotPink,
                          borderRadius: BorderRadius.circular(
                            _isRecording ? 10 : 999,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56, height: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    switch (_status) {
      case _CaptureStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.hotPink),
        );
      case _CaptureStatus.unavailable:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(context.tr('Choose from Gallery')),
                ),
              ],
            ),
          ),
        );
      case _CaptureStatus.ready:
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.hotPink),
          );
        }
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        );
    }
  }
}

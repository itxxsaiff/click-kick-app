import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminNewsForm extends StatefulWidget {
  const AdminNewsForm({super.key, this.newsId, this.existing});

  final String? newsId;
  final Map<String, dynamic>? existing;

  @override
  State<AdminNewsForm> createState() => _AdminNewsFormState();
}

class _AdminNewsFormState extends State<AdminNewsForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _imageUrl = '';
  Uint8List? _imageBytes;
  bool _saving = false;
  DateTime? _publishStart;
  DateTime? _publishEnd;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _title.text = (data['title'] ?? '').toString();
      _body.text = (data['body'] ?? '').toString();
      _imageUrl = (data['imageUrl'] ?? '').toString();
      _publishStart =
          (data['publishStart'] as Timestamp?)?.toDate() ??
          (data['scheduledAt'] as Timestamp?)?.toDate();
      _publishEnd = (data['publishEnd'] as Timestamp?)?.toDate();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<String> _uploadImage(String newsId) async {
    if (_imageBytes == null) return _imageUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'news/$newsId/${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await ref.putData(_imageBytes!);
    return ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_publishStart == null || _publishEnd == null) {
      _show(context.tr('Please select start and end time.'));
      return;
    }
    if (!_publishEnd!.isAfter(_publishStart!)) {
      _show(context.tr('End time must be after start time.'));
      return;
    }
    setState(() => _saving = true);
    final now = Timestamp.fromDate(DateTime.now());
    try {
      final col = FirebaseFirestore.instance.collection('news');
      if (widget.newsId == null) {
        final doc = col.doc();
        final image = await _uploadImage(doc.id);
        await doc.set({
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'imageUrl': image,
          'publishStart': Timestamp.fromDate(_publishStart!),
          'publishEnd': Timestamp.fromDate(_publishEnd!),
          'scheduledAt': Timestamp.fromDate(_publishStart!),
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        final image = await _uploadImage(widget.newsId!);
        await col.doc(widget.newsId).update({
          'title': _title.text.trim(),
          'body': _body.text.trim(),
          'imageUrl': image,
          'publishStart': Timestamp.fromDate(_publishStart!),
          'publishEnd': Timestamp.fromDate(_publishEnd!),
          'scheduledAt': Timestamp.fromDate(_publishStart!),
          'updatedAt': now,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      _show(context.tr('Failed to save news.'));
    } finally {
      if (mounted) setState(() => _saving = false);
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

  String _formatDateTime(DateTime? date) {
    if (date == null) return context.tr('Select date & time');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year} • $hour:$minute $suffix';
  }

  Future<void> _pickDateTime({
    required DateTime? initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return;
    onSelected(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.newsId == null
              ? context.tr('Create News')
              : context.tr('Edit News'),
        ),
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
                    onTap: _pickImage,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: _imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (_imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image.network(
                                      _imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.textMuted,
                                        size: 34,
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_photo_alternate,
                                        color: AppColors.hotPink,
                                        size: 34,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(context.tr('Upload news image')),
                                    ],
                                  )),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: context.tr('News title'),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('Title is required.')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.tr('News details'),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('Details are required.')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _DateTimeField(
                    label: context.tr('Publish start'),
                    value: _formatDateTime(_publishStart),
                    onTap: () => _pickDateTime(
                      initial: _publishStart,
                      onSelected: (value) =>
                          setState(() => _publishStart = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateTimeField(
                    label: context.tr('Publish end'),
                    value: _formatDateTime(_publishEnd),
                    onTap: () => _pickDateTime(
                      initial: _publishEnd ?? _publishStart,
                      onSelected: (value) =>
                          setState(() => _publishEnd = value),
                    ),
                  ),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: _saving
                        ? context.tr('Saving...')
                        : (widget.newsId == null
                              ? context.tr('Create News')
                              : context.tr('Update News')),
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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
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

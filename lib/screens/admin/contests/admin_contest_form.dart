import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminContestForm extends StatefulWidget {
  const AdminContestForm({super.key, this.contestId, this.existing});

  final String? contestId;
  final Map<String, dynamic>? existing;

  @override
  State<AdminContestForm> createState() => _AdminContestFormState();
}

class _AdminContestFormState extends State<AdminContestForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _region = TextEditingController();
  final _maxVideos = TextEditingController();
  final _winnerPrize = TextEditingController();

  String _logoUrl = '';
  Uint8List? _logoBytes;
  String _contestVideoUrl = '';
  Uint8List? _videoBytes;
  String _videoName = '';

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _votingStart;
  DateTime? _votingEnd;

  String? _sponsorId;
  String _sponsorName = '';
  List<Map<String, String>> _sponsors = const [];
  bool _loadingSponsors = true;
  String? _contestAdminId;
  String _contestAdminName = '';

  String? _applicationId;

  String _challengeQuestion = '';
  String _sponsorProductName = '';

  bool _saving = false;

  bool get _sponsorLocked => widget.contestId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _title.text = (data['title'] ?? '') as String;
      _logoUrl = (data['logoUrl'] ?? '') as String;
      _contestVideoUrl = (data['contestVideoUrl'] ?? '') as String;
      _description.text = (data['description'] ?? '') as String;
      _region.text = (data['region'] ?? '') as String;
      _maxVideos.text = (data['maxVideos'] ?? '').toString();
      _winnerPrize.text = (data['winnerPrize'] ?? '').toString();
      _startDate = _readDate(data['submissionStart']);
      _endDate = _readDate(data['submissionEnd']);
      _votingStart = _readDate(data['votingStart']);
      _votingEnd = _readDate(data['votingEnd']);
      _sponsorId = (data['sponsorId'] as String?)?.trim();
      _sponsorName = (data['sponsorName'] as String?)?.trim() ?? '';
      _contestAdminId = (data['contestAdminId'] as String?)?.trim();
      _contestAdminName = (data['contestAdminName'] as String?)?.trim() ?? '';
      _applicationId = (data['sponsorshipApplicationId'] as String?)?.trim();
      _challengeQuestion = (data['challengeQuestion'] ?? '').toString();
      _sponsorProductName = (data['sponsorProductName'] ?? '').toString();
    }

    _loadSponsors();
    _loadSponsorshipSettings();
  }

  Future<void> _loadSponsorshipSettings() async {
    if (_winnerPrize.text.trim().isNotEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('sponsorship')
        .get();
    final data = snap.data() ?? const <String, dynamic>{};
    _winnerPrize.text = ((data['winnerPrize'] ?? 100) as num)
        .toDouble()
        .toStringAsFixed(0);
    if (mounted) setState(() {});
  }

  Future<void> _loadSponsors() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'sponsor')
        .get();

    final sponsors =
        snap.docs
            .map((d) {
              final data = d.data();
              final name = (data['displayName'] ?? data['companyName'] ?? '')
                  .toString()
                  .trim();
              if (name.isEmpty) return null;
              return {'id': d.id, 'name': name};
            })
            .whereType<Map<String, String>>()
            .toList()
          ..sort(
            (a, b) =>
                a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
          );

    if (!mounted) return;
    setState(() {
      _sponsors = sponsors;
      _loadingSponsors = false;
      if (_sponsorId != null && !_sponsors.any((s) => s['id'] == _sponsorId)) {
        _sponsorId = null;
        _sponsorName = '';
      }
    });
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _region.dispose();
    _maxVideos.dispose();
    _winnerPrize.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    ValueSetter<DateTime?> setter,
    DateTime? initial,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setter(picked);
  }

  Future<void> _pickRegion() async {
    FocusScope.of(context).unfocus();
    Country? selected;
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppColors.deepSpace,
        textStyle: const TextStyle(color: AppColors.textLight),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        inputDecoration: const InputDecoration(
          labelText: 'Search country',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      onSelect: (country) => selected = country,
    );
    if (selected != null && mounted) {
      setState(() => _region.text = selected!.name);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _logoBytes = bytes);
  }

  Future<void> _pickContestVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _videoBytes = bytes;
      _videoName = file.name;
    });
  }

  Future<String> _uploadLogo(String contestId) async {
    if (_logoBytes == null) return _logoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'contest_logos/$contestId/${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await ref.putData(_logoBytes!);
    return await ref.getDownloadURL();
  }

  Future<String> _uploadContestVideo(String contestId) async {
    if (_videoBytes == null) return _contestVideoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'contest_videos/$contestId/${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    await ref.putData(
      _videoBytes!,
      SettableMetadata(contentType: 'video/mp4'),
    );
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startDate == null ||
        _endDate == null ||
        _votingStart == null ||
        _votingEnd == null) {
      _show(context.tr('Please select all dates.'));
      return;
    }
    if (_sponsorId == null || _sponsorId!.trim().isEmpty) {
      _show(context.tr('Sponsor assignment is required.'));
      return;
    }

    setState(() => _saving = true);

    final nowDate = DateTime.now();
    final now = Timestamp.fromDate(nowDate);
    final winnerPrize = double.tryParse(_winnerPrize.text.trim()) ?? 100;
    var contestStatus = ((widget.existing?['status'] ?? 'contest_created')
        as String);
    var sponsorVideoApprovalStatus =
        ((widget.existing?['sponsorVideoApprovalStatus'] ?? 'pending_upload')
            as String);
    var sponsorVideoReviewReason =
        ((widget.existing?['sponsorVideoReviewReason'] ?? '') as String);

    if (_videoBytes != null) {
      sponsorVideoApprovalStatus = 'pending';
      sponsorVideoReviewReason = '';
      contestStatus = 'contest_created';
    } else if (_contestVideoUrl.isNotEmpty &&
        sponsorVideoApprovalStatus == 'pending_upload') {
      sponsorVideoApprovalStatus = 'pending';
      contestStatus = 'contest_created';
    }
    if (sponsorVideoApprovalStatus == 'approved') {
      contestStatus = 'live';
    }

    final data = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'region': _region.text.trim(),
      'maxVideos': int.tryParse(_maxVideos.text.trim()) ?? 0,
      'winnerPrize': winnerPrize,
      'contestType': 'sponsor_contest',
      'sponsorId': _sponsorId,
      'sponsorName': _sponsorName,
      'challengeQuestion': _challengeQuestion,
      'sponsorProductName': _sponsorProductName,
      'submissionStart': Timestamp.fromDate(_startDate!),
      'submissionEnd': Timestamp.fromDate(_endDate!),
      'votingStart': Timestamp.fromDate(_votingStart!),
      'votingEnd': Timestamp.fromDate(_votingEnd!),
      'status': contestStatus,
      'sponsorVideoApprovalStatus': sponsorVideoApprovalStatus,
      'sponsorVideoReviewReason': sponsorVideoReviewReason,
      'updatedAt': now,
      if (_contestAdminId != null && _contestAdminId!.trim().isNotEmpty)
        'contestAdminId': _contestAdminId,
      if (_contestAdminName.trim().isNotEmpty)
        'contestAdminName': _contestAdminName,
      if (_applicationId != null && _applicationId!.trim().isNotEmpty)
        'sponsorshipApplicationId': _applicationId,
    };

    final col = FirebaseFirestore.instance.collection('contests');
    String contestId = widget.contestId ?? '';

    if (widget.contestId == null) {
      final doc = col.doc();
      contestId = doc.id;
      String url = '';
      String videoUrl = '';
      try {
        url = await _uploadLogo(doc.id);
      } catch (_) {
        _show(context.tr('Logo upload failed. Please check Storage rules.'));
      }
      try {
        videoUrl = await _uploadContestVideo(doc.id);
      } catch (_) {
        _show(context.tr('Contest video upload failed. Please check Storage rules.'));
      }
      await doc.set({
        ...data,
        'createdAt': now,
        if (url.isNotEmpty) 'logoUrl': url,
        if (videoUrl.isNotEmpty) 'contestVideoUrl': videoUrl,
      });
      if (videoUrl.isNotEmpty) {
        await _addReviewMessage(
          doc.id,
          context.tr('Admin uploaded the official contest video for sponsor review.'),
        );
      }
    } else {
      await col.doc(widget.contestId).update(data);
      if (_logoBytes != null) {
        try {
          final url = await _uploadLogo(widget.contestId!);
          if (url.isNotEmpty) {
            await col.doc(widget.contestId).update({'logoUrl': url});
          }
        } catch (_) {
          _show(context.tr('Logo upload failed. Please check Storage rules.'));
        }
      }
      if (_videoBytes != null) {
        try {
          final videoUrl = await _uploadContestVideo(widget.contestId!);
          if (videoUrl.isNotEmpty) {
            await col.doc(widget.contestId).update({
              'contestVideoUrl': videoUrl,
            });
            await _addReviewMessage(
              widget.contestId!,
              context.tr('Admin uploaded a revised contest video for sponsor review.'),
            );
          }
        } catch (_) {
          _show(
            context.tr('Contest video upload failed. Please check Storage rules.'),
          );
        }
      }
      contestId = widget.contestId!;
    }

    if (_applicationId != null && _applicationId!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('sponsorship_applications')
          .doc(_applicationId)
          .set({
            'linkedContestId': contestId,
            'contestLinkedAt': now,
            'applicationStatus': contestStatus,
            'updatedAt': now,
          }, SetOptions(merge: true));
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }


  Future<void> _addReviewMessage(String contestId, String message) async {
    final user = FirebaseAuth.instance.currentUser;
    final now = Timestamp.fromDate(DateTime.now());
    var senderName = _contestAdminName.trim().isNotEmpty
        ? _contestAdminName.trim()
        : 'Admin';
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snap.data();
        final resolved =
            (data?['displayName'] ?? user.displayName ?? '').toString().trim();
        if (resolved.isNotEmpty) senderName = resolved;
      } catch (_) {}
    }
    await FirebaseFirestore.instance
        .collection('contests')
        .doc(contestId)
        .collection('review_messages')
        .add({
      'senderId': user?.uid ?? '',
      'senderName': senderName,
      'senderRole': 'admin',
      'message': message,
      'type': 'system',
      'createdAt': now,
    });
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

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: ''),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? label
                    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: value == null
                      ? AppColors.textMuted
                      : AppColors.textLight,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contestId == null
              ? context.tr('Create Sponsored Contest')
              : context.tr('Edit Sponsored Contest'),
        ),
        backgroundColor: AppColors.deepSpace,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _logoBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                        )
                      : (_logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  _logoUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload,
                                    color: AppColors.hotPink,
                                    size: 36,
                                  ),
                                  SizedBox(height: 8),
                                  Text(context.tr('Upload contest logo')),
                                ],
                              )),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickContestVideo,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.ondemand_video_rounded,
                        color: AppColors.hotPink,
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _videoName.isNotEmpty
                            ? _videoName
                            : (_contestVideoUrl.isNotEmpty
                                  ? context.tr('Contest video uploaded')
                                  : context.tr('Upload contest intro video (MP4)')),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: context.tr('Contest name'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.tr('Details')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _region,
                readOnly: true,
                onTap: _pickRegion,
                decoration: InputDecoration(
                  labelText: context.tr('Region'),
                  suffixIcon: IconButton(
                    onPressed: _pickRegion,
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _winnerPrize,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.tr('Winner prize (USD)'),
                ),
                validator: (v) {
                  final value = double.tryParse((v ?? '').trim());
                  if (value == null || value <= 0) {
                    return context.tr('Enter valid amount');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_challengeQuestion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${context.tr('Selected Question')}: $_challengeQuestion',
                    style: const TextStyle(color: AppColors.neonGreen),
                  ),
                ),
              ],
              if (_sponsorProductName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${context.tr('Product')}: $_sponsorProductName',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_loadingSponsors)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_sponsorLocked)
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('Assigned Sponsor'),
                  ),
                  child: Text(
                    _sponsorName.isNotEmpty
                        ? _sponsorName
                        : (_sponsors
                              .where((s) => s['id'] == _sponsorId)
                              .map((s) => s['name'] ?? '')
                              .firstWhere(
                                (name) => name.trim().isNotEmpty,
                                orElse: () => '',
                              )),
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _sponsorId,
                  decoration: InputDecoration(
                    labelText: context.tr('Assign Sponsor'),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? context.tr('Please assign a sponsor.')
                      : null,
                  items: _sponsors
                      .map(
                        (s) => DropdownMenuItem<String>(
                          value: s['id'],
                          child: Text(s['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    Map<String, String>? sponsor;
                    for (final item in _sponsors) {
                      if (item['id'] == value) {
                        sponsor = item;
                        break;
                      }
                    }
                    setState(() {
                      _sponsorId = value;
                      _sponsorName = sponsor?['name'] ?? '';
                    });
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxVideos,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Total max videos'),
                ),
              ),
              const SizedBox(height: 16),
              _dateField(
                context.tr('Submission start'),
                _startDate,
                () => _pickDate(
                  (v) => setState(() => _startDate = v),
                  _startDate,
                ),
              ),
              const SizedBox(height: 12),
              _dateField(
                context.tr('Submission end'),
                _endDate,
                () => _pickDate((v) => setState(() => _endDate = v), _endDate),
              ),
              const SizedBox(height: 12),
              _dateField(
                context.tr('Voting start'),
                _votingStart,
                () => _pickDate(
                  (v) => setState(() => _votingStart = v),
                  _votingStart,
                ),
              ),
              const SizedBox(height: 12),
              _dateField(
                context.tr('Voting end'),
                _votingEnd,
                () => _pickDate(
                  (v) => setState(() => _votingEnd = v),
                  _votingEnd,
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: _saving
                    ? context.tr('Saving...')
                    : (widget.contestId == null
                          ? context.tr('Create')
                          : context.tr('Update')),
                onPressed: _saving ? () {} : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

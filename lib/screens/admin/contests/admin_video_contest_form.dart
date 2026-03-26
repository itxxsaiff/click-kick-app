import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gradient_button.dart';

class AdminVideoContestForm extends StatefulWidget {
  const AdminVideoContestForm({super.key, this.contestId, this.existing});

  final String? contestId;
  final Map<String, dynamic>? existing;

  @override
  State<AdminVideoContestForm> createState() => _AdminVideoContestFormState();
}

class _AdminVideoContestFormState extends State<AdminVideoContestForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _region = TextEditingController();
  final _maxVideos = TextEditingController();
  final _winnerPrize = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _votingStart;
  DateTime? _votingEnd;

  Uint8List? _videoBytes;
  String _videoPath = '';
  String _videoUrl = '';
  String? _contestAdminId;
  String _contestAdminName = '';
  List<Map<String, String>> _admins = const [];
  List<String> _selectedRegions = [];
  bool _loadingAdmins = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _title.text = (data['title'] ?? '').toString();
      _description.text = (data['description'] ?? '').toString();
      final existingRegions = (data['regions'] as List?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (existingRegions != null && existingRegions.isNotEmpty) {
        _selectedRegions = existingRegions;
      } else {
        final regionText = (data['region'] ?? '').toString();
        _selectedRegions = regionText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      _region.text = _selectedRegions.join(', ');
      _maxVideos.text = (data['maxVideos'] ?? '').toString();
      _winnerPrize.text = (data['winnerPrize'] ?? '').toString();
      _startDate = _readDate(data['submissionStart']);
      _endDate = _readDate(data['submissionEnd']);
      _votingStart = _readDate(data['votingStart']);
      _votingEnd = _readDate(data['votingEnd']);
      _videoUrl = (data['contestVideoUrl'] ?? '').toString();
      _contestAdminId = (data['contestAdminId'] ?? '').toString().trim();
      _contestAdminName = (data['contestAdminName'] ?? '').toString().trim();
    }
    _loadAdmins();
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

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _pickRegion() async {
    final countries = CountryService().getAll()
      ..sort((a, b) => a.name.compareTo(b.name));
    final initial = Set<String>.from(_selectedRegions);
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final temp = Set<String>.from(initial);
        var query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = countries.where((country) {
              final q = query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return country.name.toLowerCase().contains(q);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('Select regions'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.tr('Cancel')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => setModalState(() => query = value),
                      decoration: InputDecoration(
                        labelText: context.tr('Search country'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final country = filtered[index];
                            final checked = temp.contains(country.name);
                            return CheckboxListTile(
                              value: checked,
                              activeColor: AppColors.hotPink,
                              checkColor: Colors.white,
                              title: Text(
                                country.name,
                                style: const TextStyle(color: AppColors.textLight),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) {
                                setModalState(() {
                                  if (value ?? false) {
                                    temp.add(country.name);
                                  } else {
                                    temp.remove(country.name);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GradientButton(
                      label: context.tr('Done'),
                      onPressed: () =>
                          Navigator.pop(context, temp.toList()..sort()),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedRegions = selected;
      _region.text = _selectedRegions.join(', ');
    });
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

  Future<void> _loadAdmins() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final admins =
        snap.docs
            .where((d) {
              final role = (d.data()['role'] ?? '').toString().toLowerCase();
              return role.contains('admin') ||
                  role == 'super_admin' ||
                  role == 'employee';
            })
            .map((d) {
              final data = d.data();
              final name = (data['displayName'] ?? data['email'] ?? '')
                  .toString();
              final role = (data['role'] ?? '').toString();
              return {'id': d.id, 'name': name, 'role': role};
            })
            .where((e) => (e['name'] ?? '').trim().isNotEmpty)
            .toList()
          ..sort(
            (a, b) => (a['name'] ?? '').toLowerCase().compareTo(
              (b['name'] ?? '').toLowerCase(),
            ),
          );

    if (!mounted) return;
    setState(() {
      _admins = admins;
      _loadingAdmins = false;
      if (_contestAdminId != null &&
          _contestAdminId!.isNotEmpty &&
          !_admins.any((a) => a['id'] == _contestAdminId)) {
        _contestAdminId = null;
        _contestAdminName = '';
      }
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _videoBytes = bytes;
      _videoPath = file.name;
    });
  }

  Future<String> _uploadVideo(String contestId) async {
    if (_videoBytes == null) return _videoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'contest_videos/$contestId/${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    if (kIsWeb) {
      await ref.putData(
        _videoBytes!,
        SettableMetadata(contentType: 'video/mp4'),
      );
    } else {
      final temp = File(
        '${Directory.systemTemp.path}/contest_intro_$contestId.mp4',
      );
      await temp.writeAsBytes(_videoBytes!, flush: true);
      await ref.putFile(temp, SettableMetadata(contentType: 'video/mp4'));
      await temp.delete();
    }
    return ref.getDownloadURL();
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
    if (_contestAdminId == null || _contestAdminId!.isEmpty) {
      _show(context.tr('Please assign a contest admin.'));
      return;
    }

    setState(() => _saving = true);
    final nowDate = DateTime.now();
    final now = Timestamp.fromDate(nowDate);
    final winnerPrize = double.tryParse(_winnerPrize.text.trim()) ?? 100;
    final isLive =
        !nowDate.isBefore(_startDate!) && !nowDate.isAfter(_votingEnd!);
    final contestStatus = isLive ? 'live' : 'contest_created';

    final data = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'region': _selectedRegions.join(', '),
      'regions': _selectedRegions,
      'maxVideos': int.tryParse(_maxVideos.text.trim()) ?? 0,
      'winnerPrize': winnerPrize,
      'contestType': 'video_contest',
      'contestAdminId': _contestAdminId,
      'contestAdminName': _contestAdminName,
      'submissionStart': Timestamp.fromDate(_startDate!),
      'submissionEnd': Timestamp.fromDate(_endDate!),
      'votingStart': Timestamp.fromDate(_votingStart!),
      'votingEnd': Timestamp.fromDate(_votingEnd!),
      'status': contestStatus,
      'updatedAt': now,
    };

    final col = FirebaseFirestore.instance.collection('contests');
    if (widget.contestId == null) {
      final doc = col.doc();
      final videoUrl = await _uploadVideo(doc.id);
      await doc.set({...data, 'createdAt': now, 'contestVideoUrl': videoUrl});
    } else {
      await col.doc(widget.contestId).update(data);
      if (_videoBytes != null) {
        final videoUrl = await _uploadVideo(widget.contestId!);
        await col.doc(widget.contestId).update({'contestVideoUrl': videoUrl});
      }
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
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
              ? context.tr('Create Video Contest')
              : context.tr('Edit Video Contest'),
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
                onTap: _pickVideo,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.video_library,
                        color: AppColors.hotPink,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _videoPath.isNotEmpty
                            ? '${context.tr('Script video selected')}: $_videoPath'
                            : (_videoUrl.isNotEmpty
                                  ? context.tr('Script video uploaded')
                                  : context.tr(
                                      'Upload script/instruction video (MP4)',
                                    )),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                decoration: InputDecoration(
                  labelText: context.tr('Details / Script for participants'),
                ),
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
                  labelText: context.tr('Regions'),
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
              TextFormField(
                controller: _maxVideos,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('Total max videos'),
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingAdmins)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _contestAdminId,
                  decoration: InputDecoration(
                    labelText: context.tr('Assign Contest Admin'),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? context.tr('Required') : null,
                  items: _admins
                      .map(
                        (a) => DropdownMenuItem<String>(
                          value: a['id'],
                          child: Text(
                            '${a['name'] ?? ''} (${(a['role'] ?? '').toString().replaceAll('_', ' ')})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    Map<String, String>? selected;
                    for (final item in _admins) {
                      if (item['id'] == value) {
                        selected = item;
                        break;
                      }
                    }
                    setState(() {
                      _contestAdminId = value;
                      _contestAdminName = selected?['name'] ?? '';
                    });
                  },
                ),
              const SizedBox(height: 12),
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

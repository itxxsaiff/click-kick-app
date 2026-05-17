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

  Uint8List? _logoBytes;
  String _logoUrl = '';
  String _logoName = '';
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
  List<Map<String, String>> _sponsors = const [];
  String _contestSource = 'click_kick';
  String? _sponsorId;
  String _sponsorName = '';
  String? _sponsorshipApplicationId;
  bool _loadingSponsors = true;
  List<String> _selectedRegions = [];
  bool _loadingAdmins = true;
  bool _titleTouched = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing;
    if (data != null) {
      _contestSource =
          (data['contestType'] ?? 'video_contest') == 'sponsor_contest'
          ? 'sponsorship'
          : 'click_kick';
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
      _logoUrl = (data['logoUrl'] ?? '').toString();
      _startDate = _readDate(data['submissionStart']);
      _endDate = _readDate(data['submissionEnd']);
      _votingStart = _readDate(data['votingStart']);
      _votingEnd = _readDate(data['votingEnd']);
      _videoUrl = (data['contestVideoUrl'] ?? '').toString();
      _contestAdminId = (data['contestAdminId'] ?? '').toString().trim();
      _contestAdminName = (data['contestAdminName'] ?? '').toString().trim();
      _sponsorId = (data['sponsorId'] ?? '').toString().trim();
      _sponsorName = (data['sponsorName'] ?? '').toString().trim();
      _sponsorshipApplicationId = (data['sponsorshipApplicationId'] ?? '')
          .toString()
          .trim();
      _titleTouched = _title.text.trim().isNotEmpty;
    }
    _title.addListener(() {
      if (_title.text.trim().isNotEmpty) {
        _titleTouched = true;
      }
    });
    _loadAdmins();
    _loadSponsors();
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

  Future<void> _loadSponsors() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'sponsor')
        .get();

    final sponsors =
        snap.docs
            .map((doc) {
              final data = doc.data();
              final name =
                  (data['companyName'] ??
                          data['displayName'] ??
                          data['email'] ??
                          '')
                      .toString()
                      .trim();
              if (name.isEmpty) return null;
              return {
                'id': doc.id,
                'name': name,
                'logoUrl': (data['logoUrl'] ?? '').toString(),
              };
            })
            .whereType<Map<String, String>>()
            .toList()
          ..sort(
            (a, b) => (a['name'] ?? '').toLowerCase().compareTo(
              (b['name'] ?? '').toLowerCase(),
            ),
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
    if (_contestSource == 'sponsorship' &&
        _sponsorId != null &&
        _sponsorId!.isNotEmpty) {
      await _applySponsorSelection(_sponsorId!, shouldSuggestTitle: false);
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
    setState(() {
      _logoBytes = bytes;
      _logoName = file.name;
    });
  }

  Future<String> _uploadLogo(String contestId) async {
    if (_logoBytes == null) return _logoUrl;
    final ref = FirebaseStorage.instance.ref().child(
      'contest_logos/$contestId/${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await ref.putData(_logoBytes!);
    return ref.getDownloadURL();
  }

  String _extractSponsorVideoUrl(Map<String, dynamic> data) {
    final directKeys = [
      'contestVideoUrl',
      'videoUrl',
      'introVideoUrl',
      'officialVideoUrl',
      'sponsorVideoUrl',
    ];
    for (final key in directKeys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    final assets = data['productAssetUrls'];
    if (assets is List) {
      for (final item in assets) {
        final value = item.toString();
        if (value.toLowerCase().contains('.mp4') ||
            value.toLowerCase().contains('video')) {
          return value;
        }
      }
    }
    return '';
  }

  Future<void> _applySponsorSelection(
    String sponsorId, {
    bool shouldSuggestTitle = true,
  }) async {
    final selected = _sponsors.cast<Map<String, String>?>().firstWhere(
      (item) => item?['id'] == sponsorId,
      orElse: () => null,
    );
    final sponsorName = selected?['name'] ?? '';
    final sponsorLogo = selected?['logoUrl'] ?? '';

    final appSnap = await FirebaseFirestore.instance
        .collection('sponsorship_applications')
        .where('sponsorId', isEqualTo: sponsorId)
        .get();
    final appDocs = appSnap.docs.toList()
      ..sort((a, b) {
        final at =
            (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt =
            (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
    final latestApp = appDocs.isEmpty ? null : appDocs.first.data();
    final latestAppId = appDocs.isEmpty ? null : appDocs.first.id;

    if (!mounted) return;
    setState(() {
      _sponsorId = sponsorId;
      _sponsorName = sponsorName;
      _sponsorshipApplicationId = latestAppId;
      if (_logoBytes == null) {
        _logoUrl = (latestApp?['logoUrl'] ?? sponsorLogo).toString();
      }
      if (_videoBytes == null) {
        final sponsorVideo = latestApp == null
            ? ''
            : _extractSponsorVideoUrl(latestApp);
        if (sponsorVideo.isNotEmpty) {
          _videoUrl = sponsorVideo;
          _videoPath = '';
        }
      }
      final description = (latestApp?['description'] ?? '').toString().trim();
      if (description.isNotEmpty && _description.text.trim().isEmpty) {
        _description.text = description;
      }
      final country = (latestApp?['targetCountry'] ?? '').toString().trim();
      if (country.isNotEmpty) {
        _selectedRegions = [country];
        _region.text = country;
      }
      final maxVideos = (latestApp?['maxVideos'] ?? '').toString().trim();
      if (maxVideos.isNotEmpty && _maxVideos.text.trim().isEmpty) {
        _maxVideos.text = maxVideos;
      }
      final winnerPrize = (latestApp?['winnerPrize'] ?? '').toString().trim();
      if (winnerPrize.isNotEmpty && _winnerPrize.text.trim().isEmpty) {
        _winnerPrize.text = winnerPrize;
      }
      _startDate =
          _startDate ??
          _readDate(
            latestApp?['proposedSubmissionStart'] ??
                latestApp?['submissionStart'],
          );
      _endDate =
          _endDate ??
          _readDate(
            latestApp?['proposedSubmissionEnd'] ?? latestApp?['submissionEnd'],
          );
      _votingStart =
          _votingStart ??
          _readDate(
            latestApp?['proposedVotingStart'] ?? latestApp?['votingStart'],
          );
      _votingEnd =
          _votingEnd ??
          _readDate(latestApp?['proposedVotingEnd'] ?? latestApp?['votingEnd']);
    });

    if (shouldSuggestTitle) {
      final appBrand = (latestApp?['brandName'] ?? '').toString().trim();
      await _suggestContestTitle(
        baseName: appBrand.isNotEmpty ? appBrand : sponsorName,
      );
    }
  }

  Future<void> _suggestContestTitle({required String baseName}) async {
    final base = baseName.trim();
    if (base.isEmpty) return;
    if (_titleTouched && widget.contestId != null) return;
    final snap = await FirebaseFirestore.instance.collection('contests').get();
    final pattern = RegExp(
      '^${RegExp.escape(base)}\\s+(\\d+)\$',
      caseSensitive: false,
    );
    var maxNumber = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().trim();
      final match = pattern.firstMatch(title);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '') ?? 0;
        if (number > maxNumber) maxNumber = number;
      }
    }
    final nextLabel = '$base ${(maxNumber + 1).toString().padLeft(2, '0')}';
    if (!mounted) return;
    setState(() {
      if (!_titleTouched || _title.text.trim().isEmpty) {
        _title.text = nextLabel;
      }
    });
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
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                ),
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
    if (_contestSource == 'sponsorship' &&
        (_sponsorId == null || _sponsorId!.trim().isEmpty)) {
      _show(context.tr('Please select a sponsor.'));
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
      'contestType': _contestSource == 'sponsorship'
          ? 'sponsor_contest'
          : 'video_contest',
      'createdFrom': _contestSource,
      'contestAdminId': _contestAdminId,
      'contestAdminName': _contestAdminName,
      'submissionStart': Timestamp.fromDate(_startDate!),
      'submissionEnd': Timestamp.fromDate(_endDate!),
      'votingStart': Timestamp.fromDate(_votingStart!),
      'votingEnd': Timestamp.fromDate(_votingEnd!),
      'status': contestStatus,
      'updatedAt': now,
      if (_contestSource == 'sponsorship') 'sponsorId': _sponsorId,
      if (_contestSource == 'sponsorship') 'sponsorName': _sponsorName,
      if (_contestSource == 'sponsorship' &&
          (_sponsorshipApplicationId ?? '').isNotEmpty)
        'sponsorshipApplicationId': _sponsorshipApplicationId,
    };

    final col = FirebaseFirestore.instance.collection('contests');
    if (widget.contestId == null) {
      final doc = col.doc();
      final logoUrl = await _uploadLogo(doc.id);
      final videoUrl = await _uploadVideo(doc.id);
      await doc.set({
        ...data,
        'createdAt': now,
        'contestVideoUrl': videoUrl,
        if (logoUrl.isNotEmpty) 'logoUrl': logoUrl,
      });
    } else {
      await col.doc(widget.contestId).update(data);
      if (_logoBytes != null) {
        final logoUrl = await _uploadLogo(widget.contestId!);
        await col.doc(widget.contestId).update({'logoUrl': logoUrl});
      }
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
              DropdownButtonFormField<String>(
                initialValue: _contestSource,
                decoration: InputDecoration(
                  labelText: context.tr('Create contest from'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'click_kick',
                    child: Text(context.tr('Click Kick')),
                  ),
                  DropdownMenuItem(
                    value: 'sponsorship',
                    child: Text(context.tr('Sponsorship')),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _contestSource = value;
                    if (value == 'click_kick') {
                      _sponsorId = null;
                      _sponsorName = '';
                      _sponsorshipApplicationId = null;
                    }
                  });
                  if (value == 'click_kick') {
                    await _suggestContestTitle(baseName: 'Click Kick');
                  } else if (_sponsorId != null && _sponsorId!.isNotEmpty) {
                    await _applySponsorSelection(_sponsorId!);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_contestSource == 'sponsorship')
                if (_loadingSponsors)
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
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _sponsorId,
                    decoration: InputDecoration(
                      labelText: context.tr('Select Sponsor'),
                    ),
                    validator: (value) {
                      if (_contestSource != 'sponsorship') return null;
                      return (value == null || value.isEmpty)
                          ? context.tr('Required')
                          : null;
                    },
                    items: _sponsors
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(s['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null || value.isEmpty) return;
                      await _applySponsorSelection(value);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _logoBytes != null || _logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: _logoBytes != null
                              ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                              : Image.network(_logoUrl, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: AppColors.hotPink,
                              size: 34,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('Upload contest logo'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
              ),
              if (_logoName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _logoName,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
                                  ? context.tr('Script video available')
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
                onChanged: (_) => _titleTouched = true,
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

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../l10n/l10n.dart';
import '../../services/auth_service.dart';
import '../../services/employee_report_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradient_button.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String _filter = 'all';
  final _reportService = EmployeeReportService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .snapshots();
    final contestsStream = FirebaseFirestore.instance
        .collection('contests')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Employees')),
            Text(
              context.tr('Manage system employees'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.deepSpace,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _openCreateForm,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7B3FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('Add Employee')),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, usersSnap) {
              if (!usersSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final employeeDocs = usersSnap.data!.docs;
              final employeeIds = employeeDocs.map((e) => e.id).toSet();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: contestsStream,
                builder: (context, contestsSnap) {
                  final contestDocs = contestsSnap.data?.docs ?? const [];
                  final assignedCountByEmployee = <String, int>{};
                  for (final c in contestDocs) {
                    final assignedId = (c.data()['contestAdminId'] ?? '')
                        .toString();
                    if (!employeeIds.contains(assignedId)) continue;
                    assignedCountByEmployee[assignedId] =
                        (assignedCountByEmployee[assignedId] ?? 0) + 1;
                  }

                  final filteredDocs =
                      employeeDocs.where((doc) {
                        final d = doc.data();
                        final name = (d['displayName'] ?? '').toString();
                        final email = (d['email'] ?? '').toString();
                        final phone = (d['phoneE164'] ?? '').toString();
                        final assigned =
                            (assignedCountByEmployee[doc.id] ?? 0) > 0;
                        final matchesFilter = switch (_filter) {
                          'assigned' => assigned,
                          'unassigned' => !assigned,
                          _ => true,
                        };
                        if (!matchesFilter) return false;
                        if (_search.isEmpty) return true;
                        final q = _search.toLowerCase();
                        return name.toLowerCase().contains(q) ||
                            email.toLowerCase().contains(q) ||
                            phone.toLowerCase().contains(q);
                      }).toList()..sort((a, b) {
                        final aDate =
                            (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        final bDate =
                            (b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0;
                        return bDate.compareTo(aDate);
                      });

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(
                                () => _search = v.trim().toLowerCase(),
                              ),
                              decoration: InputDecoration(
                                hintText: context.tr('Search employees'),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _search = '');
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF18152A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: PopupMenuButton<String>(
                              tooltip: context.tr('Filter'),
                              initialValue: _filter,
                              color: AppColors.card,
                              icon: const Icon(
                                Icons.filter_list_rounded,
                                color: Colors.white,
                              ),
                              onSelected: (value) =>
                                  setState(() => _filter = value),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'all',
                                  child: Text(context.tr('All')),
                                ),
                                PopupMenuItem(
                                  value: 'assigned',
                                  child: Text(context.tr('Assigned')),
                                ),
                                PopupMenuItem(
                                  value: 'unassigned',
                                  child: Text(context.tr('Unassigned')),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (filteredDocs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151324),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(context.tr('No employees found.')),
                        )
                      else
                        ...filteredDocs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final doc = entry.value;
                          final d = doc.data();
                          final name = (d['displayName'] ?? '').toString();
                          final email = (d['email'] ?? '').toString();
                          final phone = (d['phoneE164'] ?? '').toString();
                          final photoUrl = (d['photoUrl'] ?? '').toString();
                          final assignedCount =
                              assignedCountByEmployee[doc.id] ?? 0;
                          final isDisabled =
                              (d['accountStatus'] ?? 'active').toString() ==
                              'disabled';
                          final subtitle = assignedCount > 0
                              ? '${context.tr('Assigned')}: $assignedCount'
                              : context.tr('System employee');
                          final statusColor = isDisabled
                              ? const Color(0xFFD64B6A)
                              : const Color(0xFF38E27B);
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: index == filteredDocs.length - 1 ? 0 : 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151324),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSoft,
                                    borderRadius: BorderRadius.circular(12),
                                    image: photoUrl.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(photoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    gradient: photoUrl.isEmpty
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF4B1A7E),
                                              Color(0xFF12101C),
                                            ],
                                          )
                                        : null,
                                  ),
                                  child: photoUrl.isEmpty
                                      ? Center(
                                          child: Text(
                                            name.isEmpty
                                                ? 'E'
                                                : name
                                                      .trim()
                                                      .split(RegExp(r'\s+'))
                                                      .take(2)
                                                      .map(
                                                        (e) =>
                                                            e[0].toUpperCase(),
                                                      )
                                                      .join(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.16,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              context.tr(
                                                isDisabled
                                                    ? 'Inactive'
                                                    : 'Active',
                                              ),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          if (phone.isNotEmpty)
                                            _EmployeeMeta(
                                              icon: Icons.phone_outlined,
                                              label: phone,
                                            ),
                                          _EmployeeMeta(
                                            icon: Icons.assignment_ind_outlined,
                                            label: assignedCount > 0
                                                ? '${context.tr('Assigned')}: $assignedCount'
                                                : context.tr('Unassigned'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textMuted,
                                  ),
                                  onSelected: (value) async {
                                    if (value == 'report') {
                                      await _openEmployeeReport(
                                        employeeId: doc.id,
                                        data: d,
                                      );
                                    } else if (value == 'disable') {
                                      await _setEmployeeStatus(
                                        employeeId: doc.id,
                                        status: 'disabled',
                                      );
                                    } else if (value == 'enable') {
                                      await _setEmployeeStatus(
                                        employeeId: doc.id,
                                        status: 'active',
                                      );
                                    } else if (value == 'remove') {
                                      await _removeEmployee(
                                        employeeId: doc.id,
                                        employeeName: name,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text(
                                        context.tr('Employee Report'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: isDisabled ? 'enable' : 'disable',
                                      child: Text(
                                        context.tr(
                                          isDisabled
                                              ? 'Enable Access'
                                              : 'Disable Access',
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Text(
                                        context.tr('Remove Employee'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          context.tr('No more employees'),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateForm() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateEmployeeScreen()),
    );
  }

  Future<void> _setEmployeeStatus({
    required String employeeId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(employeeId).set({
      'accountStatus': status,
      'updatedAt': DateTime.now().toUtc(),
      if (status == 'disabled') 'accessBlockedAt': DateTime.now().toUtc(),
      if (status == 'active') 'accessBlockedAt': FieldValue.delete(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            status == 'disabled'
                ? 'Employee access disabled.'
                : 'Employee access restored.',
          ),
        ),
      ),
    );
  }

  Future<void> _removeEmployee({
    required String employeeId,
    required String employeeName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Employee')),
        content: Text(
          context.tr(
            'This will remove the employee from active access while keeping moderation history intact.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('users').doc(employeeId).set({
      'role': 'archived_employee',
      'accountStatus': 'removed',
      'removedAt': DateTime.now().toUtc(),
      'updatedAt': DateTime.now().toUtc(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.tr('Employee removed from access.')}: $employeeName',
        ),
      ),
    );
  }

  Future<void> _openAllReport() async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();
    final submissionsSnap = await FirebaseFirestore.instance
        .collectionGroup('submissions')
        .get();

    final statusCountsByEmployee = <String, Map<String, int>>{};
    for (final s in submissionsSnap.docs) {
      final d = s.data();
      final employeeId = (d['contestAdminId'] ?? '').toString();
      if (employeeId.isEmpty) continue;
      final status = (d['status'] ?? 'pending').toString();
      final counts = statusCountsByEmployee.putIfAbsent(
        employeeId,
        () => <String, int>{'approved': 0, 'rejected': 0},
      );
      if (status == 'approved')
        counts['approved'] = (counts['approved'] ?? 0) + 1;
      if (status == 'rejected')
        counts['rejected'] = (counts['rejected'] ?? 0) + 1;
    }

    final rows = usersSnap.docs.map((doc) {
      final d = doc.data();
      final counts = statusCountsByEmployee[doc.id] ?? const <String, int>{};
      return EmployeeSummaryRow(
        name: (d['displayName'] ?? '').toString(),
        email: (d['email'] ?? '').toString(),
        phone: (d['phoneE164'] ?? '').toString(),
        approvedCount: counts['approved'] ?? 0,
        rejectedCount: counts['rejected'] ?? 0,
      );
    }).toList();

    final bytes = await _reportService.buildAllEmployeesReport(rows: rows);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('All Employees Report'),
          bytes: bytes,
          filename: 'all-employees-report.pdf',
        ),
      ),
    );
  }

  Future<void> _openEmployeeReport({
    required String employeeId,
    required Map<String, dynamic> data,
  }) async {
    final submissionsSnap = await FirebaseFirestore.instance
        .collectionGroup('submissions')
        .get();

    final videos = submissionsSnap.docs.where((doc) {
      final d = doc.data();
      return (d['contestAdminId'] ?? '').toString() == employeeId;
    }).toList();
    final approved = videos
        .where((d) => (d.data()['status'] ?? '').toString() == 'approved')
        .length;
    final rejected = videos
        .where((d) => (d.data()['status'] ?? '').toString() == 'rejected')
        .length;

    final contestIds = videos
        .map((d) => (d.data()['contestId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final userIds = videos
        .map((d) => (d.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final contestMap = await _loadNameMap('contests', contestIds, 'title');
    final userMap = await _loadNameMap('users', userIds, 'displayName');

    String dateText(Timestamp? ts) {
      if (ts == null) return '-';
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }

    final videoRows = videos.map((doc) {
      final d = doc.data();
      final contestId = (d['contestId'] ?? '').toString();
      final participantId = (d['userId'] ?? '').toString();
      final status = (d['status'] ?? '').toString();
      final reason = (d['rejectionReason'] ?? '').toString();
      return EmployeeVideoRow(
        contestName: contestMap[contestId] ?? contestId,
        participantName: userMap[participantId] ?? participantId,
        status: status.isEmpty ? 'pending' : status,
        rejectionReason: reason.isEmpty ? '-' : reason,
        createdAtText: dateText(d['createdAt'] as Timestamp?),
      );
    }).toList()..sort((a, b) => b.createdAtText.compareTo(a.createdAtText));

    final bytes = await _reportService.buildSingleEmployeeReport(
      employeeName: (data['displayName'] ?? '').toString(),
      employeeEmail: (data['email'] ?? '').toString(),
      employeePhone: (data['phoneE164'] ?? '').toString(),
      approvedCount: approved,
      rejectedCount: rejected,
      videos: videoRows,
    );

    if (!mounted) return;
    final safeName = (data['displayName'] ?? 'employee')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PdfPreviewScreen(
          title: context.tr('Employee Report'),
          bytes: bytes,
          filename: '$safeName-report.pdf',
        ),
      ),
    );
  }

  Future<Map<String, String>> _loadNameMap(
    String collection,
    List<String> ids,
    String field,
  ) async {
    if (ids.isEmpty) return <String, String>{};
    final map = <String, String>{};
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 10) {
      chunks.add(ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10));
    }
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        map[doc.id] = (doc.data()[field] ?? doc.id).toString();
      }
    }
    return map;
  }
}

class _CreateEmployeeScreen extends StatefulWidget {
  const _CreateEmployeeScreen();

  @override
  State<_CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<_CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneCodeController = TextEditingController(text: '+1');
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneCodeController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Add Employee')),
        backgroundColor: AppColors.deepSpace,
      ),
      body: Stack(
        children: [
          const _SpaceBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('Full name'),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? context.tr('Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.tr('Email'),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return context.tr('Required');
                        }
                        if (!v.contains('@'))
                          return context.tr('Invalid email');
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _phoneCodeController,
                            decoration: InputDecoration(
                              labelText: context.tr('Country code'),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.tr('Required')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: context.tr('Phone number'),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? context.tr('Required')
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: context.tr('Password'),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return context.tr('Required');
                        }
                        if (v.length < 6) {
                          return context.tr('Minimum 6 characters.');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: _saving
                          ? context.tr('Creating...')
                          : context.tr('Create account'),
                      onPressed: _saving ? () {} : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await AuthService().createEmployeeAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nameController.text.trim(),
        phoneCountryCode: _phoneCodeController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Employee created successfully.'))),
      );
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = context.tr('Failed to create employee.');
      if (e.code == 'email-already-in-use') {
        message = context.tr('Email already in use.');
      } else if (e.code == 'weak-password') {
        message = context.tr('Password is too weak.');
      } else if (e.code == 'invalid-email') {
        message = context.tr('Invalid email');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: constraints.maxWidth < 160 ? 24 : 28,
              ),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeMeta extends StatelessWidget {
  const _EmployeeMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      child: Stack(
        children: const [
          Positioned(
            top: -120,
            left: -40,
            child: _GlowOrb(size: 220, color: AppColors.hotPink),
          ),
          Positioned(
            top: 180,
            right: -80,
            child: _GlowOrb(size: 240, color: AppColors.neonGreen),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.5), color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({
    required this.title,
    required this.bytes,
    required this.filename,
  });

  final String title;
  final Uint8List bytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.deepSpace,
        actions: [
          IconButton(
            tooltip: context.tr('Download'),
            onPressed: () =>
                Printing.sharePdf(bytes: bytes, filename: filename),
            icon: const Icon(Icons.download),
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: filename,
      ),
    );
  }
}

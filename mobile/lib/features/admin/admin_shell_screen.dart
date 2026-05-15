import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/auth/session_bridge.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';

// ─────────────────────────────────────────────────────────────────
// Admin Shell — tabs: Pending | Users | Lawyers | Activity
// ─────────────────────────────────────────────────────────────────

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  static const routePath = '/admin';
  static const routeName = 'admin-shell';

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final storage = ref.read(tokenStorageProvider);
    final refreshToken = await storage.getRefreshToken();
    try {
      await ref.read(apiClientProvider).post('/auth/logout', data: {'refreshToken': refreshToken});
    } catch (_) {}
    await storage.clear();
    SessionBridge.notifySessionCleared();
    if (mounted) context.go(WelcomeScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Admin Panel', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('ADMIN', style: GoogleFonts.inter(fontSize: 11, color: AppColors.secondary, letterSpacing: 0.5)),
        ]),
        actions: [
          IconButton(icon: const Icon(LucideIcons.logOut, size: 20), onPressed: _signOut, tooltip: 'Sign out'),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Users'),
            Tab(text: 'Lawyers'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PendingQueueTab(),
          _UsersTab(),
          _LawyersTab(),
          _ActivityTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 1 — Pending lawyer verification queue
// ─────────────────────────────────────────────────────────────────

class _PendingQueueTab extends ConsumerStatefulWidget {
  const _PendingQueueTab();

  @override
  ConsumerState<_PendingQueueTab> createState() => _PendingQueueTabState();
}

class _PendingQueueTabState extends ConsumerState<_PendingQueueTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ref.read(apiClientProvider).get('/admin/queue');
      final list = (resp['data']['items'] as List<dynamic>? ?? []);
      if (mounted) setState(() {
        _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    if (_items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(LucideIcons.checkCircle, size: 48, color: AppColors.onlineGreen),
        const SizedBox(height: 12),
        Text('No pending verifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.secondary)),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _PendingLawyerCard(
          data: _items[i],
          onDecision: _load,
        ),
      ),
    );
  }
}

class _PendingLawyerCard extends ConsumerStatefulWidget {
  const _PendingLawyerCard({required this.data, required this.onDecision});
  final Map<String, dynamic> data;
  final VoidCallback onDecision;

  @override
  ConsumerState<_PendingLawyerCard> createState() => _PendingLawyerCardState();
}

class _PendingLawyerCardState extends ConsumerState<_PendingLawyerCard> {
  bool       _acting       = false;
  Uint8List? _imageBytes;
  bool       _imageLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLicenseBytes();
  }

  Future<void> _loadLicenseBytes() async {
    final lawyerId = widget.data['id'] as String;
    try {
      final dioResp = await ref.read(apiClientProvider).dio.get(
        '/license/$lawyerId/stream',
        options: Options(responseType: ResponseType.bytes),
      );
      if (mounted) {
        setState(() => _imageBytes = Uint8List.fromList((dioResp.data as List<int>)));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('License Image', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(_imageBytes!),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final lawyerId = widget.data['id'] as String;
      await ref.read(apiClientProvider).post('/admin/lawyers/$lawyerId/approve');
      widget.onDecision();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.trim().isEmpty) return;
    setState(() => _acting = true);
    try {
      final lawyerId = widget.data['id'] as String;
      await ref.read(apiClientProvider).post(
        '/admin/lawyers/$lawyerId/reject',
        data: {'reason': reason.trim()},
      );
      widget.onDecision();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<String?> _showRejectDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. License number does not match Bar Council registry.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Reject')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final name   = widget.data['fullName']     as String? ?? 'Unknown';
    final city   = widget.data['city']         as String? ?? '';
    final state  = widget.data['state']        as String? ?? '';
    final licNum = widget.data['licenseNumber'] as String? ?? '—';
    final ts     = DateTime.tryParse(widget.data['createdAt'] as String? ?? '')?.toLocal();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            CircleAvatar(
              radius: 22, backgroundColor: AppColors.surfaceContainerHigh,
              child: Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                '${city.isNotEmpty ? city : ''}${state.isNotEmpty ? ', $state' : ''}',
                style: tt.bodySmall?.copyWith(color: AppColors.secondary),
              ),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
              child: Text('PENDING', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFD97706))),
            ),
          ]),

          const SizedBox(height: 12),
          _InfoRow('License No.', licNum),
          if (ts != null) _InfoRow('Submitted', DateFormat('dd MMM yyyy, HH:mm').format(ts)),

          // License image
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _imageLoading
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  )
                : _imageBytes != null
                    ? GestureDetector(
                        onTap: () => _openFullScreen(context),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.memory(_imageBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(LucideIcons.maximize2, size: 16, color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('No license image uploaded',
                              style: TextStyle(color: AppColors.secondary)),
                        ),
                      ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _acting ? null : _reject,
                icon: const Icon(LucideIcons.xCircle, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _acting ? null : _approve,
                icon: _acting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.checkCircle, size: 16),
                label: Text(_acting ? 'Approving…' : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.onlineGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2 — All registered users
// ─────────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ref.read(apiClientProvider).get('/admin/users');
      final list = (resp['data']['items'] as List<dynamic>? ?? []);
      if (mounted) setState(() {
        _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSuspend(Map<String, dynamic> user) async {
    final isSuspended = user['isSuspended'] as bool? ?? false;
    if (!isSuspended) {
      final reason = await _askReason(context);
      if (reason == null) return;
    }
    final userId = user['id'] as String;
    final api    = ref.read(apiClientProvider);
    try {
      if (isSuspended) {
        await api.post('/admin/users/$userId/unsuspend');
      } else {
        await api.post('/admin/users/$userId/suspend');
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (_, i) => _UserTile(user: _users[i], onToggleSuspend: () => _toggleSuspend(_users[i])),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3 — All lawyers (all statuses)
// ─────────────────────────────────────────────────────────────────

class _LawyersTab extends ConsumerStatefulWidget {
  const _LawyersTab();

  @override
  ConsumerState<_LawyersTab> createState() => _LawyersTabState();
}

class _LawyersTabState extends ConsumerState<_LawyersTab> {
  List<Map<String, dynamic>> _lawyers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ref.read(apiClientProvider).get('/admin/lawyers');
      final list = (resp['data']['items'] as List<dynamic>? ?? []);
      if (mounted) setState(() {
        _lawyers = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _lawyers.length,
        itemBuilder: (_, i) => _LawyerTile(lawyer: _lawyers[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 4 — Activity / Audit log
// ─────────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerStatefulWidget {
  const _ActivityTab();

  @override
  ConsumerState<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends ConsumerState<_ActivityTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await ref.read(apiClientProvider).get('/admin/audit');
      final list = (resp['data']['items'] as List<dynamic>? ?? []);
      if (mounted) setState(() {
        _logs = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    if (_logs.isEmpty) {
      return Center(child: Text('No activity yet.', style: tt.bodyMedium?.copyWith(color: AppColors.secondary)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (_, i) {
          final log    = _logs[i];
          final action = log['action'] as String? ?? '';
          final ts     = DateTime.tryParse(log['createdAt'] as String? ?? '')?.toLocal();
          final notes  = log['notes'] as String?;
          final admin  = log['admin'] as Map<String, dynamic>?;

          IconData icon;
          Color    color;
          switch (action) {
            case 'LAWYER_APPROVED':   icon = LucideIcons.checkCircle; color = AppColors.onlineGreen;          break;
            case 'LAWYER_REJECTED':   icon = LucideIcons.xCircle;     color = AppColors.error;                break;
            case 'USER_SUSPENDED':
            case 'LAWYER_SUSPENDED':  icon = LucideIcons.shieldOff;   color = const Color(0xFFF59E0B);        break;
            case 'USER_UNSUSPENDED':
            case 'LAWYER_UNSUSPENDED':icon = LucideIcons.shield;      color = AppColors.primary;              break;
            default:                  icon = LucideIcons.activity;    color = AppColors.secondary;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_formatAction(action), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                if (admin != null)
                  Text('By: ${admin['fullName'] ?? ''}', style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
                if (notes != null && notes.isNotEmpty)
                  Text('Note: $notes', style: tt.bodySmall?.copyWith(color: AppColors.error)),
                if (ts != null)
                  Text(DateFormat('dd MMM yyyy • HH:mm').format(ts), style: tt.labelSmall?.copyWith(color: AppColors.outline)),
              ])),
            ]),
          );
        },
      ),
    );
  }

  String _formatAction(String action) => switch (action) {
    'LAWYER_APPROVED'    => 'Lawyer Approved',
    'LAWYER_REJECTED'    => 'Lawyer Rejected',
    'USER_SUSPENDED'     => 'User Suspended',
    'USER_UNSUSPENDED'   => 'User Unsuspended',
    'LAWYER_SUSPENDED'   => 'Lawyer Suspended',
    'LAWYER_UNSUSPENDED' => 'Lawyer Unsuspended',
    _                    => action.replaceAll('_', ' ').toLowerCase()
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase()),
  };
}

// ─────────────────────────────────────────────────────────────────
// Shared tile widgets
// ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onToggleSuspend});
  final Map<String, dynamic> user;
  final VoidCallback onToggleSuspend;

  @override
  Widget build(BuildContext context) {
    final tt          = Theme.of(context).textTheme;
    final isSuspended = user['isSuspended'] as bool? ?? false;
    final name        = user['fullName']    as String? ?? 'Unknown';
    final city        = user['city']        as String? ?? '';
    final state       = user['state']       as String? ?? '';
    final ts          = DateTime.tryParse(user['createdAt'] as String? ?? '')?.toLocal();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isSuspended ? AppColors.errorContainer : AppColors.surfaceContainerHigh,
          child: Text(name.isNotEmpty ? name[0] : '?',
              style: TextStyle(fontWeight: FontWeight.w700, color: isSuspended ? AppColors.error : AppColors.onSurface)),
        ),
        title: Text(name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (city.isNotEmpty || state.isNotEmpty)
            Text('${city.isNotEmpty ? city : ''}${state.isNotEmpty ? ', $state' : ''}',
                style: tt.labelSmall?.copyWith(color: AppColors.secondary)),
          if (ts != null)
            Text('Joined ${DateFormat('dd MMM yyyy').format(ts)}',
                style: tt.labelSmall?.copyWith(color: AppColors.outline)),
          if (isSuspended)
            Text('SUSPENDED', style: tt.labelSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
        ]),
        trailing: IconButton(
          tooltip: isSuspended ? 'Unsuspend' : 'Suspend',
          icon: Icon(
            isSuspended ? LucideIcons.shield : LucideIcons.shieldOff,
            size: 18,
            color: isSuspended ? AppColors.onlineGreen : AppColors.error,
          ),
          onPressed: onToggleSuspend,
        ),
      ),
    );
  }
}

class _LawyerTile extends StatelessWidget {
  const _LawyerTile({required this.lawyer});
  final Map<String, dynamic> lawyer;

  @override
  Widget build(BuildContext context) {
    final tt       = Theme.of(context).textTheme;
    final name     = lawyer['fullName']          as String? ?? 'Unknown';
    final status   = lawyer['verificationStatus'] as String? ?? '—';
    final rating   = (lawyer['avgRating']         as num?)?.toDouble() ?? 0.0;
    final consults = lawyer['totalConsultations'] as int? ?? 0;
    final isOnline = lawyer['isOnline']           as bool? ?? false;

    Color statusColor;
    switch (status) {
      case 'APPROVED':       statusColor = AppColors.onlineGreen;           break;
      case 'REJECTED':       statusColor = AppColors.error;                 break;
      case 'PENDING_REVIEW': statusColor = const Color(0xFFF59E0B);         break;
      default:               statusColor = AppColors.secondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceContainerHigh,
            child: Text(name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ),
          if (isOnline)
            Positioned(right: 0, bottom: 0, child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: AppColors.onlineGreen, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            )),
        ]),
        title: Text(name, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.replaceAll('_', ' '),
                style: tt.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          Text('⭐ $rating  •  $consults consultations',
              style: tt.labelSmall?.copyWith(color: AppColors.secondary)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary)),
        Expanded(
          child: Text(value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

Future<String?> _askReason(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Suspension reason'),
      content: TextField(
        controller: ctrl, autofocus: true, maxLines: 2,
        decoration: const InputDecoration(hintText: 'Reason…', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Suspend')),
      ],
    ),
  );
}

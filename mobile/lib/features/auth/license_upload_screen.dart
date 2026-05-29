import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jerry_app/core/auth/session_bridge.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/features/shell/lawyer_shell_screen.dart';

// ── License Upload ────────────────────────────────────────────────

class LicenseUploadScreen extends ConsumerStatefulWidget {
  const LicenseUploadScreen({super.key});

  static const routePath = '/license-upload';
  static const routeName = 'license-upload';

  @override
  ConsumerState<LicenseUploadScreen> createState() => _LicenseUploadScreenState();
}

class _LicenseUploadScreenState extends ConsumerState<LicenseUploadScreen> {
  final _licenseNumber = TextEditingController();
  XFile? _file;
  bool   _loading = false;
  int?   _fileSizeKb;

  @override
  void dispose() {
    _licenseNumber.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _file = picked;
        _fileSizeKb = (bytes.lengthInBytes / 1024).round();
      });
    }
  }

  Future<void> _submit() async {
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your license document.')));
      return;
    }
    if (_licenseNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your license number.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await _file!.readAsBytes();
      final ext   = _file!.name.split('.').last.toLowerCase();
      final mime  = ext == 'pdf' ? 'application/pdf' : ext == 'jpg' ? 'image/jpeg' : 'image/$ext';

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: _file!.name,
          contentType: DioMediaType.parse(mime),
        ),
        'licenseNumber': _licenseNumber.text.trim(),
      });

      await ref.read(apiClientProvider).postForm('/license/upload', formData);

      if (!mounted) return;
      context.go(UnderReviewScreen.routePath, extra: 'PENDING_REVIEW');
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Upload failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt      = Theme.of(context).textTheme;
    final hasFile = _file != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Verify your practice',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(
            'Upload your\nBar Council certificate',
            style: GoogleFonts.libreBaskerville(
              fontSize: 28, fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic, color: AppColors.onSurface, height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our team verifies credentials within 24–48 hours. This screen updates automatically once reviewed.',
            style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Upload area
          GestureDetector(
            onTap: _pickFile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 180,
              decoration: BoxDecoration(
                color: hasFile ? AppColors.surfaceContainerLow : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFile ? AppColors.onSurface : AppColors.outlineVariant,
                  width: hasFile ? 1.5 : 1,
                ),
              ),
              child: hasFile
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(LucideIcons.fileCheck, size: 40, color: AppColors.onSurface),
                      const SizedBox(height: 12),
                      Text(_file!.name,
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (_fileSizeKb != null)
                        Text('$_fileSizeKb KB',
                            style: tt.labelSmall?.copyWith(color: AppColors.secondary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() { _file = null; _fileSizeKb = null; }),
                        child: Text('Remove',
                            style: tt.bodySmall?.copyWith(
                                color: AppColors.secondary, decoration: TextDecoration.underline)),
                      ),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(LucideIcons.uploadCloud, size: 40, color: AppColors.secondary),
                      const SizedBox(height: 12),
                      Text('Tap to upload',
                          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      const SizedBox(height: 4),
                      Text('JPG or PNG · max 5 MB',
                          style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
                    ]),
            ),
          ),

          const SizedBox(height: 24),

          // License number field
          Text('Bar Council registration number',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.3, color: AppColors.secondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _licenseNumber,
            style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'e.g. MH/12345/2020',
              hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
              filled: true, fillColor: AppColors.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.onSurface, width: 1.5)),
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Uploading…' : 'Submit for Review'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Under Review — polls GET /lawyers/me for status changes ──────

class UnderReviewScreen extends ConsumerStatefulWidget {
  const UnderReviewScreen({super.key, this.status});
  final String? status;

  static const routePath = '/under-review';
  static const routeName = 'under-review';

  @override
  ConsumerState<UnderReviewScreen> createState() => _UnderReviewScreenState();
}

class _UnderReviewScreenState extends ConsumerState<UnderReviewScreen> {
  late String? _status;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startPolling());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final api  = ref.read(apiClientProvider);
      final resp = await api.get('/lawyers/me');
      final data = resp['data'] as Map<String, dynamic>;
      final newStatus = data['verificationStatus'] as String?;
      if (newStatus == null || !mounted) return;
      if (newStatus == 'APPROVED') {
        _pollTimer?.cancel();
        context.go(LawyerShellScreen.routePath);
      } else if (newStatus != _status) {
        setState(() => _status = newStatus);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tt         = Theme.of(context).textTheme;
    final isRejected = _status == 'REJECTED';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: isRejected ? AppColors.errorContainer : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isRejected ? LucideIcons.xCircle : LucideIcons.clock,
                  size: 30,
                  color: isRejected ? AppColors.error : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                isRejected ? 'Application\nRejected' : 'Review in\nProgress',
                style: GoogleFonts.libreBaskerville(
                  fontSize: 32, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic, color: AppColors.onSurface, height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isRejected
                    ? 'Your license could not be verified. Please re-upload a valid Bar Council registration certificate.'
                    : 'Our team is verifying your credentials. This screen updates automatically once reviewed.',
                style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.6),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: isRejected ? AppColors.error : const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isRejected ? 'REJECTED — RE-UPLOAD REQUIRED' : 'PENDING ADMIN REVIEW',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 0.8, color: AppColors.secondary),
                    ),
                  ),
                  if (!isRejected) ...[
                    Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                            color: AppColors.onlineGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('Live', style: tt.labelSmall?.copyWith(color: AppColors.onlineGreen)),
                  ],
                ]),
              ),
              const Spacer(),
              if (isRejected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go(LicenseUploadScreen.routePath),
                    icon: const Icon(LucideIcons.uploadCloud, size: 18),
                    label: const Text('Re-upload License'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    _pollTimer?.cancel();
                    final api      = ref.read(apiClientProvider);
                    final storage  = ref.read(tokenStorageProvider);
                    final refresh  = await storage.getRefreshToken();
                    final deviceId = await storage.getDeviceId();
                    // Drop FCM registration for this device first.
                    if (deviceId != null) {
                      try { await api.delete('/users/me/fcm', data: {'deviceId': deviceId}); } catch (_) {}
                    }
                    if (refresh != null) {
                      try {
                        await api.post('/auth/logout', data: {'refreshToken': refresh});
                      } catch (_) {}
                    }
                    await storage.clear();
                    SessionBridge.notifySessionCleared();
                    if (context.mounted) context.go(WelcomeScreen.routePath);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurface,
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/auth/license_upload_screen.dart';
import 'package:jerry_app/features/shell/user_shell_screen.dart';

class OtpArgs {
  const OtpArgs({
    required this.email,
    required this.role,
    required this.fullName,
    this.language = 'English',
    this.city     = '',
    this.state    = '',
  });
  final String email;
  final String role;
  final String fullName;
  final String language;
  final String city;
  final String state;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  static const routePath = '/otp';
  static const routeName = 'otp';

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());
  bool  _loading     = false;
  int   _countdown   = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown == 0) { t.cancel(); return; }
      setState(() => _countdown--);
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 6 && RegExp(r'^\d{6}$').hasMatch(value)) {
      for (int i = 0; i < 6; i++) { _controllers[i].text = value[i]; }
      _focusNodes[5].requestFocus();
      setState(() {});
      return;
    }
    if (value.length > 1) _controllers[index].text = value.characters.last;
    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() => _loading = true);
    try {
      final api     = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);

      final resp = await api.post('/auth/verify-otp', data: {
        'email': widget.args.email,
        'otp':   _otp,
      });

      final data    = resp['data'] as Map<String, dynamic>;
      final user    = data['user'] as Map<String, dynamic>;
      final userId  = user['id'] as String;
      final role    = user['role'] as String;

      await storage.saveTokens(
        accessToken:  data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        role:         role,
        userId:       userId,
      );

      // Register FCM token now that we have credentials
      NotificationService.getFcmToken().then((fcmToken) async {
        if (fcmToken == null) return;
        final deviceId = await storage.getOrCreateDeviceId();
        try {
          await ref.read(apiClientProvider).post('/users/me/fcm',
              data: {'fcmToken': fcmToken, 'deviceId': deviceId});
        } catch (_) {}
      });

      if (!mounted) return;
      if (role == 'LAWYER') {
        context.go(LicenseUploadScreen.routePath);
      } else {
        context.go(UserShellScreen.routePath);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Verification failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    _startCountdown();
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
    try {
      await ref.read(apiClientProvider).post('/auth/resend-otp', data: {
        'email': widget.args.email,
      });
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP sent to your email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt       = Theme.of(context).textTheme;
    final otpFilled = _otp.length == 6;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.mail, size: 26, color: AppColors.onSurface),
              ),
              const SizedBox(height: 24),
              Text(
                'Check your email',
                style: GoogleFonts.libreBaskerville(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: widget.args.email,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _controllers[i],
                  focusNode:  _focusNodes[i],
                  onChanged:  (v) => _onDigitChanged(i, v),
                  onKeyEvent: (e) => _onKeyEvent(i, e),
                )),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (otpFilled && !_loading) ? _verify : null,
                  child: Text(_loading ? 'Verifying…' : 'Verify'),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: _countdown > 0
                    ? Text(
                        'Resend in 0:${_countdown.toString().padLeft(2, '0')}',
                        style: tt.bodySmall?.copyWith(color: AppColors.outline),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: Text(
                          'Resend OTP',
                          style: tt.bodySmall?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: Text('Change email', style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  final _kbNode = FocusNode();

  @override
  void dispose() {
    _kbNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48, height: 56,
      child: KeyboardListener(
        focusNode: _kbNode,
        onKeyEvent: widget.onKeyEvent,
        child: TextField(
          controller: widget.controller, focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.surfaceContainerLowest,
            contentPadding: EdgeInsets.zero,
            border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.onSurface, width: 2)),
          ),
        ),
      ),
    );
  }
}

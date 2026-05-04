import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/auth/license_upload_screen.dart';
import 'package:jerry_app/features/shell/lawyer_shell_screen.dart';
import 'package:jerry_app/features/shell/user_shell_screen.dart';

class EmailPhoneOtpArgs {
  const EmailPhoneOtpArgs({
    required this.email,
    this.phone,
    this.fullName,
    this.role,
    this.language = 'English',
    this.city = '',
    this.state = '',
  });
  final String email;
  final String? phone;
  final String? fullName;
  final String? role;
  final String language;
  final String city;
  final String state;

  bool get isSignup => fullName != null;
}

class EmailPhoneOtpScreen extends ConsumerStatefulWidget {
  const EmailPhoneOtpScreen({super.key, required this.args});

  static const routePath = '/email-phone-otp';
  static const routeName = 'email-phone-otp';

  final EmailPhoneOtpArgs args;

  @override
  ConsumerState<EmailPhoneOtpScreen> createState() => _EmailPhoneOtpScreenState();
}

class _EmailPhoneOtpScreenState extends ConsumerState<EmailPhoneOtpScreen> {
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
      final supabase = ref.read(supabaseProvider);

      final res = await supabase.auth.verifyOTP(
        email: widget.args.email,
        token: _otp,
        type:  OtpType.email,
      );

      final user = res.user;
      if (user == null) throw const AuthException('Verification failed');

      if (widget.args.isSignup) {
        final role = widget.args.role ?? 'USER';

        // Set role in auth metadata so future logins can read it
        await supabase.auth.updateUser(UserAttributes(data: {
          'role':      role,
          'full_name': widget.args.fullName ?? '',
        }));

        await supabase.from('profiles').upsert(<String, dynamic>{
          'id':                 user.id,
          'role':               role,
          'full_name':          widget.args.fullName ?? '',
          'preferred_language': widget.args.language,
          if ((widget.args.phone ?? '').isNotEmpty) 'phone': widget.args.phone,
          if (widget.args.city.isNotEmpty)  'city':  widget.args.city,
          if (widget.args.state.isNotEmpty) 'state': widget.args.state,
        });

        if (role == 'LAWYER') {
          await supabase.from('lawyer_profiles').upsert(<String, dynamic>{'id': user.id});
        }
      }

      final role = widget.args.role ??
          user.userMetadata?['role'] as String? ?? 'USER';

      await ref.read(tokenStorageProvider).saveSession(
        accessToken: res.session?.accessToken ?? '',
        role:        role,
        userId:      user.id,
      );

      if (!mounted) return;

      if (role == 'LAWYER') {
        final data = await supabase
            .from('lawyer_profiles')
            .select('verification_status')
            .eq('id', user.id)
            .maybeSingle();
        final status = data?['verification_status'] as String? ?? 'PENDING_UPLOAD';
        if (!mounted) return;
        if (status == 'APPROVED') {
          context.go(LawyerShellScreen.routePath);
        } else if (status == 'PENDING_UPLOAD') {
          context.go(LicenseUploadScreen.routePath);
        } else {
          context.go(UnderReviewScreen.routePath, extra: status);
        }
      } else {
        context.go(UserShellScreen.routePath);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      await ref.read(supabaseProvider).auth.signInWithOtp(
        email: widget.args.email,
      );
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
        child: SingleChildScrollView(
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
                style: GoogleFonts.libreBaskerville(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: tt.bodyMedium?.copyWith(color: AppColors.secondary, height: 1.5),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: widget.args.email,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.onSurface),
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
                  child: Text(
                    'Change email',
                    style: tt.bodySmall?.copyWith(color: AppColors.secondary),
                  ),
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

// ── OTP box (stateful to avoid FocusNode leak) ────────────────────────────────

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
          controller: widget.controller,
          focusNode:  widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface),
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

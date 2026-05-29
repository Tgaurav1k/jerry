import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/config/env.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/admin/admin_shell_screen.dart';
import 'package:jerry_app/features/auth/license_upload_screen.dart';
import 'package:jerry_app/features/auth/signup_screen.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/features/shell/lawyer_shell_screen.dart';
import 'package:jerry_app/features/shell/user_shell_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.initialIntent});
  final String? initialIntent;

  static const routePath = '/login';
  static const routeName = 'login';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  String _role = 'USER';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final intent = widget.initialIntent;
    if (intent == 'admin') {
      _role = 'ADMIN';
      _email.text    = Env.superadminEmail;
      _password.text = Env.superadminPassword;
    } else if (intent == 'lawyer' && Env.demoLawyerEmail.isNotEmpty) {
      _role = 'LAWYER';
      _email.text    = Env.demoLawyerEmail;
      _password.text = Env.demoLawyerPassword;
    } else if (Env.demoUserEmail.isNotEmpty) {
      _email.text    = Env.demoUserEmail;
      _password.text = Env.demoUserPassword;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter email and password')));
      return;
    }

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);

      final resp = await api.post('/auth/login', data: {
        'email': email,
        'password': password,
        'role': _role,
      });

      final data = resp['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      final role = user['role'] as String;
      final userId = user['id'] as String;

      await storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        role: role,
        userId: userId,
      );

      ref.read(socketServiceProvider).disconnect();
      ref.invalidate(chatProvider);

      // Register FCM token
      final fcmToken = await NotificationService.getFcmToken();
      final deviceId = await storage.getDeviceId() ?? userId;
      await storage.saveDeviceId(deviceId);
      if (fcmToken != null) {
        try {
          await api.post('/users/me/fcm', data: {
            'fcmToken': fcmToken,
            'deviceId': deviceId,
          });
        } catch (_) {}
      }

      if (!mounted) return;
      _navigateByRole(role, user);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigateByRole(String role, Map<String, dynamic> user) {
    if (role == 'ADMIN') {
      context.go(AdminShellScreen.routePath);
    } else if (role == 'LAWYER') {
      final status = user['verificationStatus'] as String? ?? 'PENDING_UPLOAD';
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
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.go(WelcomeScreen.routePath),
        ),
        title: Text('Sign in',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Text('Welcome back',
              style: GoogleFonts.libreBaskerville(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic, color: AppColors.onSurface)),
          const SizedBox(height: 24),
          _field(controller: _email, hint: 'Email address',
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          _field(controller: _password, hint: 'Password', obscureText: true),
          const SizedBox(height: 16),
          // Role selector
          Row(
            children: [
              Text('Sign in as:', style: tt.bodySmall?.copyWith(color: AppColors.secondary)),
              const SizedBox(width: 12),
              _RoleChip(label: 'Client', value: 'USER', group: _role,
                  onTap: () => setState(() {
                    _role = 'USER';
                    // Auto-fill demo client credentials when the user is on
                    // an empty field or had a different demo set. Don't
                    // clobber a manually-typed email.
                    if (_email.text.isEmpty ||
                        _email.text == Env.demoLawyerEmail ||
                        _email.text == Env.superadminEmail) {
                      _email.text = Env.demoUserEmail;
                      _password.text = Env.demoUserPassword;
                    }
                  })),
              const SizedBox(width: 8),
              _RoleChip(label: 'Lawyer', value: 'LAWYER', group: _role,
                  onTap: () => setState(() {
                    _role = 'LAWYER';
                    // Same pattern — pre-fill demo lawyer (jerry) credentials
                    // so the demo flow is one-tap.
                    if (_email.text.isEmpty ||
                        _email.text == Env.demoUserEmail ||
                        _email.text == Env.superadminEmail) {
                      _email.text = Env.demoLawyerEmail;
                      _password.text = Env.demoLawyerPassword;
                    }
                  })),
              const SizedBox(width: 8),
              _RoleChip(label: 'Admin', value: 'ADMIN', group: _role,
                  onTap: () => setState(() {
                    _role = 'ADMIN';
                    if (_email.text.isEmpty || _email.text == Env.demoUserEmail || _email.text == Env.demoLawyerEmail) {
                      _email.text = Env.superadminEmail;
                      _password.text = Env.superadminPassword;
                    }
                  })),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              child: Text(_loading ? 'Signing in…' : 'Sign in'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Center(child: GestureDetector(
            onTap: () => context.push(SignupScreen.routePath),
            child: RichText(text: TextSpan(
              style: tt.bodySmall?.copyWith(color: AppColors.secondary),
              children: [
                const TextSpan(text: "Don't have an account? "),
                const TextSpan(text: 'Sign up',
                    style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
              ],
            )),
          )),
        ],
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.value,
    required this.group,
    required this.onTap,
  });
  final String label;
  final String value;
  final String group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.onSurface : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.onSurface : AppColors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.surface : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

// ── Field helper ──────────────────────────────────────────────────────────────

Widget _field({
  required TextEditingController controller,
  required String hint,
  TextInputType? keyboardType,
  bool obscureText = false,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    style: const TextStyle(fontSize: 15, color: AppColors.onSurface),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.outline, fontSize: 14),
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineVariant)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.onSurface, width: 1.5)),
    ),
  );
}

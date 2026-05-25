import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/admin/admin_shell_screen.dart';
import 'package:jerry_app/features/auth/license_upload_screen.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/features/shell/lawyer_shell_screen.dart';
import 'package:jerry_app/features/shell/user_shell_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const routePath = '/';
  static const routeName = 'splash';

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Hard ceiling on the splash. If anything (storage, network) takes longer
  /// than this, fall back to Welcome so the user never sits on the logo.
  static const Duration _maxSplash = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Shorter intro so the UI feels responsive on real devices.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      // Race _navigate against a fallback to Welcome. Whichever wins, route.
      await _navigate().timeout(_maxSplash, onTimeout: () {
        if (mounted) context.go(WelcomeScreen.routePath);
      });
    });
  }

  Future<void> _registerFcm() async {
    try {
      final storage  = ref.read(tokenStorageProvider);
      final fcmToken = await NotificationService.getFcmToken();
      if (fcmToken == null) return;
      final deviceId = await storage.getOrCreateDeviceId();
      await ref.read(apiClientProvider).post('/users/me/fcm',
          data: {'fcmToken': fcmToken, 'deviceId': deviceId});
    } catch (_) {}
  }

  /// Reads token + role with defensive try/catch. flutter_secure_storage
  /// can throw on Android after uninstall/reinstall when the AndroidKeyStore
  /// entry is gone but the encrypted blob in shared prefs is still there.
  Future<({String? token, String? role})> _readSession() async {
    final storage = ref.read(tokenStorageProvider);
    try {
      final token = await storage.getAccessToken();
      final role  = await storage.getRole();
      return (token: token, role: role);
    } catch (_) {
      // Wipe whatever's in storage so the next launch starts clean.
      try { await storage.clear(); } catch (_) {}
      return (token: null, role: null);
    }
  }

  Future<void> _navigate() async {
    final session = await _readSession();
    final token = session.token;
    final role  = session.role;

    if (token == null || token.isEmpty || role == null) {
      if (mounted) context.go(WelcomeScreen.routePath);
      return;
    }

    _registerFcm();

    if (role == 'ADMIN') {
      if (mounted) context.go(AdminShellScreen.routePath);
      return;
    }

    if (role == 'LAWYER') {
      try {
        final api  = ref.read(apiClientProvider);
        // Bounded so a slow / cold-starting backend never stalls the splash.
        final resp = await api.get('/lawyers/me')
            .timeout(const Duration(seconds: 5));
        final data = resp['data'] as Map<String, dynamic>;
        final status = data['verificationStatus'] as String? ?? 'PENDING_UPLOAD';

        if (!mounted) return;
        if (status == 'APPROVED') {
          context.go(LawyerShellScreen.routePath);
        } else if (status == 'PENDING_UPLOAD') {
          context.go(LicenseUploadScreen.routePath);
        } else {
          context.go(UnderReviewScreen.routePath, extra: status);
        }
      } catch (_) {
        // Network / timeout / 401: fall back to LicenseUpload (lawyer's
        // verification-aware first screen). Worst case they re-login.
        if (mounted) context.go(LicenseUploadScreen.routePath);
      }
    } else {
      if (mounted) context.go(UserShellScreen.routePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/app_icon.png', width: 120, height: 120),
            ),
            const SizedBox(height: 20),
            Text(
              'jerry',
              style: GoogleFonts.libreBaskerville(
                fontSize: 32, fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic, color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Legal help, instantly',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.darkTextMuted, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

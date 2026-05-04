import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jerry_app/features/admin/admin_shell_screen.dart';
import 'package:jerry_app/features/auth/license_upload_screen.dart';
import 'package:jerry_app/features/auth/login_screen.dart';
import 'package:jerry_app/features/auth/otp_screen.dart';
import 'package:jerry_app/features/auth/signup_screen.dart';
import 'package:jerry_app/features/call/video_call_screen.dart';
import 'package:jerry_app/features/chat/chat_thread_screen.dart';
import 'package:jerry_app/features/chat/chats_list_screen.dart';
import 'package:jerry_app/features/lawyers/lawyer_detail_screen.dart';
import 'package:jerry_app/features/lawyers/lawyer_models.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/features/shell/lawyer_shell_screen.dart';
import 'package:jerry_app/features/shell/user_shell_screen.dart';
import 'package:jerry_app/features/splash/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: SplashScreen.routePath,
    routes: [
      GoRoute(
        path: SplashScreen.routePath,
        name: SplashScreen.routeName,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: WelcomeScreen.routePath,
        name: WelcomeScreen.routeName,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: LoginScreen.routePath,
        name: LoginScreen.routeName,
        builder: (_, state) => LoginScreen(initialIntent: state.uri.queryParameters['intent']),
      ),
      GoRoute(
        path: SignupScreen.routePath,
        name: SignupScreen.routeName,
        builder: (_, state) => SignupScreen(
          initialRole:   state.uri.queryParameters['role'],
          initialMethod: state.extra as String?,   // 'phone' → open phone tab
        ),
      ),
      GoRoute(
        path: OtpScreen.routePath,
        name: OtpScreen.routeName,
        builder: (_, state) {
          final args = state.extra;
          if (args is! OtpArgs) return const Scaffold(body: Center(child: Text('Missing OTP args')));
          return OtpScreen(args: args);
        },
      ),
      GoRoute(
        path: LicenseUploadScreen.routePath,
        name: LicenseUploadScreen.routeName,
        builder: (_, _) => const LicenseUploadScreen(),
      ),
      GoRoute(
        path: UnderReviewScreen.routePath,
        name: UnderReviewScreen.routeName,
        builder: (_, state) => UnderReviewScreen(status: state.extra as String?),
      ),
      GoRoute(
        path: AdminShellScreen.routePath,
        name: AdminShellScreen.routeName,
        builder: (_, _) => const AdminShellScreen(),
      ),
      GoRoute(
        path: UserShellScreen.routePath,
        name: UserShellScreen.routeName,
        builder: (_, _) => const UserShellScreen(),
      ),
      GoRoute(
        path: LawyerShellScreen.routePath,
        name: LawyerShellScreen.routeName,
        builder: (_, _) => const LawyerShellScreen(),
      ),
      GoRoute(
        path: LawyerDetailScreen.routePath,
        name: 'lawyer-detail',
        builder: (_, state) {
          final extra = state.extra;
          if (extra is! LawyerSummary) return const Scaffold(body: Center(child: Text('Missing lawyer')));
          return LawyerDetailScreen(lawyer: extra);
        },
      ),
      GoRoute(
        path: VideoCallScreen.routePath,
        name: VideoCallScreen.routeName,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is! VideoCallArgs) return const Scaffold(body: Center(child: Text('Invalid call')));
          return VideoCallScreen(args: extra);
        },
      ),
      GoRoute(
        path: ChatsListScreen.routePath,
        name: 'chats',
        builder: (_, _) => const ChatsListScreen(),
      ),
      GoRoute(
        path: ChatThreadScreen.routePath,
        name: ChatThreadScreen.routeName,
        builder: (_, state) {
          final args = state.extra;
          if (args is! ChatArgs) return const Scaffold(body: Center(child: Text('Missing chat info')));
          return ChatThreadScreen(args: args);
        },
      ),
    ],
  );
});

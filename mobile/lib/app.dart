import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jerry_app/core/auth/session_bridge.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/router/app_router.dart';
import 'package:jerry_app/core/theme/app_theme.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';

class JerryApp extends ConsumerStatefulWidget {
  const JerryApp({super.key});

  @override
  ConsumerState<JerryApp> createState() => _JerryAppState();
}

class _JerryAppState extends ConsumerState<JerryApp> {
  @override
  void initState() {
    super.initState();
    SessionBridge.register(_resetRealtimeAfterAuthClear);
  }

  @override
  void dispose() {
    SessionBridge.register(null);
    super.dispose();
  }

  void _resetRealtimeAfterAuthClear() {
    ref.read(socketServiceProvider).disconnect();
    ref.invalidate(chatProvider);
    // Without this, clearing the session in the background (a failed token
    // refresh) left the user stranded on an authenticated screen whose every
    // subsequent request 401s — endless spinners / empty lists with no way
    // out. Send them back to Welcome so they can sign in again.
    ref.read(goRouterProvider).go(WelcomeScreen.routePath);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'jerry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}

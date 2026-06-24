import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jerry_app/app.dart';
import 'package:jerry_app/core/call/callkit_service.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/firebase_options.dart';

/// Top-level (must be top-level, not a closure) FCM background handler.
/// Fires for data-only messages when the app is killed or in background.
/// We use this to trigger CallKit's native ringing UI for incoming calls.
@pragma('vm:entry-point')
Future<void> _onFcmBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final data = message.data;

  // Caller hung up / call answered elsewhere while we were still ringing —
  // tear down the native CallKit UI. Without this the phone keeps ringing
  // the full 45 s and the user ends up answering a dead call.
  if (data['type'] == 'call:cancelled') {
    final id = data['consultationId'] as String? ?? '';
    if (id.isNotEmpty) await CallKitService.instance.endCall(id);
    return;
  }

  if (data['type'] != 'call:incoming') return;

  await CallKitService.instance.showIncoming(
    consultationId: data['consultationId'] ?? '',
    callerName:     data['callerName'] ?? 'Caller',
    callType:       data['callType'] ?? 'VIDEO',
    extra: {
      'channelName': data['channelName'] ?? '',
      'token':       data['token'] ?? '',
      'uid':         data['uid'] ?? '0',
      'callerId':    data['callerId'] ?? '',
      'callerRole':  data['callerRole'] ?? '',
      'callType':    data['callType'] ?? 'VIDEO',
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Startup init is wrapped so a single failure (a misconfigured device, a
  // missing .env, a Firebase/notification channel error) can NEVER prevent
  // runApp() from being reached — that would leave the user staring at a
  // permanently blank/black screen with no way out. Each step fails soft and
  // the app still launches; features that depend on the failed step degrade
  // rather than taking the whole app down.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Register the background handler BEFORE runApp so FCM can find it
    // even when the app is launched cold by an incoming-call push.
    FirebaseMessaging.onBackgroundMessage(_onFcmBackgroundMessage);
  } catch (_) {}

  try {
    await NotificationService.init();
  } catch (_) {}

  runApp(const ProviderScope(child: JerryApp()));
}

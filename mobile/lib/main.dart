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
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the background handler BEFORE runApp so FCM can find it
  // even when the app is launched cold by an incoming-call push.
  FirebaseMessaging.onBackgroundMessage(_onFcmBackgroundMessage);

  await NotificationService.init();

  runApp(const ProviderScope(child: JerryApp()));
}

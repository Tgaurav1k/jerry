import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jerry_app/core/call/callkit_service.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // ChatThreadScreen sets this so FCM skips that thread; ChatNotifier uses it for in-app unread.
  static String? currentThreadId;

  // Called after login to get and register FCM token
  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request FCM permission
    await FirebaseMessaging.instance.requestPermission();

    // Android 14+: USE_FULL_SCREEN_INTENT is no longer auto-granted. Without
    // it the CallKit ring shows as a banner instead of the lock-screen
    // takeover. Ask the user once — they'll be sent to Settings to toggle
    // "Display over other apps for incoming calls". Best-effort: older
    // Android / iOS just no-ops.
    try {
      final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (canUse == false) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (_) {
      // Method missing on iOS or older plugin builds — ignore.
    }

    // Foreground FCM router.
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final type = data['type'] as String?;

      // Incoming call: bridge to the native CallKit ring even though we're
      // foregrounded — the live socket might not be connected yet (e.g. user is
      // on Welcome / Login) and we must still ring like WhatsApp.
      if (type == 'call:incoming') {
        CallKitService.instance.showIncoming(
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
        return;
      }

      if (type == 'chat:message') {
        // Socket.IO already updates chat UI — don't double-toast.
        return;
      }

      final notification = message.notification;
      if (notification == null) return;

      final threadId = data['threadId'] as String?;
      if (threadId != null && threadId == currentThreadId) return;

      show(
        notification.title ?? 'Jerry',
        notification.body ?? '',
      );
    });
  }

  static Future<void> show(String title, String body) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 % 99999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jerry_chat',
          'Jerry Messages',
          channelDescription: 'Jerry notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Legacy stubs — Socket.IO handles real-time now
  static void listenForMessages(String myId) {}
  static void stopListening() {}
}

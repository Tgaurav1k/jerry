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

  /// Channel ID used for chat notifications. Must match the id used in
  /// [show] below. Created with HIGH importance so Android renders them as
  /// heads-up banners (the WhatsApp-style popup) with sound + vibration.
  static const _chatChannelId   = 'jerry_chat_v2';
  static const _chatChannelName = 'Jerry Messages';

  static Future<void> init() async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+ runtime POST_NOTIFICATIONS permission.
    await androidImpl?.requestNotificationsPermission();

    // ⚡ CRITICAL: explicitly create the notification channel with HIGH
    // importance up front. On Android 8+ the channel's importance is
    // immutable once created — if the first notification fires before a
    // channel exists, Android creates it with default (silent) importance
    // and heads-up banners never appear no matter what `priority: high`
    // we pass later. Using a new channel id (_v2) avoids inheriting a
    // previously-created low-importance channel from older app installs.
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: 'New chat messages from your lawyer or client',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

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
          _chatChannelId,
          _chatChannelName,
          channelDescription: 'New chat messages from your lawyer or client',
          importance: Importance.high,
          priority: Priority.high,
          // Make sure the heads-up banner pops over whatever screen the user
          // is on (not just buried in the tray).
          ticker: 'New message',
          playSound: true,
          enableVibration: true,
          enableLights: true,
          // Show full title+body even on the lock screen.
          visibility: NotificationVisibility.public,
          // Default category 'msg' tells Android this is a chat — gets the
          // preferential heads-up treatment.
          category: AndroidNotificationCategory.message,
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

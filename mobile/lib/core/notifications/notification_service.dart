import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // ChatThreadScreen sets this so we skip notifications for the open thread
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

    // Show foreground notifications as local notifications
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final threadId = message.data['threadId'] as String?;
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

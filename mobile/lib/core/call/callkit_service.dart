import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Wraps flutter_callkit_incoming so the rest of the app talks to one surface.
///
/// Flow:
///   1. FCM data-only message arrives -> background isolate fires
///      [showIncoming] with the payload from `notification.service.ts`.
///   2. Android shows the native full-screen ringing UI even from cold start.
///   3. User taps Accept/Decline -> [onEvent] fires -> we resolve the
///      pending future so the foreground UI can route to VideoCallScreen
///      or post `/call/:id/reject`.
class CallKitService {
  CallKitService._();
  static final instance = CallKitService._();

  StreamSubscription<CallEvent?>? _eventSub;

  /// Listen for accept/decline taps on the native UI. Call once from app
  /// bootstrap, before the user logs in.
  void registerEventListener(
      Future<void> Function(CallEvent event) handler) {
    _eventSub?.cancel();
    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      handler(event);
    });
  }

  Future<void> showIncoming({
    required String consultationId,
    required String callerName,
    required String callType, // 'VIDEO' | 'VOICE'
    Map<String, String> extra = const {},
  }) async {
    final params = CallKitParams(
      id:        consultationId,
      nameCaller: callerName,
      appName:   'Jerry',
      type:      callType == 'VIDEO' ? 1 : 0,
      duration:  45000, // matches IncomingCallOverlay timeout
      textAccept:  'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback:   false,
        subtitle:         'Missed call',
      ),
      android: const AndroidParams(
        isCustomNotification:  true,
        isShowLogo:            false,
        ringtonePath:          'system_ringtone_default',
        backgroundColor:       '#0955fa',
        actionColor:           '#4CAF50',
        incomingCallNotificationChannelName: 'Incoming Calls',
        missedCallNotificationChannelName:   'Missed Calls',
      ),
      ios: const IOSParams(
        iconName:          'CallKitLogo',
        handleType:        'generic',
        supportsVideo:     true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF:    true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
      extra: extra,
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String consultationId) =>
      FlutterCallkitIncoming.endCall(consultationId);

  Future<void> endAll() => FlutterCallkitIncoming.endAllCalls();
}

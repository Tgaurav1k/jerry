import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/call/callkit_service.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/call/video_call_screen.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/chat/chats_list_screen.dart';
import 'package:jerry_app/features/home/history_placeholder_screen.dart';
import 'package:jerry_app/features/home/lawyer_home_screen.dart';
import 'package:jerry_app/features/home/profile_placeholder_screen.dart';
import 'package:jerry_app/shared/widgets/floating_glass_nav.dart';
import 'package:jerry_app/shared/widgets/incoming_call_overlay.dart';

class LawyerShellScreen extends ConsumerStatefulWidget {
  const LawyerShellScreen({super.key});

  static const routePath = '/lawyer';
  static const routeName = 'lawyer-shell';

  @override
  ConsumerState<LawyerShellScreen> createState() => _LawyerShellScreenState();
}

class _LawyerShellScreenState extends ConsumerState<LawyerShellScreen> {
  int _index = 0;
  String _status = 'Connecting…';

  static const _titles = ['Dashboard', 'Chats', 'History', 'Profile'];

  // The consultation currently ringing via the in-app overlay, and its
  // route — kept so call:ended / call:rejected / call:cancelled can pop the
  // overlay when the caller hangs up before we answer. Previously nothing
  // dismissed it: the phone kept "ringing" a dead call and accepting it
  // failed with a Conflict error.
  String? _ringingCallId;
  Route<void>? _ringRoute;

  /// Guards against the same accept being processed twice (live event +
  /// cold-start recovery racing each other).
  final Set<String> _handledAccepts = {};

  @override
  void initState() {
    super.initState();
    NotificationService.onCallCancelled = _dismissIncomingRing;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
      _registerCallKit();
    });
  }

  void _onCallTornDown(dynamic raw) {
    if (raw is! Map) return;
    final id = raw['consultationId'] as String? ?? '';
    if (id.isNotEmpty) _dismissIncomingRing(id);
  }

  /// Tears down the ringing UI (in-app overlay + native CallKit notification)
  /// for [consultationId] if it is the one currently ringing.
  void _dismissIncomingRing(String consultationId) {
    CallKitService.instance.endCall(consultationId);
    CallKitService.instance.clearRinging(consultationId);
    if (_ringingCallId != consultationId) return;
    _ringingCallId = null;
    final route = _ringRoute;
    _ringRoute = null;
    if (route != null && route.isActive && mounted) {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _registerCallKit() {
    CallKitService.instance.registerEventListener((event) async {
      if (!mounted) return;
      final body = event.body as Map?;
      final extra = (body?['extra'] as Map?) ?? {};
      final consultationId = (body?['id'] ?? '').toString();
      if (consultationId.isEmpty) return;

      switch (event.event) {
        case Event.actionCallAccept:
          await _onCallKitAccept(
            consultationId: consultationId,
            callerId:       (extra['callerId'] ?? '').toString(),
            callerRole:     (extra['callerRole'] ?? 'USER').toString(),
            callerName:     (body?['nameCaller'] ?? 'Client').toString(),
            callType:       (extra['callType'] ?? 'VIDEO').toString(),
            channelName:    (extra['channelName'] ?? '').toString(),
            token:          (extra['token'] ?? '').toString(),
            uid:            int.tryParse((extra['uid'] ?? '0').toString()) ?? 0,
          );
          break;
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          CallKitService.instance.clearRinging(consultationId);
          try {
            await ref.read(apiClientProvider)
                .post('/call/$consultationId/reject');
          } catch (_) {}
          break;
        default:
          break;
      }
    });

    _resumePendingCallKitAccept();
  }

  /// Cold-start path: the lawyer tapped Accept on the native ring while the
  /// app was killed. By the time this shell mounts and attaches the CallKit
  /// listener, that accept event is long gone — the app would just open to
  /// the dashboard and the call dies. Recover it from the plugin's
  /// active-calls list instead.
  Future<void> _resumePendingCallKitAccept() async {
    final pending = await CallKitService.instance.pendingAcceptedCalls();
    if (!mounted || pending.isEmpty) return;
    final call  = pending.first;
    final extra = Map<String, dynamic>.from((call['extra'] as Map?) ?? {});
    final id    = (call['id'] ?? '').toString();
    if (id.isEmpty) return;
    await _onCallKitAccept(
      consultationId: id,
      callerId:       (extra['callerId'] ?? '').toString(),
      callerRole:     (extra['callerRole'] ?? 'USER').toString(),
      callerName:     (call['nameCaller'] ?? 'Client').toString(),
      callType:       (extra['callType'] ?? 'VIDEO').toString(),
      channelName:    (extra['channelName'] ?? '').toString(),
      token:          (extra['token'] ?? '').toString(),
      uid:            int.tryParse((extra['uid'] ?? '0').toString()) ?? 0,
    );
  }

  Future<void> _onCallKitAccept({
    required String consultationId,
    required String callerId,
    required String callerRole,
    required String callerName,
    required String callType,
    required String channelName,
    required String token,
    required int    uid,
  }) async {
    if (!_handledAccepts.add(consultationId)) return;
    _ringingCallId = null;
    _ringRoute = null;
    CallKitService.instance.clearRinging(consultationId);

    // Dismiss the CallKit native UI immediately. Without this, after the user
    // taps Accept, the native "Ongoing call" notification stays in the
    // foreground and our in-app VideoCallScreen never becomes visible — the
    // call "hides" into a notification the user can never get back to.
    // Our VideoCallScreen + Agora take over the audio session from here.
    await CallKitService.instance.endCall(consultationId);

    try {
      final resp = await ref.read(apiClientProvider)
          .post('/call/$consultationId/accept');
      final d2 = resp['data'] as Map<String, dynamic>;
      if (!mounted) return;

      if (callerId.isNotEmpty) {
        final myId = await ref.read(tokenStorageProvider).getUserId() ?? '';
        if (!mounted) return;
        final threadId = ChatNotifier.computeThreadId(myId, callerId);
        ref.read(chatProvider.notifier).ensureThread(
          threadId: threadId,
          peerId:   callerId,
          peerRole: callerRole,
          peerName: callerName,
        );
        ref.read(chatProvider.notifier).trackCall(consultationId, threadId, callType);
      }

      if (!mounted) return;
      await context.push(
        VideoCallScreen.routePath,
        extra: VideoCallArgs(
          consultationId: consultationId,
          channelId:      d2['agoraChannelName'] as String? ?? channelName,
          token:          d2['agoraToken']       as String? ?? token,
          uid:            (d2['uid'] as num?)?.toInt() ?? uid,
          callType:       callType,
          peerName:       callerName,
        ),
      );
    } catch (e) {
      // Allow a retry if the accept failed for a transient reason.
      _handledAccepts.remove(consultationId);
      // Dismiss the CallKit notification so the lawyer isn't left staring at it.
      await CallKitService.instance.endCall(consultationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')));
    }
  }

  Future<void> _connectSocket() async {
    final api    = ref.read(apiClientProvider);
    final socket = ref.read(socketServiceProvider);

    // Mark lawyer as online
    try {
      await api.post('/lawyers/me/availability', data: {'isOnline': true});
    } catch (_) {}

    final sock = await socket.connect();
    if (sock == null) return;

    sock.on('connect', (_) {
      if (!mounted) return;
      setState(() => _status = 'Connected — waiting for calls');
    });

    sock.on('disconnect', (_) {
      if (!mounted) return;
      setState(() => _status = 'Reconnecting…');
    });

    sock.on('call:incoming', (data) {
      if (!mounted) return;
      final d = Map<String, dynamic>.from(data as Map);
      _onIncomingCall(d);
    });
    // Caller cancelled / call answered elsewhere while we were still ringing.
    sock.on('call:ended',    _onCallTornDown);
    sock.on('call:rejected', _onCallTornDown);

    if (sock.connected) setState(() => _status = 'Connected — waiting for calls');
  }

  Future<void> _onIncomingCall(Map<String, dynamic> data) async {
    if (!mounted) return;

    // Soft-cast: a malformed call:incoming payload (missing/null id) must not
    // throw inside the socket listener — an uncaught error here killed the
    // whole incoming-call flow so the phone never rang.
    final consultationId = data['consultationId'] as String? ?? '';
    if (consultationId.isEmpty) return;

    // The FCM data push delivers this same call to NotificationService, which
    // shows the native CallKit ring. If that path won the race, don't stack
    // the in-app overlay on top — two ringing UIs at once.
    if (!CallKitService.instance.tryBeginRinging(consultationId)) return;

    final callerId       = data['callerId']       as String? ?? '';
    final callType       = data['type']           as String? ?? 'VIDEO';
    final callerName     = data['callerName']     as String? ?? 'Client';
    final channelName    = data['channelName']    as String? ?? '';
    final agoraToken     = data['token']          as String? ?? '';
    final uid            = (data['uid'] as num?)?.toInt() ?? 0;

    // Track the incoming call so call:ended / call:rejected can inject a
    // WhatsApp-style call bubble into the chat thread live — even if we
    // decline or let it time out. Without this, the bubble only appears
    // after the next chat-history reload.
    if (callerId.isNotEmpty) {
      final myId = await ref.read(tokenStorageProvider).getUserId() ?? '';
      if (!mounted) return;
      final threadId = ChatNotifier.computeThreadId(myId, callerId);
      ref.read(chatProvider.notifier).ensureThread(
        threadId: threadId,
        peerId:   callerId,
        peerRole: 'USER',
        peerName: callerName,
      );
      ref.read(chatProvider.notifier).trackCall(consultationId, threadId, callType);
    }

    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim, secAnim) => IncomingCallOverlay(
        callerName: callerName,
        callType:   callType,
        onReject: () async {
          _ringingCallId = null;
          _ringRoute = null;
          Navigator.of(ctx).pop();
          // Also tear down the parallel native CallKit notification — it
          // rings independently and would keep ringing after the decline.
          CallKitService.instance.endCall(consultationId);
          CallKitService.instance.clearRinging(consultationId);
          try {
            await ref.read(apiClientProvider).post('/call/$consultationId/reject');
          } catch (_) {}
        },
        onAccept: () async {
          _ringingCallId = null;
          _ringRoute = null;
          Navigator.of(ctx).pop();
          await _onCallKitAccept(
            consultationId: consultationId,
            callerId:       callerId,
            callerRole:     'USER',
            callerName:     callerName,
            callType:       callType,
            channelName:    channelName,
            token:          agoraToken,
            uid:            uid,
          );
        },
      ),
    );
    _ringingCallId = consultationId;
    _ringRoute = route;
    await Navigator.of(context).push<void>(route);
    // Route popped by any path (accept, decline, external dismissal).
    if (_ringRoute == route) {
      _ringRoute = null;
      _ringingCallId = null;
    }
  }

  @override
  void dispose() {
    if (NotificationService.onCallCancelled == _dismissIncomingRing) {
      NotificationService.onCallCancelled = null;
    }
    final api    = ref.read(apiClientProvider);
    final socket = ref.read(socketServiceProvider);
    api.post('/lawyers/me/availability', data: {'isOnline': false}).ignore();
    socket.socket?.off('call:incoming');
    socket.socket?.off('call:ended',    _onCallTornDown);
    socket.socket?.off('call:rejected', _onCallTornDown);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatUnread = ref.watch(chatProvider.select((s) => s.totalChatUnread));
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBody: true,
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          LawyerDashboardTab(status: _status),
          const ChatsListScreen(embedded: true),
          const HistoryPlaceholderScreen(),
          const ProfilePlaceholderScreen(),
        ],
      ),
      bottomNavigationBar: FloatingGlassBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        tabBadgeCounts: [0, chatUnread, 0, 0],
        items: const [
          FloatingNavItem(LucideIcons.layoutDashboard, 'Home'),
          FloatingNavItem(LucideIcons.messageSquare, 'Chats'),
          FloatingNavItem(LucideIcons.history, 'History'),
          FloatingNavItem(LucideIcons.user, 'Profile'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectSocket());
  }

  Future<void> _connectSocket() async {
    final api    = ref.read(apiClientProvider);
    final socket = ref.read(socketServiceProvider);

    // Mark lawyer as online
    try {
      await api.post('/lawyers/me/availability', data: {'isOnline': true});
    } catch (_) {}

    final sock = await socket.connect();

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

    if (sock.connected) setState(() => _status = 'Connected — waiting for calls');
  }

  Future<void> _onIncomingCall(Map<String, dynamic> data) async {
    if (!mounted) return;

    final consultationId = data['consultationId'] as String;
    final callerId       = data['callerId']       as String? ?? '';
    final callType       = data['type']           as String? ?? 'VIDEO';
    final callerName     = data['callerName']     as String? ?? 'Client';
    final channelName    = data['channelName']    as String? ?? '';
    final agoraToken     = data['token']          as String? ?? '';
    final uid            = (data['uid'] as num?)?.toInt() ?? 0;

    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (ctx, anim, secAnim) => IncomingCallOverlay(
          callerName: callerName,
          callType:   callType,
          onReject: () async {
            Navigator.of(ctx).pop();
            try {
              await ref.read(apiClientProvider).post('/call/$consultationId/reject');
            } catch (_) {}
          },
          onAccept: () async {
            Navigator.of(ctx).pop();
            try {
              final resp = await ref.read(apiClientProvider)
                  .post('/call/$consultationId/accept');
              final d2 = resp['data'] as Map<String, dynamic>;

              if (!mounted) return;

              // Ensure thread + track call so call:ended injects a bubble
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

              await context.push(
                VideoCallScreen.routePath,
                extra: VideoCallArgs(
                  consultationId: consultationId,
                  channelId:      d2['agoraChannelName'] as String? ?? channelName,
                  token:          d2['agoraToken'] as String? ?? agoraToken,
                  uid:            (d2['uid'] as num?)?.toInt() ?? uid,
                  callType:       callType,
                  peerName:       callerName,
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Accept failed: $e')));
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    final api    = ref.read(apiClientProvider);
    final socket = ref.read(socketServiceProvider);
    api.post('/lawyers/me/availability', data: {'isOnline': false}).ignore();
    socket.socket?.off('call:incoming');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

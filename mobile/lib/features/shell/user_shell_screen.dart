import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/auth/session_bridge.dart';
import 'package:jerry_app/core/call/callkit_service.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/call/video_call_screen.dart';
import 'package:jerry_app/features/chat/chats_list_screen.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/home/dark_home_screen.dart';
import 'package:jerry_app/features/home/history_placeholder_screen.dart';
import 'package:jerry_app/features/home/profile_placeholder_screen.dart';
import 'package:jerry_app/features/home/user_home_screen.dart';
import 'package:jerry_app/features/onboarding/welcome_screen.dart';
import 'package:jerry_app/shared/widgets/floating_glass_nav.dart';
import 'package:jerry_app/shared/widgets/incoming_call_overlay.dart';

class UserShellScreen extends ConsumerStatefulWidget {
  const UserShellScreen({super.key});

  static const routePath = '/user';
  static const routeName = 'user-shell';

  @override
  ConsumerState<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends ConsumerState<UserShellScreen> {
  int _index = 0;
  bool _showDirectory = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<UserDiscoverTabState> _discoverKey = GlobalKey<UserDiscoverTabState>();

  bool get _isDarkTab => _index == 0 && !_showDirectory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
      _registerCallKit();
    });
  }

  @override
  void dispose() {
    ref.read(socketServiceProvider).socket?.off('call:incoming');
    super.dispose();
  }

  // ─── Incoming-call handling (lawyer -> client) ───────────────────────────────

  Future<void> _connectSocket() async {
    final sock = await ref.read(socketServiceProvider).connect();
    if (sock == null) return;
    sock.on('call:incoming', (data) {
      if (!mounted) return;
      _onIncomingCall(Map<String, dynamic>.from(data as Map));
    });
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
            callerRole:     (extra['callerRole'] ?? 'LAWYER').toString(),
            callerName:     (body?['nameCaller'] ?? 'Lawyer').toString(),
            callType:       (extra['callType'] ?? 'VIDEO').toString(),
            channelName:    (extra['channelName'] ?? '').toString(),
            token:          (extra['token'] ?? '').toString(),
            uid:            int.tryParse((extra['uid'] ?? '0').toString()) ?? 0,
          );
          break;
        case Event.actionCallDecline:
        case Event.actionCallTimeout:
          try {
            await ref.read(apiClientProvider).post('/call/$consultationId/reject');
          } catch (_) {}
          break;
        default:
          break;
      }
    });
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
    try {
      final resp = await ref.read(apiClientProvider).post('/call/$consultationId/accept');
      final d2   = resp['data'] as Map<String, dynamic>;
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
      // Dismiss the CallKit notification so the user isn't left staring at it.
      await CallKitService.instance.endCall(consultationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')));
    }
  }

  Future<void> _onIncomingCall(Map<String, dynamic> data) async {
    if (!mounted) return;
    final consultationId = data['consultationId'] as String;
    final callerId       = data['callerId']       as String? ?? '';
    final callerRole     = data['callerRole']     as String? ?? 'LAWYER';
    final callType       = data['type']           as String? ?? 'VIDEO';
    final callerName     = data['callerName']     as String? ?? 'Lawyer';
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
        peerRole: callerRole,
        peerName: callerName,
      );
      ref.read(chatProvider.notifier).trackCall(consultationId, threadId, callType);
    }

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
            await _onCallKitAccept(
              consultationId: consultationId,
              callerId:       callerId,
              callerRole:     callerRole,
              callerName:     callerName,
              callType:       callType,
              channelName:    channelName,
              token:          agoraToken,
              uid:            uid,
            );
          },
        ),
      ),
    );
  }

  void _openDirectory() {
    setState(() {
      _showDirectory = true;
    });
  }

  void _backToHome() {
    setState(() {
      _showDirectory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatUnread = ref.watch(chatProvider.select((s) => s.totalChatUnread));
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkTab ? AppColors.darkBg : AppColors.surface,
      extendBody: true,
      drawer: _AppDrawer(
        currentIndex: _index,
        onTabSelected: (i) {
          Navigator.of(context).pop();
          setState(() {
            _index = i;
            if (i != 0) _showDirectory = false;
          });
        },
        onLogout: () async {
          Navigator.of(context).pop();
          final storage = ref.read(tokenStorageProvider);
          final api = ref.read(apiClientProvider);
          final refresh  = await storage.getRefreshToken();
          final deviceId = await storage.getDeviceId();
          // Unregister this device's FCM token first so pushes meant for the
          // just-logged-out identity stop reaching this phone.
          if (deviceId != null) {
            try { await api.delete('/users/me/fcm', data: {'deviceId': deviceId}); } catch (_) {}
          }
          if (refresh != null) {
            try {
              await api.post('/auth/logout', data: {'refreshToken': refresh});
            } catch (_) {}
          }
          await storage.clear();
          SessionBridge.notifySessionCleared();
          if (mounted) context.go(WelcomeScreen.routePath);
        },
      ),
      appBar: AppBar(
        backgroundColor: _isDarkTab ? AppColors.darkBg : Colors.transparent,
        foregroundColor: _isDarkTab ? Colors.white : AppColors.onSurface,
        leading: _showDirectory
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                onPressed: _backToHome,
              )
            : IconButton(
                icon: Icon(Icons.menu, size: 22, color: _isDarkTab ? Colors.white : AppColors.onSurface),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.scale,
              size: 18,
              color: _isDarkTab ? AppColors.gold : AppColors.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              _showDirectory ? 'JERRY' : 'jerry',
              style: _isDarkTab
                  ? GoogleFonts.libreBaskerville(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      color: AppColors.gold,
                    )
                  : GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.onSurface,
                    ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_isDarkTab)
            IconButton(
              icon: Icon(LucideIcons.bell, size: 20, color: AppColors.gold),
              onPressed: () {},
            )
          else if (_index == 0 && _showDirectory) ...[
            IconButton(
              icon: const Icon(LucideIcons.search, size: 20),
              onPressed: () {},
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() { _index = 3; _showDirectory = false; }),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: Icon(LucideIcons.user, size: 16, color: AppColors.secondary),
                ),
              ),
            ),
          ] else if (_index == 1)
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: () {},
            )
          else if (_index == 2 || _index == 3)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: Icon(LucideIcons.user, size: 16, color: AppColors.secondary),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isDarkTab
          ? _DarkBottomNav(
              currentIndex: _index,
              chatUnread: chatUnread,
              onTap: (i) => setState(() {
                _index = i;
                if (i != 0) _showDirectory = false;
              }),
              onAdd: _openDirectory,
            )
          : FloatingGlassBottomNav(
              currentIndex: _showDirectory ? 0 : _index,
              onTap: (i) => setState(() {
                _index = i;
                if (i != 0) _showDirectory = false;
              }),
              // Always pass per-tab unread counts so the red dot/number on
              // the Chats icon is visible even when the user is browsing the
              // lawyer directory (previously hidden in that view — meant new
              // messages went unnoticed until they tapped Home then Chats).
              tabBadgeCounts: [0, chatUnread, 0, 0],
              items: const [
                FloatingNavItem(LucideIcons.home, 'HOME'),
                FloatingNavItem(LucideIcons.messageSquare, 'CHATS'),
                FloatingNavItem(LucideIcons.clock, 'HISTORY'),
                FloatingNavItem(LucideIcons.user, 'PROFILE'),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_index == 0 && _showDirectory) {
      return UserDiscoverTab(key: _discoverKey);
    }
    return IndexedStack(
      index: _index,
      children: [
        DarkHomeScreen(onConsult: _openDirectory),
        const ChatsListScreen(embedded: true),
        const HistoryPlaceholderScreen(),
        const ProfilePlaceholderScreen(),
      ],
    );
  }
}

/// Dark-themed bottom nav for Home tab — matches Stitch with gold accent + button.
class _DarkBottomNav extends StatelessWidget {
  const _DarkBottomNav({
    required this.currentIndex,
    required this.chatUnread,
    required this.onTap,
    required this.onAdd,
  });

  final int currentIndex;
  final int chatUnread;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DarkNavItem(
              icon: LucideIcons.home,
              label: 'HOME',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _DarkNavItem(
              icon: LucideIcons.messageSquare,
              label: 'CHAT',
              selected: currentIndex == 1,
              badgeCount: chatUnread,
              onTap: () => onTap(1),
            ),
            _DarkNavItem(
              icon: LucideIcons.clock,
              label: 'HISTORY',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            // Gold + button
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldLight),
                ),
                child: Icon(Icons.add, size: 22, color: AppColors.darkBg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkNavItem extends StatelessWidget {
  const _DarkNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.gold : AppColors.darkTextMuted,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding: badgeCount > 1
                        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                        : EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: badgeCount > 1 ? 14 : 7,
                      minHeight: badgeCount > 1 ? 12 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(badgeCount > 1 ? 6 : 99),
                      border: Border.all(color: AppColors.darkBg, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: badgeCount > 1
                        ? Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.5,
              color: selected ? AppColors.gold : AppColors.darkTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation drawer.
class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onLogout,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Icon(LucideIcons.scale, size: 22, color: AppColors.onSurface),
                  const SizedBox(width: 10),
                  Text(
                    'JERRY',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceContainerHigh),
            const SizedBox(height: 8),
            _DrawerItem(icon: LucideIcons.home, label: 'Home', selected: currentIndex == 0, onTap: () => onTabSelected(0)),
            _DrawerItem(icon: LucideIcons.messageSquare, label: 'Chats', selected: currentIndex == 1, onTap: () => onTabSelected(1)),
            _DrawerItem(icon: LucideIcons.clock, label: 'History', selected: currentIndex == 2, onTap: () => onTabSelected(2)),
            _DrawerItem(icon: LucideIcons.user, label: 'Profile', selected: currentIndex == 3, onTap: () => onTabSelected(3)),
            const Divider(height: 24, color: AppColors.surfaceContainerHigh),
            _DrawerItem(icon: LucideIcons.info, label: 'About Jerry', onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('jerry — legal help on demand across India.')));
            }),
            _DrawerItem(icon: LucideIcons.helpCircle, label: 'Help & Support', onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support: coming soon.')));
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: Icon(LucideIcons.logOut, size: 18),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text('© 2026 jerry', style: TextStyle(fontSize: 12, color: AppColors.outline)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.selected = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AppColors.onSurface : AppColors.secondary),
                const SizedBox(width: 14),
                Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? AppColors.onSurface : AppColors.secondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

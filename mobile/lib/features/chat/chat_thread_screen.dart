import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/call/video_call_screen.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';
import 'package:jerry_app/features/lawyers/lawyer_detail_screen.dart';
import 'package:jerry_app/features/lawyers/lawyer_models.dart';
import 'package:jerry_app/shared/widgets/rating_modal.dart';

class ChatArgs {
  const ChatArgs({required this.peerId, required this.peerName, this.peerPhotoUrl, this.peerRole = 'LAWYER'});
  final String  peerId;
  final String  peerName;
  final String? peerPhotoUrl;
  final String  peerRole;
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.args});

  static const routePath = '/chat-thread';
  static const routeName = 'chat-thread';

  final ChatArgs args;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input      = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _myId;
  String? _myRole;
  late String _threadId;
  bool _peerOnline = false;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    NotificationService.currentThreadId = null;
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Polls the peer's online flag from /lawyers/:id. Cheap and good enough
  /// for the demo — sub-second freshness isn't required for a presence dot.
  Future<void> _refreshPeerPresence() async {
    if (widget.args.peerRole != 'LAWYER') return;
    try {
      final resp = await ref.read(apiClientProvider).get('/lawyers/${widget.args.peerId}');
      final data = resp['data'] as Map<String, dynamic>?;
      final online = data?['isOnline'] == true;
      if (!mounted || online == _peerOnline) return;
      setState(() => _peerOnline = online);
    } catch (_) {/* ignore — presence is decorative */}
  }

  Future<void> _init() async {
    final storage = ref.read(tokenStorageProvider);
    _myId   = await storage.getUserId();
    _myRole = await storage.getRole();
    if (_myId == null) return;

    _threadId = ChatNotifier.computeThreadId(_myId!, widget.args.peerId);

    ref.read(chatProvider.notifier).ensureThread(
      threadId: _threadId,
      peerId:   widget.args.peerId,
      peerRole: widget.args.peerRole,
      peerName: widget.args.peerName,
    );

    NotificationService.currentThreadId = _threadId;
    ref.read(chatProvider.notifier).clearUnread(_threadId);
    ref.read(chatProvider.notifier).markRead(
      _threadId, widget.args.peerId, widget.args.peerRole);

    // Load persisted message history from backend
    await ref.read(chatProvider.notifier).loadHistory(_threadId);

    // Initial presence pull + refresh every 30s while the screen is open.
    unawaited(_refreshPeerPresence());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshPeerPresence(),
    );

    setState(() {});
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _myId == null) return;
    _input.clear();

    await ref.read(chatProvider.notifier).sendMessage(
      threadId:  _threadId,
      peerId:    widget.args.peerId,
      peerRole:  widget.args.peerRole,
      content:   text,
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  bool _profileLoading = false;
  bool _callLoading    = false;

  Future<void> _startCall(String type) async {
    if (widget.args.peerRole != 'LAWYER') return;
    setState(() => _callLoading = true);
    try {
      final api  = ref.read(apiClientProvider);
      final resp = await api.post('/call/initiate', data: {
        'lawyerId': widget.args.peerId,
        'type':     type,
      });
      final data           = resp['data'] as Map<String, dynamic>;
      final consultationId = data['consultationId'] as String;
      final missed         = data['missed'] as bool? ?? false;

      if (!mounted) return;

      // Backend now only flags `missed` when the lawyer is on another active
      // call. Offline lawyers ring through the normal path and time out
      // server-side after 45s.
      if (missed) {
        ref.read(chatProvider.notifier).addMissedCallBubble(
          threadId: _threadId,
          callType: type,
        );
        final reason = (data['reason'] as String?) ?? 'busy';
        final msg = reason == 'busy'
            ? '${widget.args.peerName} is on another call. They will see a missed call.'
            : '${widget.args.peerName} could not be reached. They will see a missed call.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
        );
        return;
      }

      final channelName    = data['agoraChannelName'] as String? ?? '';
      final agoraToken     = data['agoraToken'] as String? ?? '';
      final uid            = (data['uid'] as num?)?.toInt() ?? 0;
      // Track so call:ended / call:rejected event can inject bubble into this thread
      ref.read(chatProvider.notifier).trackCall(consultationId, _threadId, type);
      await context.push(
        VideoCallScreen.routePath,
        extra: VideoCallArgs(
          consultationId: consultationId,
          channelId:      channelName,
          token:          agoraToken,
          uid:            uid,
          callType:       type,
          peerName:       widget.args.peerName,
        ),
      );
      if (!mounted) return;

      // Only prompt for a rating if the consultation actually reached ENDED
      // state. Calls that were rejected, missed, or dropped aren't rateable.
      bool isEnded = false;
      try {
        final detail = await api.get('/consultations/$consultationId');
        final status = (detail['data'] as Map<String, dynamic>?)?['status'] as String?;
        isEnded = status == 'ENDED';
      } catch (_) {
        isEnded = false;
      }

      if (!mounted || !isEnded) return;

      final submitted = await RatingModal.show(
        context,
        lawyerName:     widget.args.peerName,
        consultationId: consultationId,
        onSubmit: (r) async {
          await api.post('/ratings/consultations/$consultationId', data: {
            'stars': r.stars,
            if (r.reviewText != null) 'reviewText': r.reviewText,
          });
        },
      );

      if (submitted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your feedback.')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? e.message ?? 'Failed to start call';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _callLoading = false);
    }
  }

  Future<void> _openProfile() async {
    if (widget.args.peerRole != 'LAWYER') return;
    setState(() => _profileLoading = true);
    try {
      final resp   = await ref.read(apiClientProvider).get('/lawyers/${widget.args.peerId}');
      final lawyer = LawyerSummary.fromJson(resp['data'] as Map<String, dynamic>);
      if (!mounted) return;
      context.push(LawyerDetailScreen.routePath, extra: lawyer);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _myId == null
        ? <ChatMessage>[]
        : ref.watch(chatProvider.select((s) => s.threads[_threadId]?.messages ?? <ChatMessage>[]));

    // auto-scroll on new messages
    ref.listen(chatProvider, (_, next) {
      final msgs = next.threads[_threadId]?.messages ?? [];
      if (msgs.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        // Call icons appear only when the LOGGED-IN account is a USER and the
        // peer is a LAWYER. Backend rejects /call/initiate from any other role
        // ("Forbidden resource"); hiding the icons prevents that error.
        actions: (_myRole == 'USER' && widget.args.peerRole == 'LAWYER') ? [
          IconButton(
            icon: _callLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(LucideIcons.phone, size: 20),
            tooltip: 'Voice call',
            onPressed: _callLoading ? null : () => _startCall('VOICE'),
          ),
          IconButton(
            icon: const Icon(LucideIcons.video, size: 20),
            tooltip: 'Video call',
            onPressed: _callLoading ? null : () => _startCall('VIDEO'),
          ),
          const SizedBox(width: 4),
        ] : null,
        title: GestureDetector(
          onTap: _profileLoading ? null : _openProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: _profileLoading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Text(
                          widget.args.peerName.isNotEmpty ? widget.args.peerName[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                        ),
                ),
                if (_peerOnline)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.args.peerName),
              if (widget.args.peerRole == 'LAWYER')
                Text(
                  _peerOnline ? 'Online' : 'Tap to view profile',
                  style: TextStyle(
                    fontSize: 11,
                    color: _peerOnline ? AppColors.onlineGreen : AppColors.secondary,
                    fontWeight: _peerOnline ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ]),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _myId == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              : messages.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No messages yet.\nSay hello to ${widget.args.peerName}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.secondary, height: 1.5),
                      ),
                    ]))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _MessageBubble(
                        message: messages[i],
                        isMe: messages[i].senderId == _myId,
                      ),
                    ),
        ),
        Material(
          color: Colors.white,
          elevation: 4,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1, maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      filled: true, fillColor: AppColors.slate50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.blue500,
                    foregroundColor: Colors.white,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (message.type == 'call') return _buildCallBubble();

    final time   = DateFormat('HH:mm').format(message.createdAt.toLocal());
    final status = message.status;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.blue500 : AppColors.slate100,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe  ? const Radius.circular(4) : null,
            bottomLeft:  !isMe ? const Radius.circular(4) : null,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.content,
              style: TextStyle(color: isMe ? Colors.white : AppColors.slate700, height: 1.4)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(time,
                style: TextStyle(fontSize: 11, color: isMe ? Colors.white60 : AppColors.slate400)),
            if (isMe) ...[
              const SizedBox(width: 4),
              _buildTick(status),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _buildCallBubble() {
    final isVideo  = message.callType == 'VIDEO';
    final status   = message.callStatus ?? 'completed';
    final duration = message.callDurationSeconds ?? 0;

    final String label;
    final Color  bgColor;
    final Color  fgColor;
    final IconData icon;

    if (status == 'completed') {
      final mins   = duration ~/ 60;
      final secs   = duration % 60;
      final durStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
      label   = isVideo ? 'Video call · $durStr' : 'Voice call · $durStr';
      bgColor = isMe ? AppColors.blue500 : AppColors.slate100;
      fgColor = isMe ? Colors.white : AppColors.slate700;
      icon    = isVideo ? Icons.videocam_rounded : Icons.call_rounded;
    } else if (status == 'missed') {
      label   = isVideo ? 'Missed video call' : 'Missed voice call';
      bgColor = const Color(0xFFFFEDED);
      fgColor = const Color(0xFFD32F2F);
      icon    = isVideo ? Icons.videocam_off_rounded : Icons.phone_missed_rounded;
    } else {
      label   = 'Call declined';
      bgColor = const Color(0xFFFFEDED);
      fgColor = const Color(0xFFD32F2F);
      icon    = Icons.call_end_rounded;
    }

    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe  ? const Radius.circular(4) : null,
            bottomLeft:  !isMe ? const Radius.circular(4) : null,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: fgColor),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: fgColor, fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 2),
            Text(time, style: TextStyle(fontSize: 11, color: fgColor.withValues(alpha: 0.6))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTick(String status) {
    if (status == 'read') return Icon(Icons.done_all_rounded, size: 14, color: Colors.blue[200]);
    if (status == 'delivered') return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white54);
    return const Icon(Icons.done_rounded, size: 14, color: Colors.white54);
  }
}

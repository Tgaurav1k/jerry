import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';
import 'package:jerry_app/core/theme/app_colors.dart';
import 'package:jerry_app/features/chat/chat_provider.dart';

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
  late String _threadId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    NotificationService.currentThreadId = null;
    _input.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myId = await ref.read(tokenStorageProvider).getUserId();
    if (_myId == null) return;

    _threadId = ChatNotifier.computeThreadId(_myId!, widget.args.peerId);

    ref.read(chatProvider.notifier).ensureThread(
      threadId: _threadId,
      peerId:   widget.args.peerId,
      peerRole: widget.args.peerRole,
      peerName: widget.args.peerName,
    );

    NotificationService.currentThreadId = _threadId;
    ref.read(chatProvider.notifier).markRead(
      _threadId, widget.args.peerId, widget.args.peerRole);

    setState(() {});
    _scrollToBottom();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _myId == null) return;
    _input.clear();

    ref.read(chatProvider.notifier).sendMessage(
      threadId:  _threadId,
      peerId:    widget.args.peerId,
      peerRole:  widget.args.peerRole,
      content:   text,
    );
    _scrollToBottom();
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
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceContainerHigh,
            child: Text(
              widget.args.peerName.isNotEmpty ? widget.args.peerName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(width: 10),
          Text(widget.args.peerName),
        ]),
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

  Widget _buildTick(String status) {
    if (status == 'read') return Icon(Icons.done_all_rounded, size: 14, color: Colors.blue[200]);
    if (status == 'delivered') return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white54);
    return const Icon(Icons.done_rounded, size: 14, color: Colors.white54);
  }
}

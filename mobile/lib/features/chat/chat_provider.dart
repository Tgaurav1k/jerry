import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jerry_app/core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.recipientId,
    required this.recipientRole,
    required this.content,
    required this.createdAt,
    this.status = 'sent',
  });

  final String id;
  final String threadId;
  final String senderId;
  final String senderRole;
  final String recipientId;
  final String recipientRole;
  final String content;
  final DateTime createdAt;
  String status;

  bool get isLocal => id.startsWith('local-');

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id:            m['id'] as String,
        threadId:      m['threadId'] as String,
        senderId:      m['senderId'] as String,
        senderRole:    m['senderRole'] as String,
        recipientId:   m['recipientId'] as String,
        recipientRole: m['recipientRole'] as String,
        content:       m['content'] as String,
        createdAt:     DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        status:        m['status'] as String? ?? 'sent',
      );
}

class ChatThread {
  ChatThread({
    required this.threadId,
    required this.peerId,
    required this.peerRole,
    this.peerName = '',
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String threadId;
  final String peerId;
  final String peerRole;
  String peerName;
  List<ChatMessage> messages;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatThread copyWith({String? peerName, List<ChatMessage>? messages}) => ChatThread(
        threadId: threadId,
        peerId:   peerId,
        peerRole: peerRole,
        peerName: peerName ?? this.peerName,
        messages: messages ?? List.from(this.messages),
      );
}

class ChatState {
  const ChatState({this.threads = const {}});
  final Map<String, ChatThread> threads;

  List<ChatThread> get threadList {
    final list = threads.values.where((t) => t.lastMessage != null).toList();
    list.sort((a, b) => b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt));
    return list;
  }

  ChatState copyWith(Map<String, ChatThread> updated) => ChatState(threads: updated);
}

// ── Notifier ──────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._socket, this._storage) : super(const ChatState()) {
    _init();
  }

  final SocketService _socket;
  final TokenStorage  _storage;
  String? _myId;

  static String computeThreadId(String a, String b) =>
      a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';

  Future<void> _init() async {
    _myId = await _storage.getUserId();
    final sock = await _socket.connect();
    sock.on('chat:message',  _onMessage);
    sock.on('chat:sent',     _onSent);
    sock.on('chat:read_ack', _onReadAck);
  }

  void _onMessage(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    final msg  = ChatMessage.fromMap(data);
    final isMe = msg.senderId == _myId;
    final peerId   = isMe ? msg.recipientId   : msg.senderId;
    final peerRole = isMe ? msg.recipientRole : msg.senderRole;

    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[msg.threadId] ?? ChatThread(
      threadId: msg.threadId,
      peerId:   peerId,
      peerRole: peerRole,
    );

    final msgs = List<ChatMessage>.from(thread.messages);
    // replace optimistic if same localId came back
    final idx = msgs.indexWhere((m) => m.id == msg.id || (m.isLocal && m.content == msg.content && isMe));
    if (idx != -1) {
      msgs[idx] = msg;
    } else {
      msgs.add(msg);
    }

    threads[msg.threadId] = thread.copyWith(messages: msgs);
    state = state.copyWith(threads);
  }

  void _onSent(dynamic raw) {
    final data      = Map<String, dynamic>.from(raw as Map);
    final messageId = data['messageId'] as String?;
    if (messageId == null) return;
    final threads = Map<String, ChatThread>.from(state.threads);
    for (final entry in threads.entries) {
      final msgs = List<ChatMessage>.from(entry.value.messages);
      final idx  = msgs.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        msgs[idx].status = 'delivered';
        threads[entry.key] = entry.value.copyWith(messages: msgs);
        state = state.copyWith(threads);
        return;
      }
    }
  }

  void _onReadAck(dynamic raw) {
    final data     = Map<String, dynamic>.from(raw as Map);
    final threadId = data['threadId'] as String?;
    if (threadId == null) return;
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;
    final msgs = thread.messages.map((m) {
      if (m.senderId == _myId) m.status = 'read';
      return m;
    }).toList();
    threads[threadId] = thread.copyWith(messages: msgs);
    state = state.copyWith(threads);
  }

  void setPeerName(String threadId, String name) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread != null && thread.peerName != name) {
      threads[threadId] = thread.copyWith(peerName: name);
      state = state.copyWith(threads);
    }
  }

  void sendMessage({
    required String threadId,
    required String peerId,
    required String peerRole,
    required String content,
  }) {
    final localId  = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final myId     = _myId ?? '';
    final myRole   = peerRole == 'LAWYER' ? 'USER' : 'LAWYER';

    final optimistic = ChatMessage(
      id:            localId,
      threadId:      threadId,
      senderId:      myId,
      senderRole:    myRole,
      recipientId:   peerId,
      recipientRole: peerRole,
      content:       content,
      createdAt:     DateTime.now(),
      status:        'sending',
    );

    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread != null) {
      threads[threadId] = thread.copyWith(
        messages: [...thread.messages, optimistic],
      );
      state = state.copyWith(threads);
    }

    _socket.socket?.emit('chat:send', {
      'messageId':    localId,
      'threadId':     threadId,
      'recipientId':  peerId,
      'recipientRole': peerRole,
      'content':      content,
    });
  }

  void markRead(String threadId, String peerId, String peerRole) {
    _socket.socket?.emit('chat:read', {
      'threadId':  threadId,
      'senderId':  peerId,
      'senderRole': peerRole,
    });
  }

  void ensureThread({
    required String threadId,
    required String peerId,
    required String peerRole,
    required String peerName,
  }) {
    final threads = Map<String, ChatThread>.from(state.threads);
    if (!threads.containsKey(threadId)) {
      threads[threadId] = ChatThread(
        threadId: threadId,
        peerId:   peerId,
        peerRole: peerRole,
        peerName: peerName,
      );
    } else {
      threads[threadId] = threads[threadId]!.copyWith(peerName: peerName);
    }
    state = state.copyWith(threads);
  }

  List<ChatMessage> messagesFor(String threadId) =>
      state.threads[threadId]?.messages ?? [];

  @override
  void dispose() {
    _socket.socket?.off('chat:message');
    _socket.socket?.off('chat:sent');
    _socket.socket?.off('chat:read_ack');
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final socket  = ref.watch(socketServiceProvider);
  final storage = ref.watch(tokenStorageProvider);
  return ChatNotifier(socket, storage);
});

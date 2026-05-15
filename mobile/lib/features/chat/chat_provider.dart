import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jerry_app/core/network/api_client.dart';
import 'package:jerry_app/core/notifications/notification_service.dart';

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
    this.type = 'text',
    this.callType,
    this.callStatus,
    this.callDurationSeconds,
  });

  final String   id;
  final String   threadId;
  final String   senderId;
  final String   senderRole;
  final String   recipientId;
  final String   recipientRole;
  final String   content;
  final DateTime createdAt;
  String status;
  final String   type;               // 'text' | 'call'
  final String?  callType;           // 'VIDEO' | 'VOICE'
  final String?  callStatus;         // 'completed' | 'missed' | 'declined'
  final int?     callDurationSeconds;

  bool get isLocal => id.startsWith('local-');

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id:                   m['id'] as String,
        threadId:             m['threadId'] as String,
        senderId:             m['senderId'] as String,
        senderRole:           m['senderRole'] as String,
        recipientId:          m['recipientId'] as String,
        recipientRole:        m['recipientRole'] as String,
        content:              m['content'] as String,
        createdAt:            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        status:               m['status'] as String? ?? 'sent',
        type:                 m['type'] as String? ?? 'text',
        callType:             m['callType'] as String?,
        callStatus:           m['callStatus'] as String?,
        callDurationSeconds:  (m['callDurationSeconds'] as num?)?.toInt(),
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
  const ChatState({
    this.threads = const {},
    this.unreadByThreadId = const {},
  });
  final Map<String, ChatThread> threads;
  /// Unread incoming messages per thread (incremented via Socket when not viewing that thread).
  final Map<String, int> unreadByThreadId;

  List<ChatThread> get threadList {
    final list = threads.values.where((t) => t.lastMessage != null).toList();
    list.sort((a, b) => b.lastMessage!.createdAt.compareTo(a.lastMessage!.createdAt));
    return list;
  }

  int get totalChatUnread =>
      unreadByThreadId.values.fold<int>(0, (sum, n) => sum + n);

  ChatState copyWith({
    Map<String, ChatThread>? threads,
    Map<String, int>? unreadByThreadId,
  }) =>
      ChatState(
        threads: threads ?? this.threads,
        unreadByThreadId: unreadByThreadId ?? this.unreadByThreadId,
      );
}

// ── Notifier ──────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._socket, this._storage, this._api) : super(const ChatState()) {
    _init();
  }

  final SocketService _socket;
  final TokenStorage  _storage;
  final ApiClient     _api;
  String? _myId;

  static String computeThreadId(String a, String b) =>
      a.compareTo(b) < 0 ? '$a:$b' : '$b:$a';

  final Map<String, Map<String, String>> _activeCalls = {};

  void trackCall(String consultationId, String threadId, String callType) {
    _activeCalls[consultationId] = {'threadId': threadId, 'callType': callType};
  }

  Future<void> _init() async {
    // Connect socket and ATTACH LISTENERS FIRST. The backend drains pending
    // messages immediately on handshake — if listeners aren't attached yet,
    // those drained events go to /dev/null. _myId is read in parallel.
    final sockFuture = _socket.connect();
    final idFuture   = _storage.getUserId();

    final sock = await sockFuture;
    if (sock == null) {
      _myId = await idFuture;
      return;
    }
    sock.on('chat:message',  _onMessage);
    sock.on('chat:sent',     _onSent);
    sock.on('chat:read_ack', _onReadAck);
    sock.on('call:ended',    _onCallEnded);
    sock.on('call:rejected', _onCallRejected);

    _myId = await idFuture;
    if (_myId != null && _myId!.isNotEmpty) {
      await loadThreads();
    }
  }

  Future<void> loadThreads() async {
    try {
      final resp = await _api.get('/chat/threads');
      final list = resp is List ? resp : (resp['data'] as List<dynamic>? ?? []);
      if (list.isEmpty) return;

      final threads = Map<String, ChatThread>.from(state.threads);
      for (final raw in list) {
        final m            = raw as Map<String, dynamic>;
        final threadId     = m['threadId']     as String;
        final peerId       = m['peerId']       as String? ?? '';
        final peerRole     = m['peerRole']     as String? ?? 'LAWYER';
        final peerName     = m['peerName']     as String? ?? '';
        if (peerId.isEmpty) continue;

        // Last message preview
        final lastMsg = ChatMessage.fromMap(m);

        final existing = threads[threadId];
        if (existing == null) {
          threads[threadId] = ChatThread(
            threadId: threadId,
            peerId:   peerId,
            peerRole: peerRole,
            peerName: peerName,
            messages: [lastMsg],
          );
        } else {
          // Update peer name (in case it was empty), keep existing messages
          final hasMsg = existing.messages.any((x) => x.id == lastMsg.id);
          threads[threadId] = existing.copyWith(
            peerName: peerName.isNotEmpty ? peerName : existing.peerName,
            messages: hasMsg ? existing.messages : [lastMsg, ...existing.messages],
          );
        }
      }
      state = state.copyWith(threads: threads);
    } catch (_) {}
  }

  void _onCallEnded(dynamic raw) {
    final data           = Map<String, dynamic>.from(raw as Map);
    final consultationId = data['consultationId'] as String;
    final duration       = (data['durationSeconds'] as num?)?.toInt() ?? 0;
    final callInfo       = _activeCalls.remove(consultationId);
    if (callInfo == null) return;
    _addCallBubble(
      threadId:        callInfo['threadId']!,
      callType:        callInfo['callType']!,
      status:          duration > 0 ? 'completed' : 'missed',
      durationSeconds: duration,
    );
  }

  void _onCallRejected(dynamic raw) {
    final data           = Map<String, dynamic>.from(raw as Map);
    final consultationId = data['consultationId'] as String;
    final callInfo       = _activeCalls.remove(consultationId);
    if (callInfo == null) return;
    _addCallBubble(
      threadId:        callInfo['threadId']!,
      callType:        callInfo['callType']!,
      status:          'declined',
      durationSeconds: 0,
    );
  }

  void addMissedCallBubble({required String threadId, required String callType}) {
    _addCallBubble(threadId: threadId, callType: callType, status: 'missed', durationSeconds: 0);
  }

  void _addCallBubble({
    required String threadId,
    required String callType,
    required String status,
    required int    durationSeconds,
  }) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;
    final msg = ChatMessage(
      id:                  'call-${DateTime.now().microsecondsSinceEpoch}',
      threadId:            threadId,
      senderId:            _myId ?? '',
      senderRole:          thread.peerRole == 'LAWYER' ? 'USER' : 'LAWYER',
      recipientId:         thread.peerId,
      recipientRole:       thread.peerRole,
      content:             '',
      createdAt:           DateTime.now(),
      status:              'sent',
      type:                'call',
      callType:            callType,
      callStatus:          status,
      callDurationSeconds: durationSeconds,
    );
    threads[threadId] = thread.copyWith(messages: [...thread.messages, msg]);
    state = state.copyWith(threads: threads);
  }

  /// Socket.IO passes positional args; the last one is the ack callback
  /// when the server emitted with one (used by the pending-message drain).
  /// We invoke it after successfully integrating the message so the backend
  /// only deletes the PendingMessage row on confirmed receipt.
  void _onMessage(dynamic raw, [dynamic ack]) {
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

    final unread = Map<String, int>.from(state.unreadByThreadId);
    if (!isMe && msg.threadId != NotificationService.currentThreadId) {
      unread[msg.threadId] = (unread[msg.threadId] ?? 0) + 1;
    }
    state = state.copyWith(threads: threads, unreadByThreadId: unread);

    // Confirm receipt so backend deletes the PendingMessage row.
    if (ack is Function) {
      try { ack({'ok': true}); } catch (_) {}
    }
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
        state = state.copyWith(threads: threads);
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
    state = state.copyWith(threads: threads);
  }

  void setPeerName(String threadId, String name) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread != null && thread.peerName != name) {
      threads[threadId] = thread.copyWith(peerName: name);
      state = state.copyWith(threads: threads);
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
    var thread = threads[threadId];
    thread ??= ChatThread(
      threadId: threadId,
      peerId: peerId,
      peerRole: peerRole,
    );
    threads[threadId] = thread.copyWith(
      messages: [...thread.messages, optimistic],
    );
    state = state.copyWith(threads: threads);

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
    state = state.copyWith(threads: threads);
  }

  Future<void> loadHistory(String threadId) async {
    try {
      final resp = await _api.get('/chat/history', params: {'threadId': threadId, 'limit': '100'});
      final list = resp is List ? resp : (resp['data'] as List<dynamic>? ?? []);
      final msgs = list.map((e) => ChatMessage.fromMap(e as Map<String, dynamic>)).toList();
      if (msgs.isEmpty) return;
      final threads = Map<String, ChatThread>.from(state.threads);
      final thread  = threads[threadId];
      if (thread == null) return;
      // Merge: keep local optimistic messages, prepend history
      final existingIds = thread.messages.map((m) => m.id).toSet();
      final newMsgs = msgs.where((m) => !existingIds.contains(m.id)).toList();
      if (newMsgs.isEmpty) return;
      threads[threadId] = thread.copyWith(messages: [...newMsgs, ...thread.messages]);
      state = state.copyWith(threads: threads);
    } catch (_) {}
  }

  void clearUnread(String threadId) {
    if (!state.unreadByThreadId.containsKey(threadId)) return;
    final unread = Map<String, int>.from(state.unreadByThreadId)..remove(threadId);
    state = state.copyWith(unreadByThreadId: unread);
  }

  List<ChatMessage> messagesFor(String threadId) =>
      state.threads[threadId]?.messages ?? [];

  @override
  void dispose() {
    final s = _socket.socket;
    if (s != null) {
      s.off('chat:message', _onMessage);
      s.off('chat:sent', _onSent);
      s.off('chat:read_ack', _onReadAck);
      s.off('call:ended', _onCallEnded);
      s.off('call:rejected', _onCallRejected);
    }
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final socket  = ref.watch(socketServiceProvider);
  final storage = ref.watch(tokenStorageProvider);
  final api     = ref.watch(apiClientProvider);
  return ChatNotifier(socket, storage, api);
});

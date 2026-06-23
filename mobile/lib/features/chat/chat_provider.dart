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
    this.deletedForAll = false,
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
  /// True if the sender ran "Delete for everyone" within the 2h window.
  /// The bubble renders as a tombstone instead of showing content.
  bool deletedForAll;

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
        deletedForAll:        m['deletedForAll'] == true,
      );
}

class ChatThread {
  ChatThread({
    required this.threadId,
    required this.peerId,
    required this.peerRole,
    this.peerName = '',
    this.peerIsOnline = false,
    List<ChatMessage>? messages,
  }) : messages = _sortByTime(messages ?? const []);

  final String threadId;
  final String peerId;
  final String peerRole;
  String peerName;
  bool peerIsOnline;
  List<ChatMessage> messages;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Messages are always stored oldest → newest. Live socket events,
  /// history fetches, and thread-list previews all funnel through here so the
  /// UI never has to second-guess ordering.
  static List<ChatMessage> _sortByTime(Iterable<ChatMessage> input) {
    final list = List<ChatMessage>.from(input);
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  ChatThread copyWith({String? peerName, bool? peerIsOnline, List<ChatMessage>? messages}) => ChatThread(
        threadId: threadId,
        peerId:   peerId,
        peerRole: peerRole,
        peerName: peerName ?? this.peerName,
        peerIsOnline: peerIsOnline ?? this.peerIsOnline,
        messages: messages ?? this.messages,
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
    sock.on('chat:message',         _onMessage);
    sock.on('chat:sent',            _onSent);
    sock.on('chat:read_ack',        _onReadAck);
    sock.on('chat:deleted',         _onDeleted);
    sock.on('chat:thread_cleared',  _onThreadCleared);
    sock.on('call:ended',           _onCallEnded);
    sock.on('call:rejected',        _onCallRejected);

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
        final peerIsOnline = m['peerIsOnline'] == true;
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
            peerIsOnline: peerIsOnline,
            messages: [lastMsg],
          );
        } else {
          // Update peer name (in case it was empty), append last-message
          // preview if we haven't seen it yet. ChatThread re-sorts internally
          // so insertion order here doesn't matter.
          final hasMsg = existing.messages.any((x) => x.id == lastMsg.id);
          threads[threadId] = existing.copyWith(
            peerName: peerName.isNotEmpty ? peerName : existing.peerName,
            peerIsOnline: peerIsOnline,
            messages: hasMsg ? existing.messages : [...existing.messages, lastMsg],
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
      consultationId:  consultationId,
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
      consultationId:  consultationId,
    );
  }

  void addMissedCallBubble({
    required String threadId,
    required String callType,
    String? consultationId,
  }) {
    _addCallBubble(
      threadId: threadId,
      callType: callType,
      status: 'missed',
      durationSeconds: 0,
      consultationId: consultationId,
    );
  }

  void _addCallBubble({
    required String threadId,
    required String callType,
    required String status,
    required int    durationSeconds,
    String? consultationId,
  }) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;
    // Use the consultation id as the bubble id when we have it so this live
    // bubble matches the row the backend persists (`call-<consultationId>`).
    // loadHistory() dedups by id, so without this the same call shows twice
    // after the thread is reopened (live `call-<timestamp>` + history
    // `call-<consultationId>`).
    final msgId = consultationId != null
        ? 'call-$consultationId'
        : 'call-${DateTime.now().microsecondsSinceEpoch}';
    // Idempotency guard: never add the same call bubble twice.
    if (thread.messages.any((m) => m.id == msgId)) return;
    final msg = ChatMessage(
      id:                  msgId,
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

      // In-app heads-up notification (Instagram / WhatsApp style). Tab badge
      // already updates via the unread map; this gives the user the popup
      // they expect when they're foregrounded on a different tab. We skip it
      // when the user is actively reading this thread (currentThreadId).
      // The FCM foreground handler intentionally skips chat:message so this
      // is the single source of truth — no double-toasting.
      if (msg.type == 'text' && msg.content.isNotEmpty) {
        final sender = thread.peerName.isNotEmpty ? thread.peerName : 'New message';
        NotificationService.show(sender, msg.content);
      }
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

  /// Server says a message was deleted. For scope='all' both sides receive
  /// this; for scope='me' only the deleter's other devices receive it.
  void _onDeleted(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    final messageId = data['messageId'] as String?;
    final threadId  = data['threadId']  as String?;
    final scope     = data['scope']     as String? ?? 'all';
    if (messageId == null || threadId == null) return;
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;

    if (scope == 'me') {
      // Remove entirely from this client's state.
      final msgs = thread.messages.where((m) => m.id != messageId).toList();
      threads[threadId] = thread.copyWith(messages: msgs);
    } else {
      // Tombstone in place.
      final msgs = thread.messages.map((m) {
        if (m.id == messageId) m.deletedForAll = true;
        return m;
      }).toList();
      threads[threadId] = thread.copyWith(messages: msgs);
    }
    state = state.copyWith(threads: threads);
  }

  /// Server confirms a "Clear chat" sweep. The deleter's view drops every
  /// message in this thread. Other side is untouched on their device.
  void _onThreadCleared(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    final threadId = data['threadId'] as String?;
    if (threadId == null) return;
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;
    threads[threadId] = thread.copyWith(messages: []);
    state = state.copyWith(threads: threads);
  }

  Future<bool> deleteMessageForMe(String messageId) async {
    try {
      await _api.delete('/chat/messages/$messageId', params: {'scope': 'me'});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMessageForEveryone(String messageId) async {
    try {
      await _api.delete('/chat/messages/$messageId', params: {'scope': 'all'});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearChat(String threadId) async {
    try {
      await _api.delete('/chat/threads/$threadId');
      return true;
    } catch (_) {
      return false;
    }
  }

  void setPeerName(String threadId, String name) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread != null && thread.peerName != name) {
      threads[threadId] = thread.copyWith(peerName: name);
      state = state.copyWith(threads: threads);
    }
  }

  /// Sends a chat message via HTTP POST /chat/send, not WebSocket.
  ///
  /// Why HTTP: the WebSocket connection silently dies when the app is
  /// backgrounded for too long, the network drops, or a NAT eats the
  /// connection. emit() on a stale socket is a no-op and the message is lost.
  /// HTTP gives us a real success/failure signal and is rock-solid for
  /// persistence. Recipients still receive instantly because the server
  /// broadcasts on the same gateway after persisting.
  Future<void> sendMessage({
    required String threadId,
    required String peerId,
    required String peerRole,
    required String content,
  }) async {
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

    try {
      await _api.post('/chat/send', data: {
        'messageId':     localId,
        'threadId':      threadId,
        'recipientId':   peerId,
        'recipientRole': peerRole,
        'content':       content,
      });
      // Server-side broadcast will echo `chat:message` back to us with the
      // same messageId, replacing the optimistic bubble. Status flips to
      // 'delivered' once the recipient is reached (via the chat:sent path on
      // future ack work, or simply on next loadHistory).
      _markStatus(threadId, localId, 'sent');
    } catch (_) {
      _markStatus(threadId, localId, 'failed');
    }
  }

  void _markStatus(String threadId, String messageId, String status) {
    final threads = Map<String, ChatThread>.from(state.threads);
    final thread  = threads[threadId];
    if (thread == null) return;
    final msgs = thread.messages.map((m) {
      if (m.id == messageId) m.status = status;
      return m;
    }).toList();
    threads[threadId] = thread.copyWith(messages: msgs);
    state = state.copyWith(threads: threads);
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
      // Merge in any history rows we don't already have. Final ordering is
      // enforced by ChatThread._sortByTime, so the insertion order here doesn't
      // matter — we just need every message to be present exactly once.
      final existingIds = thread.messages.map((m) => m.id).toSet();
      final newMsgs = msgs.where((m) => !existingIds.contains(m.id)).toList();
      if (newMsgs.isEmpty) return;
      threads[threadId] = thread.copyWith(messages: [...thread.messages, ...newMsgs]);
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
      s.off('chat:message',        _onMessage);
      s.off('chat:sent',           _onSent);
      s.off('chat:read_ack',       _onReadAck);
      s.off('chat:deleted',        _onDeleted);
      s.off('chat:thread_cleared', _onThreadCleared);
      s.off('call:ended',          _onCallEnded);
      s.off('call:rejected',       _onCallRejected);
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

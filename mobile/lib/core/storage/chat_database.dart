import 'package:jerry_app/core/config/demo_ids.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _dbName = 'jerry_chat.db';
const _v1 = 1;

/// Local-only chat store (MVP-Tech-Doc). Demo thread is seeded for demo accounts.
class ChatDatabase {
  ChatDatabase._();
  static final ChatDatabase instance = ChatDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _v1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  client_message_id TEXT UNIQUE,
  thread_id TEXT NOT NULL,
  from_id TEXT NOT NULL,
  from_role TEXT NOT NULL,
  to_id TEXT NOT NULL,
  to_role TEXT NOT NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'DELIVERED',
  timestamp INTEGER NOT NULL,
  is_mine INTEGER NOT NULL
);
''');
        await db.execute('CREATE INDEX idx_messages_thread ON messages(thread_id, timestamp DESC);');
        await db.execute('''
CREATE TABLE threads (
  thread_id TEXT PRIMARY KEY,
  other_party_id TEXT NOT NULL,
  other_party_role TEXT NOT NULL,
  other_party_name TEXT,
  other_party_photo_url TEXT,
  last_message_preview TEXT,
  last_message_timestamp INTEGER,
  unread_count INTEGER DEFAULT 0
);
''');
        await db.execute('CREATE INDEX idx_threads_recent ON threads(last_message_timestamp DESC);');
      },
    );
  }

  /// Inserts the demo conversation for [myUserId] when it is a demo account and thread is empty.
  Future<void> ensureDemoThreadSeed({
    required String myUserId,
    required String role,
  }) async {
    if (!isDemoAccount(myUserId)) return;

    final db = await database;
    final threadId = demoThreadIdSorted();

    final existing = await db.query('messages', where: 'thread_id = ?', whereArgs: [threadId], limit: 1);
    if (existing.isNotEmpty) return;

    final isUser = role == 'USER';
    final myId = myUserId;
    final peerId = isUser ? kDemoLawyerId : kDemoUserId;
    final peerRole = isUser ? 'LAWYER' : 'USER';
    final peerName = isUser ? 'Demo Lawyer' : 'Demo Client';

    final now = DateTime.now().millisecondsSinceEpoch;
    const step = 60000;

    final m1From = kDemoLawyerId;
    final m2From = kDemoUserId;
    final m3From = kDemoLawyerId;

    Future<void> insertMsg({
      required String id,
      required String clientId,
      required String fromId,
      required String fromRole,
      required String toId,
      required String toRole,
      required String content,
      required int ts,
    }) async {
      final mine = fromId == myId ? 1 : 0;
      await db.insert('messages', {
        'id': id,
        'client_message_id': clientId,
        'thread_id': threadId,
        'from_id': fromId,
        'from_role': fromRole,
        'to_id': toId,
        'to_role': toRole,
        'content': content,
        'status': 'DELIVERED',
        'timestamp': ts,
        'is_mine': mine,
      });
    }

    await insertMsg(
      id: 'demo-seed-1',
      clientId: 'demo-seed-1',
      fromId: m1From,
      fromRole: 'LAWYER',
      toId: kDemoUserId,
      toRole: 'USER',
      content:
          'Hello — this is the demo chat between the demo client and demo lawyer. Messages stay on each phone until live Socket.IO sync is enabled.',
      ts: now - 3 * step,
    );
    await insertMsg(
      id: 'demo-seed-2',
      clientId: 'demo-seed-2',
      fromId: m2From,
      fromRole: 'USER',
      toId: kDemoLawyerId,
      toRole: 'LAWYER',
      content: 'Thanks — I can see the thread. Good for testing the UI on both devices.',
      ts: now - 2 * step,
    );
    await insertMsg(
      id: 'demo-seed-3',
      clientId: 'demo-seed-3',
      fromId: m3From,
      fromRole: 'LAWYER',
      toId: kDemoUserId,
      toRole: 'USER',
      content: 'Type below to add more messages. They are saved only in this app’s local database.',
      ts: now - step,
    );

    await db.insert('threads', {
      'thread_id': threadId,
      'other_party_id': peerId,
      'other_party_role': peerRole,
      'other_party_name': peerName,
      'other_party_photo_url': null,
      'last_message_preview': 'Type below to add more messages. They are saved only in this app’s local database.',
      'last_message_timestamp': now - step,
      'unread_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> loadThreads() async {
    final db = await database;
    return db.query('threads', orderBy: 'last_message_timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> loadMessages(String threadId) async {
    final db = await database;
    return db.query('messages', where: 'thread_id = ?', whereArgs: [threadId], orderBy: 'timestamp ASC');
  }

  Future<void> insertOutgoingMessage({
    required String threadId,
    required String myUserId,
    required String myRole,
    required String peerId,
    required String peerRole,
    required String content,
  }) async {
    final db = await database;
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final ts = DateTime.now().millisecondsSinceEpoch;
    await db.insert('messages', {
      'id': id,
      'client_message_id': id,
      'thread_id': threadId,
      'from_id': myUserId,
      'from_role': myRole,
      'to_id': peerId,
      'to_role': peerRole,
      'content': content,
      'status': 'DELIVERED',
      'timestamp': ts,
      'is_mine': 1,
    });
    await db.update(
      'threads',
      {
        'last_message_preview': content.length > 80 ? '${content.substring(0, 80)}…' : content,
        'last_message_timestamp': ts,
      },
      where: 'thread_id = ?',
      whereArgs: [threadId],
    );
  }
}

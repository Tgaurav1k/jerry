import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

/** Window during which the sender can still "Delete for everyone". */
const DELETE_FOR_ALL_WINDOW_MS = 2 * 60 * 60 * 1000; // 2 hours

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async send(
    sender: JwtPayload,
    payload: {
      messageId: string;
      threadId: string;
      recipientId: string;
      recipientRole: 'USER' | 'LAWYER';
      content: string;
    },
  ) {
    const now = new Date();
    const msgPayload = {
      id: payload.messageId,
      threadId: payload.threadId,
      senderId: sender.sub,
      senderRole: sender.role,
      recipientId: payload.recipientId,
      recipientRole: payload.recipientRole,
      content: payload.content,
      createdAt: now.toISOString(),
      status: 'sent',
    };

    // Persist to chat history — upsert so duplicate messageIds don't error
    await this.prisma.chatMessage.upsert({
      where: { id: payload.messageId },
      create: {
        id:            payload.messageId,
        threadId:      payload.threadId,
        senderId:      sender.sub,
        senderRole:    sender.role,
        recipientId:   payload.recipientId,
        recipientRole: payload.recipientRole,
        content:       payload.content,
        createdAt:     now,
      },
      update: {}, // already saved, no-op
    });

    // Store as pending for offline delivery (separate write — DB failures here
    // shouldn't block history persistence above)
    try {
      const data: Record<string, unknown> = { payload: msgPayload, createdAt: now };
      if (payload.recipientRole === 'USER') data.recipientUserId = payload.recipientId;
      else data.recipientLawyerId = payload.recipientId;

      if (sender.role === 'USER') data.senderUserId = sender.sub;
      else data.senderLawyerId = sender.sub;

      await this.prisma.pendingMessage.create({ data: data as any });
    } catch (_) { /* non-fatal */ }

    return msgPayload;
  }

  /**
   * @param viewer the role + id of whoever is reading the thread. Used to
   *        filter rows that were "Deleted for me" by the viewer.
   */
  async getHistory(threadId: string, viewer: JwtPayload, limit = 50) {
    const hiddenFilter =
      viewer.role === 'USER'
        ? { hiddenForUser: false }
        : viewer.role === 'LAWYER'
        ? { hiddenForLawyer: false }
        : {};

    const rows = await this.prisma.chatMessage.findMany({
      where: { threadId, ...hiddenFilter },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    return rows.map((m) => this._serialize(m));
  }

  /// Shared serializer applied to both history rows and live broadcasts.
  /// Deleted-for-all rows are returned with empty content + a flag the
  /// client uses to render a "Message deleted" tombstone in place.
  private _serialize(m: {
    id: string; threadId: string; senderId: string; senderRole: string;
    recipientId: string; recipientRole: string; content: string;
    type: string; callType: string | null; callStatus: string | null;
    callDurationSeconds: number | null; createdAt: Date;
    deletedForAll: boolean;
  }) {
    return {
      id:                  m.id,
      threadId:            m.threadId,
      senderId:            m.senderId,
      senderRole:          m.senderRole,
      recipientId:         m.recipientId,
      recipientRole:       m.recipientRole,
      content:             m.deletedForAll ? '' : m.content,
      type:                m.type,
      callType:            m.callType,
      callStatus:          m.callStatus,
      callDurationSeconds: m.callDurationSeconds,
      createdAt:           m.createdAt.toISOString(),
      status:              'sent',
      deletedForAll:       m.deletedForAll,
    };
  }

  async saveCallRecord(
    userId: string,
    lawyerId: string,
    consultationId: string,
    callType: 'VIDEO' | 'VOICE',
    callStatus: 'missed' | 'completed' | 'declined',
    callDurationSeconds: number,
  ) {
    const threadId = [userId, lawyerId].sort().join(':');
    await this.prisma.chatMessage.create({
      data: {
        id:                  `call-${consultationId}`,
        threadId,
        senderId:            userId,
        senderRole:          'USER',
        recipientId:         lawyerId,
        recipientRole:       'LAWYER',
        content:             '',
        type:                'call',
        callType,
        callStatus,
        callDurationSeconds,
      },
    });
    return threadId;
  }

  async saveMissedCall(
    senderId: string,
    recipientId: string,
    consultationId: string,
    callType: 'VIDEO' | 'VOICE',
  ) {
    return this.saveCallRecord(senderId, recipientId, consultationId, callType, 'missed', 0);
  }

  async getThreadList(userId: string, role: 'USER' | 'LAWYER') {
    // Last message per thread where this user is a participant. Skip rows the
    // viewer has hidden ("Delete for me") so the preview reflects the next
    // most-recent visible row, not a phantom.
    const hideCol = role === 'USER' ? '"hiddenForUser"' : '"hiddenForLawyer"';
    const rows = await this.prisma.$queryRawUnsafe<any[]>(`
      SELECT DISTINCT ON ("threadId")
        id, "threadId", "senderId", "senderRole",
        "recipientId", "recipientRole", content, type,
        "callType", "callStatus", "callDurationSeconds", "createdAt",
        "deletedForAll"
      FROM "ChatMessage"
      WHERE ("senderId" = $1 OR "recipientId" = $1)
        AND ${hideCol} = FALSE
      ORDER BY "threadId", "createdAt" DESC
    `, userId);

    // Resolve peer info (name/photo) for each thread
    const peerIds = { USER: new Set<string>(), LAWYER: new Set<string>() };
    for (const m of rows) {
      const isMe       = m.senderId === userId;
      const peerId     = isMe ? m.recipientId   : m.senderId;
      const peerRole   = isMe ? m.recipientRole : m.senderRole;
      if (peerRole === 'USER' || peerRole === 'LAWYER') peerIds[peerRole].add(peerId);
    }
    const [users, lawyers] = await Promise.all([
      peerIds.USER.size
        ? this.prisma.user.findMany({
            where: { id: { in: [...peerIds.USER] } },
            select: { id: true, fullName: true, profilePhotoUrl: true },
          })
        : Promise.resolve([]),
      peerIds.LAWYER.size
        ? this.prisma.lawyer.findMany({
            where: { id: { in: [...peerIds.LAWYER] } },
            select: { id: true, fullName: true, profilePhotoUrl: true, isOnline: true },
          })
        : Promise.resolve([]),
    ]);
    const peerMap = new Map<string, { fullName: string; photoUrl: string | null; isOnline: boolean }>();
    for (const u of users)   peerMap.set(u.id, { fullName: u.fullName, photoUrl: u.profilePhotoUrl, isOnline: false });
    for (const l of lawyers) peerMap.set(l.id, { fullName: l.fullName, photoUrl: l.profilePhotoUrl, isOnline: l.isOnline });

    return rows.map((m) => {
      const isMe     = m.senderId === userId;
      const peerId   = isMe ? m.recipientId   : m.senderId;
      const peerRole = isMe ? m.recipientRole : m.senderRole;
      const peer     = peerMap.get(peerId);
      const deletedForAll = !!m.deletedForAll;
      return {
        id:                  m.id,
        threadId:            m.threadId,
        senderId:            m.senderId,
        senderRole:          m.senderRole,
        recipientId:         m.recipientId,
        recipientRole:       m.recipientRole,
        content:             deletedForAll ? '' : m.content,
        type:                m.type ?? 'text',
        callType:            m.callType ?? null,
        callStatus:          m.callStatus ?? null,
        callDurationSeconds: m.callDurationSeconds ?? null,
        createdAt:           m.createdAt instanceof Date ? m.createdAt.toISOString() : m.createdAt,
        status:              'sent',
        deletedForAll,
        // Peer info for ChatsListScreen
        peerId,
        peerRole,
        peerName:            peer?.fullName ?? 'Unknown',
        peerPhotoUrl:        peer?.photoUrl ?? null,
        peerIsOnline:        peer?.isOnline ?? false,
      };
    });
  }

  async getPending(id: string, role: 'USER' | 'LAWYER') {
    return this.prisma.pendingMessage.findMany({
      where: role === 'USER' ? { recipientUserId: id } : { recipientLawyerId: id },
      orderBy: { createdAt: 'asc' },
    });
  }

  async ackPending(ids: string[]) {
    await this.prisma.pendingMessage.deleteMany({ where: { id: { in: ids } } });
  }

  async markRead(threadId: string, reader: JwtPayload) {
    // In this architecture chat history is device-side; just delete pending for this thread
    const where: Record<string, unknown> = {};
    if (reader.role === 'USER') where.recipientUserId = reader.sub;
    else where.recipientLawyerId = reader.sub;

    const pending = await this.prisma.pendingMessage.findMany({ where: where as any });
    const threadPending = pending.filter((p) => {
      const pl = p.payload as any;
      return pl?.threadId === threadId;
    });
    if (threadPending.length) {
      await this.prisma.pendingMessage.deleteMany({
        where: { id: { in: threadPending.map((p) => p.id) } },
      });
    }
  }

  async onLawyerDisconnect(lawyerId: string) {
    await this.prisma.lawyer.update({
      where: { id: lawyerId },
      data: { isOnline: false },
    });
  }

  // ─── Delete operations (WhatsApp-style) ──────────────────────────────────────

  /// "Delete for me" — hides the message from the requesting user's view.
  /// Either participant of the thread can hide a message from their own side.
  /// Returns the still-existing row so the caller can broadcast (no-op for
  /// the other side, since their hide flag is independent).
  async deleteForMe(messageId: string, viewer: JwtPayload) {
    const msg = await this.prisma.chatMessage.findUnique({ where: { id: messageId } });
    if (!msg) throw new NotFoundException();
    if (msg.type === 'call') {
      throw new BadRequestException('Call records cannot be deleted');
    }
    // Only participants can hide
    const isUser   = viewer.role === 'USER'   && (msg.senderId === viewer.sub || msg.recipientId === viewer.sub);
    const isLawyer = viewer.role === 'LAWYER' && (msg.senderId === viewer.sub || msg.recipientId === viewer.sub);
    if (!isUser && !isLawyer) throw new ForbiddenException();

    await this.prisma.chatMessage.update({
      where: { id: messageId },
      data: isUser ? { hiddenForUser: true } : { hiddenForLawyer: true },
    });
    return { messageId, threadId: msg.threadId };
  }

  /// "Delete for everyone" — sender-only, within a 2-hour window after send.
  /// The row stays (preserves chronology) but content is blanked and a flag
  /// is set so both sides render a "Message deleted" tombstone.
  async deleteForAll(messageId: string, sender: JwtPayload) {
    const msg = await this.prisma.chatMessage.findUnique({ where: { id: messageId } });
    if (!msg) throw new NotFoundException();
    if (msg.type === 'call') {
      throw new BadRequestException('Call records cannot be deleted');
    }
    if (msg.senderId !== sender.sub) {
      throw new ForbiddenException('Only the sender can delete for everyone');
    }
    // Derive participants from the message itself so the controller can
    // broadcast without a follow-up DB query. Returned in every branch.
    const isUserSender = msg.senderRole === 'USER';
    const participants = {
      userId:   isUserSender ? msg.senderId    : msg.recipientId,
      lawyerId: isUserSender ? msg.recipientId : msg.senderId,
    };

    if (msg.deletedForAll) {
      // Idempotent — already deleted.
      return { messageId, threadId: msg.threadId, alreadyDeleted: true, participants };
    }
    const ageMs = Date.now() - new Date(msg.createdAt).getTime();
    if (ageMs > DELETE_FOR_ALL_WINDOW_MS) {
      throw new BadRequestException('This message is older than 2 hours — only "Delete for me" is allowed.');
    }

    await this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        deletedForAll: true,
        deletedForAllAt: new Date(),
        content: '', // also blank the stored content so it isn't recoverable via getHistory
      },
    });

    return { messageId, threadId: msg.threadId, participants };
  }

  /// "Clear chat" — bulk hide every message in the thread from the requester's
  /// view only. The other participant's view is untouched. Call records are
  /// included in the bulk hide (the user can still see them in History tab).
  async clearChat(threadId: string, viewer: JwtPayload) {
    if (viewer.role !== 'USER' && viewer.role !== 'LAWYER') {
      throw new ForbiddenException();
    }
    const field = viewer.role === 'USER' ? 'hiddenForUser' : 'hiddenForLawyer';
    // Only touch rows the viewer participates in (defense-in-depth — the
    // threadId already encodes both party UUIDs but we re-check on senderId
    // / recipientId so a crafted threadId can't wipe someone else's thread).
    const result = await this.prisma.chatMessage.updateMany({
      where: {
        threadId,
        OR: [
          { senderId: viewer.sub },
          { recipientId: viewer.sub },
        ],
      },
      data: { [field]: true },
    });
    return { threadId, hiddenCount: result.count };
  }
}

import { Injectable } from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

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

  async getHistory(threadId: string, limit = 50) {
    const rows = await this.prisma.chatMessage.findMany({
      where: { threadId },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });
    return rows.map((m) => ({
      id:                  m.id,
      threadId:            m.threadId,
      senderId:            m.senderId,
      senderRole:          m.senderRole,
      recipientId:         m.recipientId,
      recipientRole:       m.recipientRole,
      content:             m.content,
      type:                m.type,
      callType:            m.callType,
      callStatus:          m.callStatus,
      callDurationSeconds: m.callDurationSeconds,
      createdAt:           m.createdAt.toISOString(),
      status:              'sent',
    }));
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
    // Last message per thread where this user is a participant
    const rows = await this.prisma.$queryRaw<any[]>`
      SELECT DISTINCT ON ("threadId")
        id, "threadId", "senderId", "senderRole",
        "recipientId", "recipientRole", content, type,
        "callType", "callStatus", "callDurationSeconds", "createdAt"
      FROM "ChatMessage"
      WHERE "senderId" = ${userId} OR "recipientId" = ${userId}
      ORDER BY "threadId", "createdAt" DESC
    `;

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
      return {
        id:                  m.id,
        threadId:            m.threadId,
        senderId:            m.senderId,
        senderRole:          m.senderRole,
        recipientId:         m.recipientId,
        recipientRole:       m.recipientRole,
        content:             m.content,
        type:                m.type ?? 'text',
        callType:            m.callType ?? null,
        callStatus:          m.callStatus ?? null,
        callDurationSeconds: m.callDurationSeconds ?? null,
        createdAt:           m.createdAt instanceof Date ? m.createdAt.toISOString() : m.createdAt,
        status:              'sent',
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
}

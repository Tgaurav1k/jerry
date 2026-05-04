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
    };

    // Store as pending for offline delivery
    const data: Record<string, unknown> = { payload: msgPayload, createdAt: now };
    if (payload.recipientRole === 'USER') data.recipientUserId = payload.recipientId;
    else data.recipientLawyerId = payload.recipientId;

    if (sender.role === 'USER') data.senderUserId = sender.sub;
    else data.senderLawyerId = sender.sub;

    await this.prisma.pendingMessage.create({ data: data as any });

    return msgPayload;
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

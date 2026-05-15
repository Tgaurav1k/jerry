import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import type { JwtPayload } from '../auth/jwt.strategy';
import { NotificationService } from '../notification/notification.service';
import { ChatService } from './chat.service';

@Injectable()
@WebSocketGateway({
  cors: { origin: '*' },
  transports: ['websocket', 'polling'],
  namespace: '/',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly chat: ChatService,
    private readonly notifications: NotificationService,
  ) {}

  async handleConnection(client: Socket) {
    const raw = client.handshake.auth?.token ?? client.handshake.query?.token;
    const token = typeof raw === 'string' ? raw : Array.isArray(raw) ? raw[0] : undefined;
    if (!token) { client.disconnect(true); return; }

    try {
      const secret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, { secret });
      client.data.user = payload;

      const { sub, role } = payload;
      if (role === 'LAWYER') await client.join(`lawyer:${sub}`);
      if (role === 'USER') await client.join(`user:${sub}`);

      // Drain pending messages
      const pending = await this.chat.getPending(sub, role as 'USER' | 'LAWYER');
      for (const msg of pending) {
        client.emit('chat:message', msg.payload);
      }
      if (pending.length) {
        const ids = pending.map((p) => p.id);
        await this.chat.ackPending(ids);
      }
    } catch {
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: Socket) {
    const user = client.data.user as JwtPayload | undefined;
    if (user?.role === 'LAWYER') {
      // Mark offline on disconnect (non-blocking)
      this.chat.onLawyerDisconnect(user.sub).catch(() => {});
    }
  }

  // ─── client → server: send message ────────────────────────────────────────

  @SubscribeMessage('chat:send')
  async onSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: {
      messageId: string;
      threadId: string;
      recipientId: string;
      recipientRole: 'USER' | 'LAWYER';
      content: string;
    },
  ) {
    const sender = client.data.user as JwtPayload | undefined;
    if (!sender?.sub) {
      client.emit('chat:error', { messageId: payload.messageId, error: 'unauthorized' });
      return;
    }
    let result;
    try {
      result = await this.chat.send(sender, payload);
    } catch (err) {
      console.error('[chat:send] persist failed', err);
      client.emit('chat:error', { messageId: payload.messageId, error: 'send_failed' });
      return;
    }

    // Echo delivery confirmation to sender
    client.emit('chat:sent', { messageId: payload.messageId, status: 'delivered' });

    // Route to recipient
    const room = payload.recipientRole === 'LAWYER'
      ? `lawyer:${payload.recipientId}`
      : `user:${payload.recipientId}`;

    this.server.to(room).emit('chat:message', {
      ...result,
      messageId: payload.messageId,
    });

    // Push notification (fires when recipient has app in background)
    const preview = payload.content.length > 60
      ? `${payload.content.slice(0, 60)}…`
      : payload.content;
    if (payload.recipientRole === 'LAWYER') {
      this.notifications.sendToLawyer(payload.recipientId, 'New Message', preview,
        { type: 'chat:message', threadId: payload.threadId }).catch(() => {});
    } else {
      this.notifications.sendToUser(payload.recipientId, 'New Message', preview,
        { type: 'chat:message', threadId: payload.threadId }).catch(() => {});
    }
  }

  // ─── client → server: typing indicator ────────────────────────────────────

  @SubscribeMessage('chat:typing')
  onTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { threadId: string; recipientId: string; recipientRole: 'USER' | 'LAWYER' },
  ) {
    const sender = client.data.user as JwtPayload;
    const room = payload.recipientRole === 'LAWYER'
      ? `lawyer:${payload.recipientId}`
      : `user:${payload.recipientId}`;

    this.server.to(room).emit('chat:typing', {
      threadId: payload.threadId,
      senderId: sender.sub,
      senderRole: sender.role,
    });
  }

  // ─── client → server: read receipt ────────────────────────────────────────

  @SubscribeMessage('chat:read')
  async onRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { threadId: string; senderId: string; senderRole: 'USER' | 'LAWYER' },
  ) {
    const reader = client.data.user as JwtPayload;
    await this.chat.markRead(payload.threadId, reader);

    const room = payload.senderRole === 'LAWYER'
      ? `lawyer:${payload.senderId}`
      : `user:${payload.senderId}`;

    this.server.to(room).emit('chat:read_ack', {
      threadId: payload.threadId,
      readBy: reader.sub,
      readByRole: reader.role,
    });
  }

  // ─── server → client helpers ───────────────────────────────────────────────

  emitToUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }

  emitToLawyer(lawyerId: string, event: string, data: unknown) {
    this.server.to(`lawyer:${lawyerId}`).emit(event, data);
  }
}

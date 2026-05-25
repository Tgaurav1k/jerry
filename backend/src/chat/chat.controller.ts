import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { ChatGateway } from './chat.gateway';
import { ChatService } from './chat.service';
import { NotificationService } from '../notification/notification.service';

class SendMessageDto {
  @IsString() messageId!: string;
  @IsString() threadId!: string;
  @IsString() recipientId!: string;
  @IsIn(['USER', 'LAWYER']) recipientRole!: 'USER' | 'LAWYER';
  @IsString() @MinLength(1) @MaxLength(4000) content!: string;
}

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(
    private readonly chat: ChatService,
    private readonly gateway: ChatGateway,
    private readonly notifications: NotificationService,
  ) {}

  // GET /chat/history?threadId=X&limit=50
  // Viewer-scoped: rows the caller has "Deleted for me" are filtered out;
  // "Deleted for everyone" rows are returned with empty content + a flag so
  // the client can render a tombstone.
  @Get('history')
  getHistory(
    @CurrentUser() user: JwtPayload,
    @Query('threadId') threadId: string,
    @Query('limit') limit?: string,
  ) {
    return this.chat.getHistory(threadId, user, limit ? parseInt(limit, 10) : 50);
  }

  // GET /chat/threads — last message per thread for this user
  @Get('threads')
  getThreads(@CurrentUser() user: JwtPayload) {
    return this.chat.getThreadList(user.sub, user.role as 'USER' | 'LAWYER');
  }

  /// POST /chat/send — reliable HTTP send path.
  ///
  /// WebSocket is for instant delivery; HTTP guarantees persistence even when
  /// the sender's socket has silently died (background timeout, network blip).
  /// Same persistence as the gateway's chat:send handler, then broadcasts via
  /// the gateway to the recipient if they're online.
  @Post('send')
  async send(@CurrentUser() user: JwtPayload, @Body() dto: SendMessageDto) {
    const result = await this.chat.send(user, dto);

    // Broadcast to recipient's room — if they're online, instant delivery; if
    // not, the PendingMessage row (created by chat.send) will replay on their
    // next reconnect.
    const room = dto.recipientRole === 'LAWYER'
      ? `lawyer:${dto.recipientId}`
      : `user:${dto.recipientId}`;
    this.gateway.server.to(room).emit('chat:message', { ...result, messageId: dto.messageId });

    // Push notification (mirrors the gateway behaviour)
    const preview = dto.content.length > 60 ? `${dto.content.slice(0, 60)}…` : dto.content;
    if (dto.recipientRole === 'LAWYER') {
      this.notifications.sendToLawyer(dto.recipientId, 'New Message', preview,
        { type: 'chat:message', threadId: dto.threadId }).catch(() => {});
    } else {
      this.notifications.sendToUser(dto.recipientId, 'New Message', preview,
        { type: 'chat:message', threadId: dto.threadId }).catch(() => {});
    }

    return {
      success: true,
      data: result,
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Delete endpoints (WhatsApp-style) ──────────────────────────────────────

  /// DELETE /chat/messages/:id?scope=me|all
  /// scope=me  → "Delete for me" (hide only from caller's view)
  /// scope=all → "Delete for everyone" (sender-only, within 2h)
  @Delete('messages/:id')
  async deleteMessage(
    @CurrentUser() user: JwtPayload,
    @Param('id') messageId: string,
    @Query('scope') scope: 'me' | 'all' = 'me',
  ) {
    if (scope === 'all') {
      const res = await this.chat.deleteForAll(messageId, user);
      // Tell both sides to render the tombstone in real time.
      this.gateway.emitToUser(res.participants.userId, 'chat:deleted', {
        messageId, threadId: res.threadId, scope: 'all',
      });
      this.gateway.emitToLawyer(res.participants.lawyerId, 'chat:deleted', {
        messageId, threadId: res.threadId, scope: 'all',
      });
      return { success: true, data: res, meta: { timestamp: new Date().toISOString() } };
    }
    const res = await this.chat.deleteForMe(messageId, user);
    // Only echo to the deleter so their other devices (if any) sync.
    if (user.role === 'USER') {
      this.gateway.emitToUser(user.sub, 'chat:deleted', {
        messageId, threadId: res.threadId, scope: 'me',
      });
    } else if (user.role === 'LAWYER') {
      this.gateway.emitToLawyer(user.sub, 'chat:deleted', {
        messageId, threadId: res.threadId, scope: 'me',
      });
    }
    return { success: true, data: res, meta: { timestamp: new Date().toISOString() } };
  }

  /// DELETE /chat/threads/:threadId
  /// "Clear chat" — bulk hides every message in the thread from the caller's
  /// view. The peer's view is untouched.
  @Delete('threads/:threadId')
  async clearThread(
    @CurrentUser() user: JwtPayload,
    @Param('threadId') threadId: string,
  ) {
    const res = await this.chat.clearChat(threadId, user);
    // Echo to the caller so their other devices sync.
    if (user.role === 'USER') {
      this.gateway.emitToUser(user.sub, 'chat:thread_cleared', {
        threadId, hiddenCount: res.hiddenCount,
      });
    } else if (user.role === 'LAWYER') {
      this.gateway.emitToLawyer(user.sub, 'chat:thread_cleared', {
        threadId, hiddenCount: res.hiddenCount,
      });
    }
    return { success: true, data: res, meta: { timestamp: new Date().toISOString() } };
  }

}

import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
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
  @Get('history')
  getHistory(
    @Query('threadId') threadId: string,
    @Query('limit') limit?: string,
  ) {
    return this.chat.getHistory(threadId, limit ? parseInt(limit, 10) : 50);
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
}

import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { ChatService } from './chat.service';

@Controller('chat')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chat: ChatService) {}

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
}

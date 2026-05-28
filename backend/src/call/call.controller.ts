import { BadRequestException, Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { CallService } from './call.service';
import { InitiateCallDto } from './dto/initiate-call.dto';

@Controller('call')
@UseGuards(JwtAuthGuard)
export class CallController {
  constructor(private readonly call: CallService) {}

  @Post('initiate')
  initiate(@CurrentUser() user: JwtPayload, @Body() dto: InitiateCallDto) {
    // Resolve recipient. New field names win; legacy `lawyerId` is treated as
    // a USER->LAWYER call so old mobile builds keep working.
    let recipientId = dto.recipientId;
    let recipientRole: 'USER' | 'LAWYER' | undefined = dto.recipientRole;
    if (!recipientId && dto.lawyerId) {
      recipientId = dto.lawyerId;
      recipientRole = 'LAWYER';
    }
    if (!recipientId) {
      throw new BadRequestException('recipientId (or legacy lawyerId) is required');
    }
    if (!recipientRole) {
      // Without an explicit role, infer from the caller: a USER always calls a
      // LAWYER and vice versa. This keeps the API ergonomic for the common case.
      recipientRole = user.role === 'USER' ? 'LAWYER' : 'USER';
    }
    return this.call.initiate(user, recipientId, recipientRole, dto.type);
  }

  @Post(':consultationId/accept')
  accept(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.accept(user, consultationId);
  }

  @Post(':consultationId/reject')
  reject(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.reject(user, consultationId);
  }

  @Post(':consultationId/end')
  end(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.end(user, consultationId);
  }

  @Post(':consultationId/token')
  refreshToken(
    @CurrentUser() user: JwtPayload,
    @Param('consultationId') consultationId: string,
  ) {
    return this.call.refreshToken(user, consultationId);
  }
}

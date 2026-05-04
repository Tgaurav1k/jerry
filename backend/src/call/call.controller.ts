import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CallService } from './call.service';
import { InitiateCallDto } from './dto/initiate-call.dto';

@Controller('call')
export class CallController {
  constructor(private readonly call: CallService) {}

  @Post('initiate')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('USER')
  initiate(@CurrentUser() user: JwtPayload, @Body() dto: InitiateCallDto) {
    return this.call.initiate(user, dto.lawyerId, dto.type);
  }

  @Post(':consultationId/accept')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('LAWYER')
  accept(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.accept(user, consultationId);
  }

  @Post(':consultationId/reject')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('LAWYER')
  reject(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.reject(user, consultationId);
  }

  @Post(':consultationId/end')
  @UseGuards(JwtAuthGuard)
  end(@CurrentUser() user: JwtPayload, @Param('consultationId') consultationId: string) {
    return this.call.end(user, consultationId);
  }
}

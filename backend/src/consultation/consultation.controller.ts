import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Min } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { ConsultationService } from './consultation.service';

class PageQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number;
}

@Controller('consultations')
@UseGuards(JwtAuthGuard)
export class ConsultationController {
  constructor(private readonly svc: ConsultationService) {}

  @Get('my')
  myHistory(@CurrentUser() user: JwtPayload, @Query() q: PageQueryDto) {
    return this.svc.getMyHistory(user, q.page, q.limit);
  }

  @Get(':id')
  getDetail(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.getDetail(user, id);
  }
}

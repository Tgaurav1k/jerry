import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { RatingService } from './rating.service';

class CreateRatingDto {
  @IsInt() @Min(1) @Max(5) stars!: number;
  @IsOptional() @IsString() reviewText?: string;
}

class PageQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number;
}

@Controller('ratings')
export class RatingController {
  constructor(private readonly svc: RatingService) {}

  @Post('consultations/:id')
  @UseGuards(JwtAuthGuard)
  create(
    @CurrentUser() user: JwtPayload,
    @Param('id') consultationId: string,
    @Body() dto: CreateRatingDto,
  ) {
    return this.svc.create(user, consultationId, dto.stars, dto.reviewText);
  }

  @Get('lawyers/:id')
  getLawyerRatings(@Param('id') lawyerId: string, @Query() q: PageQueryDto) {
    return this.svc.getLawyerRatings(lawyerId, q.page, q.limit);
  }
}

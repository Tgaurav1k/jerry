import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { IsIn, IsOptional } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { MediaService } from './media.service';

class UploadUrlQuery {
  @IsOptional()
  @IsIn(['jpg', 'png', 'webp'])
  ext?: 'jpg' | 'png' | 'webp';
}

@Controller('media')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private readonly svc: MediaService) {}

  @Get('photo-upload-url')
  getPhotoUploadUrl(@CurrentUser() user: JwtPayload, @Query() q: UploadUrlQuery) {
    return this.svc.getPhotoUploadUrl(user.sub, q.ext ?? 'jpg');
  }
}

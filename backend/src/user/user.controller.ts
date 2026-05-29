import { Body, Controller, Delete, Get, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { IsString } from 'class-validator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserService } from './user.service';

class FcmDto {
  @IsString() fcmToken!: string;
  @IsString() deviceId!: string;
}

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UserController {
  constructor(private readonly svc: UserService) {}

  @Get('me')
  getMe(@CurrentUser() user: JwtPayload) {
    return this.svc.getMe(user);
  }

  @Patch('me')
  updateMe(@CurrentUser() user: JwtPayload, @Body() dto: UpdateUserDto) {
    return this.svc.updateMe(user, dto);
  }

  @Post('me/fcm')
  registerFcm(@CurrentUser() user: JwtPayload, @Body() dto: FcmDto) {
    return this.svc.registerFcm(user, dto.fcmToken, dto.deviceId);
  }

  /// Unregister this device's FCM token from the currently-authenticated
  /// account. Called by the mobile app right before clearing local tokens
  /// on logout, so push fan-out for the just-logged-out identity stops
  /// hitting this device immediately.
  @Delete('me/fcm')
  unregisterFcm(@CurrentUser() user: JwtPayload, @Body() body: { deviceId: string }) {
    return this.svc.unregisterFcm(user, body.deviceId);
  }
}

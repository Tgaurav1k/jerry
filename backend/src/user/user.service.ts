import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import type { JwtPayload } from '../auth/jwt.strategy';

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(user: JwtPayload) {
    if (user.role !== 'USER') throw new ForbiddenException();
    const u = await this.prisma.user.findUnique({
      where: { id: user.sub },
      select: {
        id: true, email: true, fullName: true,
        preferredLanguage: true, profilePhotoUrl: true,
        city: true, state: true, isSuspended: true, createdAt: true,
      },
    });
    if (!u) throw new NotFoundException();
    return this._ok(u);
  }

  async updateMe(user: JwtPayload, dto: UpdateUserDto) {
    if (user.role !== 'USER') throw new ForbiddenException();
    const u = await this.prisma.user.update({
      where: { id: user.sub },
      data: dto,
      select: {
        id: true, email: true, fullName: true,
        preferredLanguage: true, profilePhotoUrl: true,
        city: true, state: true,
      },
    });
    return this._ok(u);
  }

  async registerFcm(user: JwtPayload, fcmToken: string, deviceId: string) {
    // Self-heal: if this exact FCM token is registered against any OTHER
    // user's/lawyer's deviceSession (e.g. someone previously logged in as a
    // different account on this same device), null it out so push fan-out
    // for the old identity no longer reaches this device. Without this, a
    // phone that was once logged in as USER then becomes LAWYER keeps
    // receiving USER-targeted pushes — including incoming calls.
    await this.prisma.deviceSession.updateMany({
      where: {
        fcmToken,
        NOT: user.role === 'USER'
          ? { userId: user.sub }
          : { lawyerId: user.sub },
      },
      data: { fcmToken: null },
    });

    if (user.role === 'USER') {
      await this.prisma.deviceSession.upsert({
        where: { userId_deviceId: { userId: user.sub, deviceId } },
        update: { fcmToken },
        create: { userId: user.sub, deviceId, fcmToken, role: 'USER' },
      });
    } else if (user.role === 'LAWYER') {
      await this.prisma.deviceSession.upsert({
        where: { lawyerId_deviceId: { lawyerId: user.sub, deviceId } },
        update: { fcmToken },
        create: { lawyerId: user.sub, deviceId, fcmToken, role: 'LAWYER' },
      });
    }
    return this._ok({ registered: true });
  }

  /**
   * Called on explicit logout — clears the FCM token from this device's
   * row so the just-logged-out account stops receiving pushes immediately
   * (don't wait for the next login to self-heal).
   */
  async unregisterFcm(user: JwtPayload, deviceId: string) {
    if (user.role === 'USER') {
      await this.prisma.deviceSession.updateMany({
        where: { userId: user.sub, deviceId },
        data: { fcmToken: null },
      });
    } else if (user.role === 'LAWYER') {
      await this.prisma.deviceSession.updateMany({
        where: { lawyerId: user.sub, deviceId },
        data: { fcmToken: null },
      });
    }
    return this._ok({ unregistered: true });
  }

  private _ok(data: unknown) {
    return { success: true, data, meta: { timestamp: new Date().toISOString() } };
  }
}

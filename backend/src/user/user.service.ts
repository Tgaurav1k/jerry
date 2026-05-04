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

  private _ok(data: unknown) {
    return { success: true, data, meta: { timestamp: new Date().toISOString() } };
  }
}

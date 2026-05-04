import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ConsultationService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyHistory(user: JwtPayload, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const where =
      user.role === 'USER'
        ? { userId: user.sub }
        : user.role === 'LAWYER'
        ? { lawyerId: user.sub }
        : null;

    if (!where) throw new ForbiddenException();

    const [total, rows] = await this.prisma.$transaction([
      this.prisma.consultation.count({ where }),
      this.prisma.consultation.findMany({
        where,
        orderBy: { startedAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: { select: { id: true, fullName: true, profilePhotoUrl: true } },
          lawyer: { select: { id: true, fullName: true, profilePhotoUrl: true } },
          rating: { select: { stars: true, reviewText: true } },
        },
      }),
    ]);

    return this._ok({ items: rows, total, page, limit });
  }

  async getDetail(user: JwtPayload, consultationId: string) {
    const c = await this.prisma.consultation.findUnique({
      where: { id: consultationId },
      include: {
        user: { select: { id: true, fullName: true, profilePhotoUrl: true } },
        lawyer: { select: { id: true, fullName: true, profilePhotoUrl: true } },
        rating: true,
      },
    });
    if (!c) throw new NotFoundException();

    const canView =
      (user.role === 'USER' && c.userId === user.sub) ||
      (user.role === 'LAWYER' && c.lawyerId === user.sub) ||
      user.role === 'ADMIN';

    if (!canView) throw new ForbiddenException();
    return this._ok(c);
  }

  private _ok(data: unknown) {
    return { success: true, data, meta: { timestamp: new Date().toISOString() } };
  }
}

import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class RatingService {
  constructor(private readonly prisma: PrismaService) {}

  async create(user: JwtPayload, consultationId: string, stars: number, reviewText?: string) {
    if (user.role !== 'USER') throw new ForbiddenException('Only clients can rate');
    if (stars < 1 || stars > 5) throw new BadRequestException('Stars must be 1-5');
    if (stars < 4 && !reviewText) throw new BadRequestException('Review text required for ratings below 4 stars');

    const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
    if (!c) throw new NotFoundException('Consultation not found');
    if (c.userId !== user.sub) throw new ForbiddenException();
    if (c.status !== 'ENDED') throw new BadRequestException('Can only rate ended consultations');

    const existing = await this.prisma.rating.findUnique({ where: { consultationId } });
    if (existing) throw new ConflictException('Already rated this consultation');

    const rating = await this.prisma.rating.create({
      data: {
        consultationId,
        userId: user.sub,
        lawyerId: c.lawyerId,
        stars,
        reviewText,
      },
    });

    // Atomically recompute lawyer aggregates
    const allRatings = await this.prisma.rating.findMany({
      where: { lawyerId: c.lawyerId },
      select: { stars: true },
    });
    const total = allRatings.length;
    const avg = allRatings.reduce((sum, r) => sum + r.stars, 0) / total;

    await this.prisma.lawyer.update({
      where: { id: c.lawyerId },
      data: {
        avgRating: Math.round(avg * 100) / 100,
        totalRatings: total,
      },
    });

    return {
      success: true,
      data: { id: rating.id, stars, reviewText, consultationId },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async getLawyerRatings(lawyerId: string, page = 1, limit = 20) {
    const skip = (page - 1) * limit;
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.rating.count({ where: { lawyerId } }),
      this.prisma.rating.findMany({
        where: { lawyerId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: { user: { select: { id: true, fullName: true, profilePhotoUrl: true } } },
      }),
    ]);
    return {
      success: true,
      data: { items: rows, total, page, limit },
      meta: { timestamp: new Date().toISOString() },
    };
  }
}

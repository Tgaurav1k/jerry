import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { LawyerQueryDto } from './dto/lawyer-query.dto';
import { UpdateLawyerDto } from './dto/update-lawyer.dto';

const PRESENCE_TTL = 300; // 5 min — auto-offline after no heartbeat

@Injectable()
export class LawyerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  // ─── Public list (user-facing) ─────────────────────────────────────────────

  async listPublic(query: LawyerQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = {
      verificationStatus: 'APPROVED',
      isSuspended: false,
    };
    if (query.onlineOnly) where.isOnline = true;
    if (query.city) where.city = { contains: query.city, mode: 'insensitive' };
    if (query.state) where.state = { contains: query.state, mode: 'insensitive' };
    if (query.language) {
      where.languagesSpoken = { has: query.language };
    }

    const whereWithSpecialty = query.specialtyId
      ? { ...where, specialties: { some: { specialtyId: query.specialtyId } } }
      : where;

    const [total, rows] = await this.prisma.$transaction([
      this.prisma.lawyer.count({ where: whereWithSpecialty as any }),
      this.prisma.lawyer.findMany({
        where: whereWithSpecialty as any,
        orderBy: [
          { isOnline: 'desc' },
          { avgRating: 'desc' },
          { totalRatings: 'desc' },
          { id: 'asc' },
        ],
        skip,
        take: limit,
        select: {
          id: true,
          fullName: true,
          profilePhotoUrl: true,
          city: true,
          state: true,
          avgRating: true,
          totalRatings: true,
          totalConsultations: true,
          isOnline: true,
          languagesSpoken: true,
          yearsExperience: true,
          bio: true,
          specialties: {
            select: { specialty: { select: { id: true, name: true } } },
          },
        },
      }),
    ]);

    const data = rows.map((l) => ({
      ...l,
      specialties: l.specialties.map((s) => s.specialty),
    }));

    return {
      success: true,
      data: { items: data, total, page, limit },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Public detail ─────────────────────────────────────────────────────────

  async getPublic(id: string) {
    const l = await this.prisma.lawyer.findUnique({
      where: { id },
      select: {
        id: true, fullName: true, profilePhotoUrl: true, bio: true,
        city: true, state: true, avgRating: true, totalRatings: true,
        totalConsultations: true, isOnline: true, languagesSpoken: true,
        yearsExperience: true, verificationStatus: true,
        specialties: { select: { specialty: { select: { id: true, name: true } } } },
      },
    });
    if (!l || l.verificationStatus !== 'APPROVED') throw new NotFoundException();
    return this._ok({ ...l, specialties: l.specialties.map((s) => s.specialty) });
  }

  // ─── My profile (lawyer self) ──────────────────────────────────────────────

  async getMyProfile(user: JwtPayload) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();
    const l = await this.prisma.lawyer.findUnique({
      where: { id: user.sub },
      select: {
        id: true, email: true, fullName: true, profilePhotoUrl: true, bio: true,
        city: true, state: true, preferredLanguage: true, avgRating: true,
        totalRatings: true, totalConsultations: true, isOnline: true,
        languagesSpoken: true, yearsExperience: true, verificationStatus: true,
        rejectionReason: true, licenseNumber: true, isSuspended: true, createdAt: true,
        specialties: { select: { specialty: { select: { id: true, name: true } } } },
      },
    });
    if (!l) throw new NotFoundException();
    return this._ok({ ...l, specialties: l.specialties.map((s) => s.specialty) });
  }

  // ─── Update profile ────────────────────────────────────────────────────────

  async updateMyProfile(user: JwtPayload, dto: UpdateLawyerDto) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();
    const { languagesSpoken, ...rest } = dto;
    const l = await this.prisma.lawyer.update({
      where: { id: user.sub },
      data: { ...rest, ...(languagesSpoken ? { languagesSpoken } : {}) },
      select: {
        id: true, fullName: true, profilePhotoUrl: true, bio: true,
        city: true, state: true, languagesSpoken: true, yearsExperience: true,
      },
    });
    return this._ok(l);
  }

  // ─── Specialties ───────────────────────────────────────────────────────────

  async setSpecialties(user: JwtPayload, specialtyIds: string[]) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();
    await this.prisma.$transaction([
      this.prisma.lawyerSpecialty.deleteMany({ where: { lawyerId: user.sub } }),
      this.prisma.lawyerSpecialty.createMany({
        data: specialtyIds.map((specialtyId) => ({ lawyerId: user.sub, specialtyId })),
        skipDuplicates: true,
      }),
    ]);
    return this._ok({ updated: true });
  }

  // ─── Heartbeat / availability ──────────────────────────────────────────────

  async heartbeat(lawyerId: string, isOnline: boolean) {
    await this.prisma.lawyer.update({
      where: { id: lawyerId },
      data: { isOnline, lastHeartbeatAt: new Date() },
    });
    if (isOnline) {
      await this.redis.set(`presence:lawyer:${lawyerId}`, '1', PRESENCE_TTL);
    } else {
      await this.redis.del(`presence:lawyer:${lawyerId}`);
    }
    return this._ok({ isOnline });
  }

  async setAvailability(user: JwtPayload, isOnline: boolean) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();
    return this.heartbeat(user.sub, isOnline);
  }

  // ─── All specialties catalog ───────────────────────────────────────────────

  async listSpecialties() {
    const rows = await this.prisma.specialty.findMany({ orderBy: { name: 'asc' } });
    return this._ok(rows);
  }

  private _ok(data: unknown) {
    return { success: true, data, meta: { timestamp: new Date().toISOString() } };
  }
}

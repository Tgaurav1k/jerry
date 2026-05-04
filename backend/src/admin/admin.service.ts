import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  private _requireAdmin(user: JwtPayload) {
    if (user.role !== 'ADMIN') throw new ForbiddenException();
  }

  // ─── Pending verification queue ───────────────────────────────────────────

  async getPendingQueue(user: JwtPayload, page = 1, limit = 20) {
    this._requireAdmin(user);
    const skip = (page - 1) * limit;
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.lawyer.count({ where: { verificationStatus: 'PENDING_REVIEW' } }),
      this.prisma.lawyer.findMany({
        where: { verificationStatus: 'PENDING_REVIEW' },
        orderBy: { createdAt: 'asc' },
        skip,
        take: limit,
        select: {
          id: true, fullName: true, email: true, city: true, state: true,
          licenseNumber: true, licenseFileMime: true, createdAt: true,
        },
      }),
    ]);
    return this._ok({ items: rows, total, page, limit });
  }

  // ─── Approve lawyer ────────────────────────────────────────────────────────

  async approveLawyer(user: JwtPayload, lawyerId: string) {
    this._requireAdmin(user);
    const lawyer = await this.prisma.lawyer.findUnique({ where: { id: lawyerId } });
    if (!lawyer) throw new NotFoundException('Lawyer not found');
    if (lawyer.verificationStatus !== 'PENDING_REVIEW') {
      throw new BadRequestException('Lawyer is not in PENDING_REVIEW state');
    }

    await this.prisma.lawyer.update({
      where: { id: lawyerId },
      data: { verificationStatus: 'APPROVED', rejectionReason: null },
    });

    await this._audit(user.sub, 'LAWYER_APPROVED', 'LAWYER', lawyerId);
    return this._ok({ lawyerId, verificationStatus: 'APPROVED' });
  }

  // ─── Reject lawyer ─────────────────────────────────────────────────────────

  async rejectLawyer(user: JwtPayload, lawyerId: string, reason: string) {
    this._requireAdmin(user);
    const lawyer = await this.prisma.lawyer.findUnique({ where: { id: lawyerId } });
    if (!lawyer) throw new NotFoundException('Lawyer not found');

    await this.prisma.lawyer.update({
      where: { id: lawyerId },
      data: { verificationStatus: 'REJECTED', rejectionReason: reason },
    });

    await this._audit(user.sub, 'LAWYER_REJECTED', 'LAWYER', lawyerId, reason);
    return this._ok({ lawyerId, verificationStatus: 'REJECTED' });
  }

  // ─── Suspend / unsuspend ───────────────────────────────────────────────────

  async suspendUser(user: JwtPayload, targetId: string, suspend: boolean, targetType: 'USER' | 'LAWYER') {
    this._requireAdmin(user);
    if (targetType === 'USER') {
      const u = await this.prisma.user.findUnique({ where: { id: targetId } });
      if (!u) throw new NotFoundException();
      await this.prisma.user.update({ where: { id: targetId }, data: { isSuspended: suspend } });
    } else {
      const l = await this.prisma.lawyer.findUnique({ where: { id: targetId } });
      if (!l) throw new NotFoundException();
      await this.prisma.lawyer.update({ where: { id: targetId }, data: { isSuspended: suspend } });
    }

    const action = suspend
      ? targetType === 'USER' ? 'USER_SUSPENDED' : 'LAWYER_SUSPENDED'
      : targetType === 'USER' ? 'USER_UNSUSPENDED' : 'LAWYER_UNSUSPENDED';

    await this._audit(user.sub, action, targetType, targetId);
    return this._ok({ targetId, suspended: suspend });
  }

  // ─── User directory ────────────────────────────────────────────────────────

  async listUsers(user: JwtPayload, page = 1, limit = 20) {
    this._requireAdmin(user);
    const skip = (page - 1) * limit;
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.user.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        select: {
          id: true, email: true, fullName: true, city: true, state: true,
          isSuspended: true, createdAt: true,
        },
      }),
    ]);
    return this._ok({ items: rows, total, page, limit });
  }

  async listLawyers(user: JwtPayload, page = 1, limit = 20) {
    this._requireAdmin(user);
    const skip = (page - 1) * limit;
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.lawyer.count(),
      this.prisma.lawyer.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        select: {
          id: true, email: true, fullName: true, city: true, state: true,
          verificationStatus: true, isSuspended: true, avgRating: true,
          totalConsultations: true, createdAt: true,
        },
      }),
    ]);
    return this._ok({ items: rows, total, page, limit });
  }

  // ─── Audit log ─────────────────────────────────────────────────────────────

  async getAuditLog(user: JwtPayload, page = 1, limit = 30) {
    this._requireAdmin(user);
    const skip = (page - 1) * limit;
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.auditLog.count(),
      this.prisma.auditLog.findMany({
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: { admin: { select: { id: true, fullName: true, email: true } } },
      }),
    ]);
    return this._ok({ items: rows, total, page, limit });
  }

  // ─── Super admin: admin CRUD ───────────────────────────────────────────────

  async createAdmin(user: JwtPayload, email: string, fullName: string, password: string) {
    this._requireAdmin(user);
    const me = await this.prisma.admin.findUnique({ where: { id: user.sub } });
    if (!me?.isSuperAdmin) throw new ForbiddenException('Only superadmin can create admins');

    const existing = await this.prisma.admin.findUnique({ where: { email } });
    if (existing) throw new BadRequestException('Email already taken');

    const passwordHash = await bcrypt.hash(password, 12);
    const admin = await this.prisma.admin.create({
      data: { email, fullName, passwordHash },
      select: { id: true, email: true, fullName: true, isActive: true, createdAt: true },
    });

    await this._audit(user.sub, 'ADMIN_CREATED', 'ADMIN', admin.id);
    return this._ok(admin);
  }

  async listAdmins(user: JwtPayload) {
    this._requireAdmin(user);
    const me = await this.prisma.admin.findUnique({ where: { id: user.sub } });
    if (!me?.isSuperAdmin) throw new ForbiddenException('Only superadmin can list admins');

    const rows = await this.prisma.admin.findMany({
      orderBy: { createdAt: 'asc' },
      select: { id: true, email: true, fullName: true, isSuperAdmin: true, isActive: true, createdAt: true },
    });
    return this._ok(rows);
  }

  async toggleAdmin(user: JwtPayload, adminId: string, isActive: boolean) {
    this._requireAdmin(user);
    const me = await this.prisma.admin.findUnique({ where: { id: user.sub } });
    if (!me?.isSuperAdmin) throw new ForbiddenException('Only superadmin');
    await this.prisma.admin.update({ where: { id: adminId }, data: { isActive } });
    await this._audit(user.sub, isActive ? 'ADMIN_ACTIVATED' : 'ADMIN_DEACTIVATED', 'ADMIN', adminId);
    return this._ok({ adminId, isActive });
  }

  // ─── Dashboard ─────────────────────────────────────────────────────────────

  async getDashboard(user: JwtPayload) {
    this._requireAdmin(user);
    const [
      totalUsers,
      totalLawyers,
      approvedLawyers,
      pendingReview,
      totalConsultations,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.lawyer.count(),
      this.prisma.lawyer.count({ where: { verificationStatus: 'APPROVED' } }),
      this.prisma.lawyer.count({ where: { verificationStatus: 'PENDING_REVIEW' } }),
      this.prisma.consultation.count(),
    ]);
    return this._ok({ totalUsers, totalLawyers, approvedLawyers, pendingReview, totalConsultations });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private async _audit(adminId: string, action: string, targetType?: string, targetId?: string, notes?: string) {
    await this.prisma.auditLog.create({
      data: { adminId, action, targetType, targetId, notes },
    });
  }

  private _ok(data: unknown) {
    return { success: true, data, meta: { timestamp: new Date().toISOString() } };
  }
}

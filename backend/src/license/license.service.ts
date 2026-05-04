import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { JwtPayload } from '../auth/jwt.strategy';
import { PrismaService } from '../prisma/prisma.service';

const MAX_LICENSE_BYTES = 5 * 1024 * 1024; // 5 MB

@Injectable()
export class LicenseService {
  constructor(private readonly prisma: PrismaService) {}

  async upload(user: JwtPayload, file: Express.Multer.File, licenseNumber?: string) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();

    if (file.size > MAX_LICENSE_BYTES) {
      throw new BadRequestException('License file exceeds 5 MB limit');
    }

    const allowedMimes = ['image/jpeg', 'image/png', 'application/pdf'];
    if (!allowedMimes.includes(file.mimetype)) {
      throw new BadRequestException('Only JPEG, PNG, or PDF files are accepted');
    }

    await this.prisma.lawyer.update({
      where: { id: user.sub },
      data: {
        licenseData: file.buffer,
        licenseFileMime: file.mimetype,
        verificationStatus: 'PENDING_REVIEW',
        ...(licenseNumber?.trim() ? { licenseNumber: licenseNumber.trim() } : {}),
      },
    });

    return {
      success: true,
      data: { verificationStatus: 'PENDING_REVIEW' },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async streamLicense(lawyerId: string, admin: JwtPayload) {
    if (admin.role !== 'ADMIN') throw new ForbiddenException();

    const lawyer = await this.prisma.lawyer.findUnique({
      where: { id: lawyerId },
      select: { licenseData: true, licenseFileMime: true },
    });

    if (!lawyer || !lawyer.licenseData) throw new NotFoundException('No license on file');

    return {
      buffer: lawyer.licenseData,
      mime: lawyer.licenseFileMime ?? 'application/octet-stream',
    };
  }
}

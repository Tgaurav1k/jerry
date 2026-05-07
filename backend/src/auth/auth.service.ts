import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import * as nodemailer from 'nodemailer';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto, LoginRole } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { SignupDto, SignupRole } from './dto/signup.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';

export type JwtRole = 'USER' | 'LAWYER' | 'ADMIN';

const OTP_TTL = 600; // 10 min
const OTP_MAX_ATTEMPTS = 5;
const REFRESH_TTL_DAYS = 30;
const ACCESS_TTL_SECONDS = 900; // 15 min

@Injectable()
export class AuthService {
  private mailer!: nodemailer.Transporter;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly redis: RedisService,
    private readonly config: ConfigService,
  ) {
    this.mailer = nodemailer.createTransport({
      host: config.get('SMTP_HOST', 'smtp.brevo.com'),
      port: config.get<number>('SMTP_PORT', 587),
      auth: {
        user: config.get('SMTP_USER', ''),
        pass: config.get('SMTP_PASS', ''),
      },
    });
  }

  // ─── Signup ────────────────────────────────────────────────────────────────

  async signup(dto: SignupDto) {
    const email = dto.email.toLowerCase().trim();

    const existingUser = await this.prisma.user.findUnique({ where: { email } });
    const existingLawyer = await this.prisma.lawyer.findUnique({ where: { email } });
    if (existingUser || existingLawyer) {
      throw new ConflictException('Email already registered');
    }

    const pending = await this.redis.get(`pending_signup:${email}`);
    if (pending) {
      const data = JSON.parse(pending);
      if (Date.now() - data.createdAt < 30_000) {
        throw new ConflictException('OTP already sent. Wait 30 seconds before requesting again.');
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const otp = this._generateOtp();
    const otpHash = crypto.createHash('sha256').update(otp).digest('hex');

    await this.redis.set(
      `pending_signup:${email}`,
      JSON.stringify({
        role: dto.role,
        email,
        passwordHash,
        fullName: dto.fullName,
        preferredLanguage: dto.preferredLanguage ?? 'English',
        city: dto.city ?? null,
        state: dto.state ?? null,
        deviceId: dto.deviceId ?? null,
        otpHash,
        attempts: 0,
        createdAt: Date.now(),
      }),
      OTP_TTL,
    );

    await this._sendOtp(email, otp, 'Email Verification');

    return { success: true, data: { message: 'OTP sent to email' }, meta: { timestamp: new Date().toISOString() } };
  }

  // ─── Verify OTP ────────────────────────────────────────────────────────────

  async verifyOtp(dto: VerifyOtpDto) {
    const email = dto.email.toLowerCase().trim();
    const raw = await this.redis.get(`pending_signup:${email}`);
    if (!raw) throw new BadRequestException('OTP expired or not found');

    const data = JSON.parse(raw);

    data.attempts = (data.attempts ?? 0) + 1;
    if (data.attempts > OTP_MAX_ATTEMPTS) {
      await this.redis.del(`pending_signup:${email}`);
      throw new BadRequestException('Too many incorrect attempts. Please signup again.');
    }

    const inputHash = crypto.createHash('sha256').update(dto.otp).digest('hex');
    if (inputHash !== data.otpHash) {
      await this.redis.set(`pending_signup:${email}`, JSON.stringify(data), OTP_TTL);
      throw new BadRequestException('Invalid OTP');
    }

    await this.redis.del(`pending_signup:${email}`);

    let id: string;
    let role: JwtRole;

    if (data.role === SignupRole.USER) {
      const user = await this.prisma.user.create({
        data: {
          email: data.email,
          passwordHash: data.passwordHash,
          fullName: data.fullName,
          preferredLanguage: data.preferredLanguage,
          city: data.city,
          state: data.state,
        },
      });
      id = user.id;
      role = 'USER';
    } else {
      const lawyer = await this.prisma.lawyer.create({
        data: {
          email: data.email,
          passwordHash: data.passwordHash,
          fullName: data.fullName,
          preferredLanguage: data.preferredLanguage,
          city: data.city,
          state: data.state,
          verificationStatus: 'PENDING_UPLOAD',
        },
      });
      id = lawyer.id;
      role = 'LAWYER';
    }

    const { accessToken, refreshToken } = await this._issueTokens(id, role, data.email, data.deviceId);

    return {
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: { id, email: data.email, fullName: data.fullName, role },
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Resend OTP ────────────────────────────────────────────────────────────

  async resendOtp(email: string) {
    email = email.toLowerCase().trim();
    const raw = await this.redis.get(`pending_signup:${email}`);
    if (!raw) throw new BadRequestException('No pending signup for this email');

    const data = JSON.parse(raw);
    if (Date.now() - data.createdAt < 30_000) {
      throw new ConflictException('Wait 30 seconds before requesting another OTP');
    }

    const otp = this._generateOtp();
    data.otpHash = crypto.createHash('sha256').update(otp).digest('hex');
    data.attempts = 0;
    data.createdAt = Date.now();

    await this.redis.set(`pending_signup:${email}`, JSON.stringify(data), OTP_TTL);
    await this._sendOtp(email, otp, 'Email Verification');

    return { success: true, data: { message: 'OTP resent' }, meta: { timestamp: new Date().toISOString() } };
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  async login(dto: LoginDto) {
    const email = dto.email.toLowerCase().trim();
    let id: string;
    let fullName: string;
    let role: JwtRole;

    if (dto.role === LoginRole.ADMIN) {
      const admin = await this.prisma.admin.findUnique({ where: { email } });
      if (!admin || !admin.isActive) throw new UnauthorizedException('Invalid credentials');
      const ok = await bcrypt.compare(dto.password, admin.passwordHash);
      if (!ok) throw new UnauthorizedException('Invalid credentials');
      id = admin.id;
      fullName = admin.fullName;
      role = 'ADMIN';
    } else if (dto.role === LoginRole.USER) {
      const user = await this.prisma.user.findUnique({ where: { email } });
      if (!user) throw new UnauthorizedException('Invalid credentials');
      if (user.isSuspended) throw new UnauthorizedException('Account suspended');
      const ok = await bcrypt.compare(dto.password, user.passwordHash);
      if (!ok) throw new UnauthorizedException('Invalid credentials');
      id = user.id;
      fullName = user.fullName;
      role = 'USER';
    } else {
      // LAWYER
      const lawyer = await this.prisma.lawyer.findUnique({ where: { email } });
      if (!lawyer) throw new UnauthorizedException('Invalid credentials');
      if (lawyer.isSuspended) throw new UnauthorizedException('Account suspended');
      const ok = await bcrypt.compare(dto.password, lawyer.passwordHash);
      if (!ok) throw new UnauthorizedException('Invalid credentials');
      id = lawyer.id;
      fullName = lawyer.fullName;
      role = 'LAWYER';

      // Return verification status for not-yet-approved lawyers
      if (lawyer.verificationStatus !== 'APPROVED') {
        const { accessToken, refreshToken } = await this._issueTokens(id, role, email, dto.deviceId);
        return {
          success: true,
          data: {
            accessToken,
            refreshToken,
            user: { id, email, fullName, role, verificationStatus: lawyer.verificationStatus },
          },
          meta: { timestamp: new Date().toISOString() },
        };
      }
    }

    // Device conflict check
    if (dto.deviceId) {
      const existingSession = await this.prisma.deviceSession.findFirst({
        where: role === 'USER'
          ? { userId: id, deviceId: { not: dto.deviceId } }
          : role === 'LAWYER'
          ? { lawyerId: id, deviceId: { not: dto.deviceId } }
          : { adminId: id, deviceId: { not: dto.deviceId } },
      });

      if (existingSession && !dto.forceLogout) {
        throw new ConflictException({
          code: 'DEVICE_CONFLICT',
          message: 'Already logged in on another device',
        });
      }

      if (existingSession && dto.forceLogout) {
        // Revoke all existing refresh tokens for this identity
        await this.prisma.refreshToken.deleteMany({
          where: role === 'USER'
            ? { userId: id }
            : role === 'LAWYER'
            ? { lawyerId: id }
            : { adminId: id },
        });
        // Remove old device sessions
        await this.prisma.deviceSession.deleteMany({
          where: role === 'USER'
            ? { userId: id }
            : role === 'LAWYER'
            ? { lawyerId: id }
            : { adminId: id },
        });
      }
    }

    const { accessToken, refreshToken } = await this._issueTokens(id, role, email, dto.deviceId);

    return {
      success: true,
      data: {
        accessToken,
        refreshToken,
        user: { id, email, fullName, role, ...(role === 'LAWYER' && { verificationStatus: 'APPROVED' }) },
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Refresh ───────────────────────────────────────────────────────────────

  async refresh(dto: RefreshDto) {
    const stored = await this.prisma.refreshToken.findUnique({ where: { token: dto.refreshToken } });
    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Rotate: delete old, issue new
    await this.prisma.refreshToken.delete({ where: { id: stored.id } });

    let email: string;
    let role: JwtRole;
    const id = stored.userId ?? stored.lawyerId ?? stored.adminId!;

    if (stored.userId) {
      const user = await this.prisma.user.findUnique({ where: { id: stored.userId } });
      if (!user || user.isSuspended) throw new UnauthorizedException('Account invalid');
      email = user.email;
      role = 'USER';
    } else if (stored.lawyerId) {
      const lawyer = await this.prisma.lawyer.findUnique({ where: { id: stored.lawyerId } });
      if (!lawyer || lawyer.isSuspended) throw new UnauthorizedException('Account invalid');
      email = lawyer.email;
      role = 'LAWYER';
    } else {
      const admin = await this.prisma.admin.findUnique({ where: { id: stored.adminId! } });
      if (!admin || !admin.isActive) throw new UnauthorizedException('Account invalid');
      email = admin.email;
      role = 'ADMIN';
    }

    const { accessToken, refreshToken } = await this._issueTokens(id, role, email, dto.deviceId ?? stored.deviceId ?? undefined);

    return {
      success: true,
      data: { accessToken, refreshToken },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  async logout(refreshToken: string, userId: string, role: JwtRole) {
    await this.prisma.refreshToken.deleteMany({ where: { token: refreshToken } });
    return { success: true, data: { message: 'Logged out' }, meta: { timestamp: new Date().toISOString() } };
  }

  // ─── Forgot password ───────────────────────────────────────────────────────

  async forgotPassword(dto: ForgotPasswordDto) {
    const email = dto.email.toLowerCase().trim();
    let exists = false;

    if (dto.role === SignupRole.USER) {
      exists = !!(await this.prisma.user.findUnique({ where: { email } }));
    } else {
      exists = !!(await this.prisma.lawyer.findUnique({ where: { email } }));
    }

    if (!exists) throw new NotFoundException('Email not found');

    const otp = this._generateOtp();
    const otpHash = crypto.createHash('sha256').update(otp).digest('hex');

    await this.redis.set(
      `reset_otp:${email}`,
      JSON.stringify({ role: dto.role, otpHash, attempts: 0, createdAt: Date.now() }),
      OTP_TTL,
    );

    await this._sendOtp(email, otp, 'Password Reset');

    return { success: true, data: { message: 'OTP sent to email' }, meta: { timestamp: new Date().toISOString() } };
  }

  // ─── Reset password ────────────────────────────────────────────────────────

  async resetPassword(dto: ResetPasswordDto) {
    const email = dto.email.toLowerCase().trim();
    const raw = await this.redis.get(`reset_otp:${email}`);
    if (!raw) throw new BadRequestException('OTP expired or not found');

    const data = JSON.parse(raw);
    data.attempts = (data.attempts ?? 0) + 1;
    if (data.attempts > OTP_MAX_ATTEMPTS) {
      await this.redis.del(`reset_otp:${email}`);
      throw new BadRequestException('Too many attempts');
    }

    const inputHash = crypto.createHash('sha256').update(dto.otp).digest('hex');
    if (inputHash !== data.otpHash) {
      await this.redis.set(`reset_otp:${email}`, JSON.stringify(data), OTP_TTL);
      throw new BadRequestException('Invalid OTP');
    }

    await this.redis.del(`reset_otp:${email}`);

    const newHash = await bcrypt.hash(dto.newPassword, 12);

    if (dto.role === SignupRole.USER) {
      await this.prisma.user.update({ where: { email }, data: { passwordHash: newHash } });
    } else {
      await this.prisma.lawyer.update({ where: { email }, data: { passwordHash: newHash } });
    }

    // Revoke all refresh tokens for security
    const target = dto.role === SignupRole.USER
      ? await this.prisma.user.findUnique({ where: { email } })
      : await this.prisma.lawyer.findUnique({ where: { email } });

    if (target) {
      if (dto.role === SignupRole.USER) {
        await this.prisma.refreshToken.deleteMany({ where: { userId: target.id } });
      } else {
        await this.prisma.refreshToken.deleteMany({ where: { lawyerId: target.id } });
      }
    }

    return { success: true, data: { message: 'Password updated' }, meta: { timestamp: new Date().toISOString() } };
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private _generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private async _sendOtp(email: string, otp: string, subject: string) {
    const smtpUser = this.config.get('SMTP_USER', '');
    if (!smtpUser) {
      // Dev mode: just log
      console.log(`[OTP] ${email} → ${otp} (${subject})`);
      return;
    }

    await this.mailer.sendMail({
      from: this.config.get('EMAIL_FROM', 'noreply@jerry.in'),
      to: email,
      subject: `Jerry — ${subject} OTP`,
      text: `Your OTP is ${otp}. Valid for 10 minutes.`,
      html: `<p>Your OTP is <strong>${otp}</strong>. Valid for 10 minutes.</p>`,
    });
  }

  async _issueTokens(id: string, role: JwtRole, email: string, deviceId?: string) {
    const accessToken = await this.jwt.signAsync(
      { sub: id, role, email },
      { expiresIn: ACCESS_TTL_SECONDS },
    );

    const refreshToken = crypto.randomBytes(48).toString('hex');
    const expiresAt = new Date(Date.now() + REFRESH_TTL_DAYS * 24 * 3600 * 1000);

    const data: Record<string, unknown> = { token: refreshToken, expiresAt, deviceId: deviceId ?? null };
    if (role === 'USER') data.userId = id;
    else if (role === 'LAWYER') data.lawyerId = id;
    else data.adminId = id;

    await this.prisma.refreshToken.create({ data: data as any });

    // Upsert device session with FCM token placeholder
    if (deviceId) {
      const sessionData: Record<string, unknown> = {
        deviceId,
        role: role === 'ADMIN' ? 'ADMIN' : role,
      };
      if (role === 'USER') {
        sessionData.userId = id;
        await this.prisma.deviceSession.upsert({
          where: { userId_deviceId: { userId: id, deviceId } },
          update: { updatedAt: new Date() },
          create: sessionData as any,
        });
      } else if (role === 'LAWYER') {
        sessionData.lawyerId = id;
        await this.prisma.deviceSession.upsert({
          where: { lawyerId_deviceId: { lawyerId: id, deviceId } },
          update: { updatedAt: new Date() },
          create: sessionData as any,
        });
      }
    }

    return { accessToken, refreshToken };
  }
}

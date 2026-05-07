import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConsultationStatus, ConsultationType } from '@prisma/client';
import { randomUUID } from 'crypto';
import type { JwtPayload } from '../auth/jwt.strategy';
import { ChatGateway } from '../chat/chat.gateway';
import { ChatService } from '../chat/chat.service';
import { NotificationService } from '../notification/notification.service';
import { PrismaService } from '../prisma/prisma.service';
import { AgoraService } from './agora.service';
import { agoraUidFromString } from './agora.util';

@Injectable()
export class CallService {
  /** lawyerId -> consultationId while ringing/active */
  private readonly busy = new Map<string, string>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly agora: AgoraService,
    private readonly gateway: ChatGateway,
    private readonly chat: ChatService,
    private readonly notifications: NotificationService,
  ) {}

  async initiate(user: JwtPayload, lawyerId: string, type: 'VIDEO' | 'VOICE') {
    if (user.role !== 'USER') throw new ForbiddenException('Only clients can start calls');

    const lawyer = await this.prisma.lawyer.findUnique({ where: { id: lawyerId } });
    if (!lawyer || lawyer.isSuspended || lawyer.verificationStatus !== 'APPROVED') {
      throw new NotFoundException('Lawyer not found');
    }
    const consultationType: ConsultationType = type === 'VIDEO' ? 'VIDEO' : 'VOICE';
    const client = await this.prisma.user.findUnique({ where: { id: user.sub } });
    const callerName = client?.fullName ?? 'Client';

    // Lawyer is offline or already in a call — record missed call and return immediately
    if (!lawyer.isOnline || this.busy.has(lawyerId)) {
      const row = await this.prisma.consultation.create({
        data: {
          userId: user.sub,
          lawyerId,
          type: consultationType,
          status: ConsultationStatus.MISSED,
        },
      });
      await this.chat.saveMissedCall(user.sub, lawyerId, row.id, type);
      return {
        success: true,
        data: { consultationId: row.id, missed: true },
        meta: { timestamp: new Date().toISOString() },
      };
    }

    const channelName = `consult_${randomUUID()}`;

    const row = await this.prisma.consultation.create({
      data: {
        userId: user.sub,
        lawyerId,
        type: consultationType,
        status: ConsultationStatus.RINGING,
        agoraChannelName: channelName,
      },
    });

    this.busy.set(lawyerId, row.id);

    const userUid = agoraUidFromString(user.sub);
    const lawyerUid = agoraUidFromString(lawyerId);
    const userToken = this.agora.buildRtcToken(channelName, userUid);
    const lawyerToken = this.agora.buildRtcToken(channelName, lawyerUid);

    this.gateway.emitToLawyer(lawyerId, 'call:incoming', {
      consultationId: row.id,
      callerId:       user.sub,
      channelName,
      token:          lawyerToken,
      uid:            lawyerUid,
      callerName,
      callerPhotoUrl: client?.profilePhotoUrl ?? null,
      type:           consultationType,
    });

    // Push notification for lawyer (in case app is in background)
    this.notifications.sendToLawyer(
      lawyerId,
      `📞 Incoming ${type === 'VIDEO' ? 'Video' : 'Voice'} Call`,
      `${callerName} is calling you`,
      { type: 'call:incoming', consultationId: row.id },
    ).catch(() => {});

    return {
      success: true,
      data: {
        consultationId: row.id,
        agoraChannelName: channelName,
        agoraToken: userToken,
        uid: userUid,
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async accept(user: JwtPayload, consultationId: string) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();

    const c = await this.prisma.consultation.findUnique({
      where: { id: consultationId },
      include: { lawyer: true },
    });
    if (!c || c.lawyerId !== user.sub) throw new NotFoundException();
    if (c.status !== ConsultationStatus.RINGING) {
      throw new ConflictException('Call not ringing');
    }

    await this.prisma.consultation.update({
      where: { id: consultationId },
      data: { status: ConsultationStatus.ACTIVE, startedAt: new Date() },
    });

    const channelName = c.agoraChannelName ?? '';
    const lawyerUid = agoraUidFromString(user.sub);
    const lawyerToken = this.agora.buildRtcToken(channelName, lawyerUid);

    return {
      success: true,
      data: {
        consultationId: c.id,
        agoraChannelName: channelName,
        agoraToken: lawyerToken,
        uid: lawyerUid,
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async reject(user: JwtPayload, consultationId: string) {
    if (user.role !== 'LAWYER') throw new ForbiddenException();

    const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
    if (!c || c.lawyerId !== user.sub) throw new NotFoundException();
    if (c.status !== ConsultationStatus.RINGING) {
      throw new ConflictException('Call not ringing');
    }

    await this.prisma.consultation.update({
      where: { id: consultationId },
      data: { status: ConsultationStatus.REJECTED_BY_LAWYER },
    });

    this.busy.delete(c.lawyerId);

    // Persist declined record so caller sees it in history after restart
    await this.chat.saveCallRecord(
      c.userId, c.lawyerId, consultationId,
      c.type as 'VIDEO' | 'VOICE',
      'declined', 0,
    ).catch(() => {});

    this.gateway.emitToUser(c.userId, 'call:rejected', { consultationId });

    return {
      success: true,
      data: { consultationId },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async end(user: JwtPayload, consultationId: string) {
    const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
    if (!c) throw new NotFoundException();
    const okUser = user.role === 'USER' && c.userId === user.sub;
    const okLawyer = user.role === 'LAWYER' && c.lawyerId === user.sub;
    if (!okUser && !okLawyer) throw new ForbiddenException();

    const ended = new Date();
    const started = c.startedAt;
    const durationSeconds = started
      ? Math.max(0, Math.floor((ended.getTime() - started.getTime()) / 1000))
      : 0;

    await this.prisma.consultation.update({
      where: { id: consultationId },
      data: {
        status: ConsultationStatus.ENDED,
        endedAt: ended,
        durationSeconds,
      },
    });

    this.busy.delete(c.lawyerId);

    // Persist call record so both parties see it in history after restart
    await this.chat.saveCallRecord(
      c.userId, c.lawyerId, consultationId,
      c.type as 'VIDEO' | 'VOICE',
      durationSeconds > 0 ? 'completed' : 'missed',
      durationSeconds,
    ).catch(() => {});

    const endedPayload = { consultationId, durationSeconds };
    this.gateway.emitToUser(c.userId, 'call:ended', endedPayload);
    this.gateway.emitToLawyer(c.lawyerId, 'call:ended', endedPayload);

    return {
      success: true,
      data: { consultationId, durationSeconds },
      meta: { timestamp: new Date().toISOString() },
    };
  }
}

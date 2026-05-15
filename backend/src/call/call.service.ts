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
import { RedisService } from '../redis/redis.service';
import { AgoraService } from './agora.service';
import { agoraUidFromString } from './agora.util';

/**
 * "Lawyer is currently in a call" lock. Stored in Redis so it survives
 * server restarts and stays consistent across multiple backend instances.
 * Key TTL is a safety net — if /call/:id/end is missed, the lawyer auto-frees
 * after the call's max length plus a buffer.
 */
const BUSY_KEY = (lawyerId: string) => `call:busy:${lawyerId}`;
const BUSY_TTL_SECONDS = 60 * 65; // 65 min — slightly above Agora token's 1h

@Injectable()
export class CallService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly agora: AgoraService,
    private readonly gateway: ChatGateway,
    private readonly chat: ChatService,
    private readonly notifications: NotificationService,
    private readonly redis: RedisService,
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

    // Reserve the lawyer atomically via Redis. setNX returns false if another
    // call already holds the lock, so two simultaneous callers can't both reach
    // the same lawyer. Combined with `isOnline`, this covers offline + busy.
    const channelName = `consult_${randomUUID()}`;
    const reserved = lawyer.isOnline
      && await this.redis.setNX(BUSY_KEY(lawyerId), 'pending', BUSY_TTL_SECONDS);

    if (!reserved) {
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

    const row = await this.prisma.consultation.create({
      data: {
        userId: user.sub,
        lawyerId,
        type: consultationType,
        status: ConsultationStatus.RINGING,
        agoraChannelName: channelName,
      },
    });

    // Update the lock with the actual consultation id (still under TTL)
    await this.redis.set(BUSY_KEY(lawyerId), row.id, BUSY_TTL_SECONDS);

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

    // Data-only push wakes the client's background isolate so it can show
    // CallKit (native ringing UI). Must NOT include a `notification` block,
    // otherwise Android also shows a tray banner alongside CallKit.
    this.notifications.sendDataOnlyToLawyer(lawyerId, {
      type:           'call:incoming',
      consultationId: row.id,
      callerId:       user.sub,
      callerName,
      callType:       consultationType,
      channelName,
      token:          lawyerToken,
      uid:            String(lawyerUid),
    }).catch(() => {});

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

    await this.redis.del(BUSY_KEY(c.lawyerId));

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

  /**
   * Mints a fresh Agora RTC token for the caller of an in-progress call.
   * Used by the mobile client when Agora signals `onTokenPrivilegeWillExpire`
   * (fires ~30 s before the current 1-hour token expires).
   */
  async refreshToken(user: JwtPayload, consultationId: string) {
    const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
    if (!c) throw new NotFoundException();
    const okUser   = user.role === 'USER'   && c.userId   === user.sub;
    const okLawyer = user.role === 'LAWYER' && c.lawyerId === user.sub;
    if (!okUser && !okLawyer) throw new ForbiddenException();
    if (c.status !== ConsultationStatus.ACTIVE && c.status !== ConsultationStatus.RINGING) {
      throw new ConflictException('Call is not active');
    }
    const channelName = c.agoraChannelName ?? '';
    const uid = agoraUidFromString(user.sub);
    const token = this.agora.buildRtcToken(channelName, uid);
    return {
      success: true,
      data: { consultationId, agoraToken: token, uid, agoraChannelName: channelName },
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

    await this.redis.del(BUSY_KEY(c.lawyerId));

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

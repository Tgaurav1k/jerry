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
const RING_TIMEOUT_MS = 45_000;   // matches mobile IncomingCallOverlay timeout

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

  /// Ring the lawyer regardless of online state (WhatsApp-style).
  ///
  /// - If lawyer is already on another call (Redis lock held) → immediate MISSED.
  /// - Otherwise create RINGING consultation, issue Agora tokens, broadcast
  ///   call:incoming via socket (reaches them if their app is foregrounded
  ///   right now) AND send data-only FCM push to ALL device sessions (wakes
  ///   the app via CallKit even if killed). Caller's screen rings for 45s.
  /// - A server-side timer marks the call MISSED at T+45s if not accepted.
  async initiate(user: JwtPayload, lawyerId: string, type: 'VIDEO' | 'VOICE') {
    if (user.role !== 'USER') throw new ForbiddenException('Only clients can start calls');

    const lawyer = await this.prisma.lawyer.findUnique({ where: { id: lawyerId } });
    if (!lawyer || lawyer.isSuspended || lawyer.verificationStatus !== 'APPROVED') {
      throw new NotFoundException('Lawyer not found');
    }
    const consultationType: ConsultationType = type === 'VIDEO' ? 'VIDEO' : 'VOICE';
    const client = await this.prisma.user.findUnique({ where: { id: user.sub } });
    const callerName = client?.fullName ?? 'Client';

    // Reserve the lawyer atomically. Only reject the call if another active
    // call already holds the lock — being "offline" no longer blocks ringing.
    const channelName = `consult_${randomUUID()}`;
    const reserved = await this.redis.setNX(BUSY_KEY(lawyerId), 'pending', BUSY_TTL_SECONDS);

    if (!reserved) {
      // Lawyer is genuinely busy on another call.
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
        data: { consultationId: row.id, missed: true, reason: 'busy' },
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

    // 1. Live socket broadcast — hits the lawyer instantly IF their app is
    //    foregrounded and the socket is connected. Targets the lawyer:{id}
    //    room which all of their currently-connected devices have joined.
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

    // 2. Data-only FCM push fans out to every registered device session for
    //    this lawyer. NotificationService.sendDataOnlyToLawyer already
    //    multicasts to all tokens. CallKit picks this up and rings even from
    //    a killed app state.
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

    // 3. Schedule the no-answer timeout. If accept/reject lands within 45s,
    //    those handlers clear the timer slot in `pendingTimeouts`.
    this._scheduleRingTimeout(row.id);

    return {
      success: true,
      data: {
        consultationId: row.id,
        agoraChannelName: channelName,
        agoraToken: userToken,
        uid: userUid,
        ringTimeoutMs: RING_TIMEOUT_MS,
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  // ─── Ring timeout (server-side missed-call watcher) ──────────────────────────

  private readonly pendingTimeouts = new Map<string, NodeJS.Timeout>();

  private _scheduleRingTimeout(consultationId: string) {
    // Clear any prior timer for the same call (defensive).
    const existing = this.pendingTimeouts.get(consultationId);
    if (existing) clearTimeout(existing);

    const handle = setTimeout(
      () => { void this._handleRingTimeout(consultationId); },
      RING_TIMEOUT_MS,
    );
    this.pendingTimeouts.set(consultationId, handle);
  }

  private _clearRingTimeout(consultationId: string) {
    const t = this.pendingTimeouts.get(consultationId);
    if (t) {
      clearTimeout(t);
      this.pendingTimeouts.delete(consultationId);
    }
  }

  /// Fires 45s after initiate. If the call is still RINGING, marks it MISSED
  /// and tells everyone. If the lawyer accepted in the meantime, this is a
  /// no-op (status will be ACTIVE or ENDED).
  private async _handleRingTimeout(consultationId: string) {
    this.pendingTimeouts.delete(consultationId);
    try {
      const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
      if (!c || c.status !== ConsultationStatus.RINGING) return;

      await this.prisma.consultation.update({
        where: { id: consultationId },
        data: { status: ConsultationStatus.MISSED },
      });
      await this.redis.del(BUSY_KEY(c.lawyerId));

      // Insert the "missed call" bubble into the shared chat thread so both
      // sides see it in history when they next open the chat.
      await this.chat.saveCallRecord(
        c.userId, c.lawyerId, c.id,
        c.type as 'VIDEO' | 'VOICE',
        'missed', 0,
      ).catch(() => {});

      // Caller's screen — close the ringing UI.
      this.gateway.emitToUser(c.userId, 'call:ended', {
        consultationId: c.id,
        durationSeconds: 0,
        reason: 'no_answer',
      });
      // Lawyer's screen if they happen to be in the app — dismiss the
      // CallKit overlay if it's still showing.
      this.gateway.emitToLawyer(c.lawyerId, 'call:ended', {
        consultationId: c.id,
        durationSeconds: 0,
        reason: 'no_answer',
      });

      // Push notification to the lawyer summarising the missed call so they
      // see it when they open their phone later.
      this.notifications.sendToLawyer(
        c.lawyerId,
        `📞 Missed ${c.type === 'VIDEO' ? 'video' : 'voice'} call`,
        `${(await this.prisma.user.findUnique({ where: { id: c.userId } }))?.fullName ?? 'A client'} tried to reach you`,
        { type: 'call:missed', consultationId: c.id },
      ).catch(() => {});
    } catch (e) {
      // Best-effort — the next call.initiate or a manual cleanup will catch
      // any stuck rows.
      console.error('[call timeout]', e);
    }
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

    // Cancel the server-side ring timeout — the call is now ACTIVE.
    this._clearRingTimeout(consultationId);

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

    // Cancel the server-side ring timeout — lawyer explicitly declined.
    this._clearRingTimeout(consultationId);

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

    // Either party hung up — cancel the ring timeout in case the call ends
    // before the timer fires (e.g. caller cancels mid-ring).
    this._clearRingTimeout(consultationId);

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

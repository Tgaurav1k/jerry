import {
  BadRequestException,
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

/**
 * Who initiated the consultation. Kept in Redis (not the DB) so we don't need
 * a schema migration. Used by accept/reject to forbid the caller from
 * accepting their own call, and to know which side is the recipient when
 * routing end-of-call socket events.
 */
const INITIATOR_KEY = (consultationId: string) => `call:initiator:${consultationId}`;

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

  /**
   * Ring the recipient regardless of online state (WhatsApp-style).
   *
   * Either side (USER or LAWYER) may initiate. The lawyer-busy lock is held
   * regardless of who started the call, because lawyer-availability is the
   * scarce resource.
   *
   * Delivery: live socket (foregrounded app) + data-only FCM push (CallKit
   * ring even when killed). A server-side 45s timer marks the call MISSED if
   * not accepted in time.
   */
  async initiate(
    caller: JwtPayload,
    recipientId: string,
    recipientRole: 'USER' | 'LAWYER',
    type: 'VIDEO' | 'VOICE',
  ) {
    if (caller.role !== 'USER' && caller.role !== 'LAWYER') {
      throw new ForbiddenException();
    }
    if (caller.role === recipientRole) {
      throw new BadRequestException('Cannot call a peer of the same role');
    }
    if (caller.sub === recipientId) {
      throw new BadRequestException('Cannot call yourself');
    }

    // Resolve the user/lawyer side of the consultation regardless of who
    // initiated. The Consultation table is bound by role columns.
    const userId   = caller.role === 'USER'   ? caller.sub : recipientId;
    const lawyerId = caller.role === 'LAWYER' ? caller.sub : recipientId;

    const lawyer = await this.prisma.lawyer.findUnique({ where: { id: lawyerId } });
    if (!lawyer || lawyer.isSuspended || lawyer.verificationStatus !== 'APPROVED') {
      throw new NotFoundException('Lawyer not found');
    }
    const userRow = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!userRow || userRow.isSuspended) {
      throw new NotFoundException('User not found');
    }

    const consultationType: ConsultationType = type === 'VIDEO' ? 'VIDEO' : 'VOICE';
    const callerRecord = caller.role === 'USER' ? userRow : lawyer;
    const callerName = (callerRecord as { fullName?: string })?.fullName
      ?? (caller.role === 'USER' ? 'Client' : 'Lawyer');
    const callerPhotoUrl = (callerRecord as { profilePhotoUrl?: string | null })?.profilePhotoUrl ?? null;

    // Reserve the lawyer atomically. Only reject the call if another active
    // call already holds the lock — being "offline" no longer blocks ringing.
    const channelName = `consult_${randomUUID()}`;
    const reserved = await this.redis.setNX(BUSY_KEY(lawyerId), 'pending', BUSY_TTL_SECONDS);

    if (!reserved) {
      // Lawyer is genuinely busy on another call.
      const row = await this.prisma.consultation.create({
        data: {
          userId,
          lawyerId,
          type: consultationType,
          status: ConsultationStatus.MISSED,
        },
      });
      await this.chat.saveMissedCall(userId, lawyerId, row.id, type);
      return {
        success: true,
        data: { consultationId: row.id, missed: true, reason: 'busy' },
        meta: { timestamp: new Date().toISOString() },
      };
    }

    const row = await this.prisma.consultation.create({
      data: {
        userId,
        lawyerId,
        type: consultationType,
        status: ConsultationStatus.RINGING,
        agoraChannelName: channelName,
      },
    });

    // Update the lock with the actual consultation id (still under TTL)
    await this.redis.set(BUSY_KEY(lawyerId), row.id, BUSY_TTL_SECONDS);

    // Record the initiator so accept/reject can forbid the caller from
    // accepting their own call. TTL slightly above the ring timeout — once
    // ACTIVE, we extend it via the BUSY lock anyway.
    await this.redis.set(INITIATOR_KEY(row.id), caller.role, BUSY_TTL_SECONDS);

    const callerUid    = agoraUidFromString(caller.sub);
    const recipientUid = agoraUidFromString(recipientId);
    const callerToken    = this.agora.buildRtcToken(channelName, callerUid);
    const recipientToken = this.agora.buildRtcToken(channelName, recipientUid);

    const incomingPayload = {
      consultationId: row.id,
      callerId:       caller.sub,
      callerRole:     caller.role,
      channelName,
      token:          recipientToken,
      uid:            recipientUid,
      callerName,
      callerPhotoUrl,
      type:           consultationType,
    };

    // Data payload for FCM must be Record<string, string>. Strip nullables.
    const fcmData: Record<string, string> = {
      type:           'call:incoming',
      consultationId: row.id,
      callerId:       caller.sub,
      callerRole:     caller.role,
      callerName,
      callType:       consultationType,
      channelName,
      token:          recipientToken,
      uid:            String(recipientUid),
    };

    if (recipientRole === 'LAWYER') {
      this.gateway.emitToLawyer(recipientId, 'call:incoming', incomingPayload);
      this.notifications.sendDataOnlyToLawyer(recipientId, fcmData).catch(() => {});
    } else {
      this.gateway.emitToUser(recipientId, 'call:incoming', incomingPayload);
      this.notifications.sendDataOnlyToUser(recipientId, fcmData).catch(() => {});
    }

    // Schedule the no-answer timeout. If accept/reject lands within 45s,
    // those handlers clear the timer slot in `pendingTimeouts`.
    this._scheduleRingTimeout(row.id);

    return {
      success: true,
      data: {
        consultationId: row.id,
        agoraChannelName: channelName,
        agoraToken: callerToken,
        uid: callerUid,
        ringTimeoutMs: RING_TIMEOUT_MS,
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  /**
   * Data-only FCM telling the recipient's device(s) to tear down any ringing
   * UI (native CallKit screen / in-app overlay). Socket events alone are NOT
   * enough: the CallKit ring on a killed or backgrounded app was started by
   * an FCM push, so only another push can stop it. Without this, the phone
   * keeps ringing for the full 45 s after the caller hung up, and answering
   * the dead call fails with "Call not ringing".
   *
   * Sent to the NON-initiator side(s). If the initiator is unknown (Redis
   * evicted), push to both — dismissing a call id that isn't ringing is a
   * no-op on the client.
   */
  private _pushCallCancelled(
    c: { id: string; userId: string; lawyerId: string },
    reason: 'cancelled' | 'timeout' | 'rejected' | 'answered_elsewhere',
    initiatorRole: string | null,
  ) {
    const data: Record<string, string> = {
      type: 'call:cancelled',
      consultationId: c.id,
      reason,
    };
    if (initiatorRole !== 'LAWYER') {
      this.notifications.sendDataOnlyToLawyer(c.lawyerId, data).catch(() => {});
    }
    if (initiatorRole !== 'USER') {
      this.notifications.sendDataOnlyToUser(c.userId, data).catch(() => {});
    }
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
  /// and tells everyone. If the recipient accepted in the meantime, this is a
  /// no-op (status will be ACTIVE or ENDED).
  private async _handleRingTimeout(consultationId: string) {
    this.pendingTimeouts.delete(consultationId);
    try {
      const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
      if (!c || c.status !== ConsultationStatus.RINGING) return;

      // Read BEFORE deleting — needed to route the cancel/missed pushes.
      const initiatorRole = await this.redis.get(INITIATOR_KEY(c.id));

      await this.prisma.consultation.update({
        where: { id: consultationId },
        data: { status: ConsultationStatus.MISSED },
      });
      await this.redis.del(BUSY_KEY(c.lawyerId));
      await this.redis.del(INITIATOR_KEY(c.id));

      // Stop the ringing UI on the recipient's device(s).
      this._pushCallCancelled(c, 'timeout', initiatorRole);

      // Insert the "missed call" bubble into the shared chat thread.
      await this.chat.saveCallRecord(
        c.userId, c.lawyerId, c.id,
        c.type as 'VIDEO' | 'VOICE',
        'missed', 0,
      ).catch(() => {});

      // Notify BOTH ends — whoever was ringing should drop their UI, and the
      // missed-call side gets the system push.
      const endedPayload = { consultationId: c.id, durationSeconds: 0, reason: 'no_answer' };
      this.gateway.emitToUser(c.userId, 'call:ended', endedPayload);
      this.gateway.emitToLawyer(c.lawyerId, 'call:ended', endedPayload);

      // Push the missed-call summary only to the side that didn't pick up
      // (the non-initiator). Previously this went to both sides, so the
      // CALLER got a bogus "X tried to reach you" push about their own call.
      // If the initiator is unknown (Redis evicted), fall back to both.
      const callerLabel = c.type === 'VIDEO' ? 'video' : 'voice';
      if (initiatorRole !== 'LAWYER') {
        this.notifications.sendToLawyer(
          c.lawyerId,
          `📞 Missed ${callerLabel} call`,
          `${(await this.prisma.user.findUnique({ where: { id: c.userId } }))?.fullName ?? 'A client'} tried to reach you`,
          { type: 'call:missed', consultationId: c.id },
        ).catch(() => {});
      }
      if (initiatorRole !== 'USER') {
        this.notifications.sendToUser(
          c.userId,
          `📞 Missed ${callerLabel} call`,
          `${(await this.prisma.lawyer.findUnique({ where: { id: c.lawyerId } }))?.fullName ?? 'A lawyer'} tried to reach you`,
          { type: 'call:missed', consultationId: c.id },
        ).catch(() => {});
      }
    } catch (e) {
      console.error('[call timeout]', e);
    }
  }

  async accept(user: JwtPayload, consultationId: string) {
    const c = await this.prisma.consultation.findUnique({
      where: { id: consultationId },
      include: { lawyer: true },
    });
    if (!c) throw new NotFoundException();

    // Caller must be a participant of this consultation.
    const isUser   = user.role === 'USER'   && user.sub === c.userId;
    const isLawyer = user.role === 'LAWYER' && user.sub === c.lawyerId;
    if (!isUser && !isLawyer) throw new ForbiddenException();

    // The initiator cannot accept their own call.
    const initiatorRole = await this.redis.get(INITIATOR_KEY(consultationId));
    if (initiatorRole && initiatorRole === user.role) {
      throw new ConflictException("Caller cannot accept their own call");
    }

    if (c.status !== ConsultationStatus.RINGING) {
      throw new ConflictException('Call not ringing');
    }

    // Cancel the server-side ring timeout — the call is now ACTIVE.
    this._clearRingTimeout(consultationId);

    await this.prisma.consultation.update({
      where: { id: consultationId },
      data: { status: ConsultationStatus.ACTIVE, startedAt: new Date() },
    });

    // The recipient may be logged in on several devices — stop the ring on
    // all of them. The device that accepted already dismissed its own UI, so
    // the redundant push there is a harmless no-op.
    this._pushCallCancelled(c, 'answered_elsewhere', initiatorRole);

    const channelName = c.agoraChannelName ?? '';
    const accepterUid = agoraUidFromString(user.sub);
    const accepterToken = this.agora.buildRtcToken(channelName, accepterUid);

    return {
      success: true,
      data: {
        consultationId: c.id,
        agoraChannelName: channelName,
        agoraToken: accepterToken,
        uid: accepterUid,
      },
      meta: { timestamp: new Date().toISOString() },
    };
  }

  async reject(user: JwtPayload, consultationId: string) {
    const c = await this.prisma.consultation.findUnique({ where: { id: consultationId } });
    if (!c) throw new NotFoundException();

    const isUser   = user.role === 'USER'   && user.sub === c.userId;
    const isLawyer = user.role === 'LAWYER' && user.sub === c.lawyerId;
    if (!isUser && !isLawyer) throw new ForbiddenException();

    // The initiator can also "cancel" via /end; rejecting is only for the
    // recipient. But to keep the API forgiving, treat caller-side reject as
    // an end too (covered by the /end path), and only allow real reject from
    // the non-initiator here.
    const initiatorRole = await this.redis.get(INITIATOR_KEY(consultationId));
    if (initiatorRole && initiatorRole === user.role) {
      throw new ConflictException("Caller cannot reject their own call — use /end to cancel");
    }

    if (c.status !== ConsultationStatus.RINGING) {
      throw new ConflictException('Call not ringing');
    }

    this._clearRingTimeout(consultationId);

    await this.prisma.consultation.update({
      where: { id: consultationId },
      data: { status: ConsultationStatus.REJECTED_BY_LAWYER },
    });

    await this.redis.del(BUSY_KEY(c.lawyerId));
    await this.redis.del(INITIATOR_KEY(c.id));

    // Stop the ring on the recipient's OTHER devices (and the parallel
    // native CallKit notification on the device that declined in-app).
    this._pushCallCancelled(c, 'rejected', initiatorRole);

    // Persist declined record so caller sees it in history after restart
    await this.chat.saveCallRecord(
      c.userId, c.lawyerId, consultationId,
      c.type as 'VIDEO' | 'VOICE',
      'declined', 0,
    ).catch(() => {});

    // Notify the initiator (whoever they were).
    this.gateway.emitToUser(c.userId,     'call:rejected', { consultationId });
    this.gateway.emitToLawyer(c.lawyerId, 'call:rejected', { consultationId });

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

    // If the caller cancelled while still RINGING, the recipient's device is
    // mid-ring (CallKit / overlay) and must be told to stop. Capture state +
    // initiator before we overwrite/delete them below.
    const wasRinging = c.status === ConsultationStatus.RINGING;
    const initiatorRole = wasRinging
      ? await this.redis.get(INITIATOR_KEY(c.id))
      : null;

    const ended = new Date();
    // Only count real talk-time if the call was actually answered (ACTIVE).
    // `startedAt` defaults to row-creation time (set while RINGING), and accept()
    // resets it to the pickup moment. So for a call that ends while still
    // RINGING (caller cancelled before pickup) `startedAt` is the creation time —
    // computing a duration from it would wrongly log a cancelled call as a
    // completed N-second call. In that case duration is 0 → recorded as missed.
    const wasActive = c.status === ConsultationStatus.ACTIVE;
    const durationSeconds = wasActive && c.startedAt
      ? Math.max(0, Math.floor((ended.getTime() - c.startedAt.getTime()) / 1000))
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
    await this.redis.del(INITIATOR_KEY(c.id));

    if (wasRinging) this._pushCallCancelled(c, 'cancelled', initiatorRole);

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

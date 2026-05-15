import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);
  private fcmEnabled = false;
  private fcmApp: any;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    const projectId = config.get('FCM_PROJECT_ID');
    const clientEmail = config.get('FCM_CLIENT_EMAIL');
    const privateKey = config.get('FCM_PRIVATE_KEY');

    if (projectId && clientEmail && privateKey) {
      try {
        // Lazy import firebase-admin only when credentials present
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        const admin = require('firebase-admin');
        if (!admin.apps.length) {
          admin.initializeApp({
            credential: admin.credential.cert({ projectId, clientEmail, privateKey: privateKey.replace(/\\n/g, '\n') }),
          });
        }
        this.fcmApp = admin;
        this.fcmEnabled = true;
        this.logger.log('FCM initialized');
      } catch (e) {
        this.logger.warn('FCM init failed — push disabled', e);
      }
    } else {
      this.logger.warn('FCM credentials not set — push notifications disabled');
    }
  }

  async sendToUser(userId: string, title: string, body: string, data?: Record<string, string>) {
    const sessions = await this.prisma.deviceSession.findMany({
      where: { userId, fcmToken: { not: null } },
    });
    await this._sendToTokens(sessions.map((s) => s.fcmToken!), title, body, data);
  }

  async sendToLawyer(lawyerId: string, title: string, body: string, data?: Record<string, string>) {
    const sessions = await this.prisma.deviceSession.findMany({
      where: { lawyerId, fcmToken: { not: null } },
    });
    await this._sendToTokens(sessions.map((s) => s.fcmToken!), title, body, data);
  }

  /**
   * Data-only push (no notification block) for events that the client must
   * handle itself — e.g. CallKit ringing UI. Wakes the app in background so
   * onBackgroundMessage fires instead of the system tray banner.
   */
  async sendDataOnlyToLawyer(lawyerId: string, data: Record<string, string>) {
    const sessions = await this.prisma.deviceSession.findMany({
      where: { lawyerId, fcmToken: { not: null } },
    });
    const tokens = sessions.map((s) => s.fcmToken!).filter(Boolean);
    if (!this.fcmEnabled || !tokens.length) {
      this.logger.debug(`[FCM stub data-only] → ${tokens.length} tokens: ${JSON.stringify(data)}`);
      return;
    }
    try {
      await this.fcmApp.messaging().sendEachForMulticast({
        tokens,
        data,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10', 'apns-push-type': 'voip' } },
      });
    } catch (e) {
      this.logger.error('FCM data-only send failed', e);
    }
  }

  private async _sendToTokens(tokens: string[], title: string, body: string, data?: Record<string, string>) {
    if (!this.fcmEnabled || !tokens.length) {
      this.logger.debug(`[FCM stub] → ${tokens.length} tokens: ${title} — ${body}`);
      return;
    }
    try {
      await this.fcmApp.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: data ?? {},
      });
    } catch (e) {
      this.logger.error('FCM send failed', e);
    }
  }
}

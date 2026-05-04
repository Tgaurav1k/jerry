import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RtcRole, RtcTokenBuilder } from 'agora-access-token';

@Injectable()
export class AgoraService {
  constructor(private readonly config: ConfigService) {}

  buildRtcToken(channelName: string, uid: number): string {
    const appId = this.config.get<string>('AGORA_APP_ID')?.trim() ?? '';
    const cert = this.config.get<string>('AGORA_APP_CERTIFICATE')?.trim() ?? '';
    if (!appId) {
      throw new Error('AGORA_APP_ID is not set. Add it to backend/.env from the Agora console.');
    }
    const privilegeExpiredTs = Math.floor(Date.now() / 1000) + 3600;
    return RtcTokenBuilder.buildTokenWithUid(
      appId,
      cert,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
    );
  }
}

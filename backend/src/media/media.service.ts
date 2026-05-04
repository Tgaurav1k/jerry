import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class MediaService {
  private readonly bucket: string;
  private readonly supabaseUrl: string;
  private readonly serviceKey: string;

  constructor(private readonly config: ConfigService) {
    this.supabaseUrl = config.get('SUPABASE_URL', '');
    this.serviceKey = config.get('SUPABASE_SERVICE_ROLE_KEY', '');
    this.bucket = config.get('SUPABASE_STORAGE_BUCKET_PHOTOS', 'profile-photos');
  }

  async getPhotoUploadUrl(userId: string, extension: 'jpg' | 'png' | 'webp' = 'jpg') {
    const path = `${userId}/${crypto.randomUUID()}.${extension}`;

    if (!this.supabaseUrl || !this.serviceKey) {
      // Dev fallback: return a placeholder
      return {
        success: true,
        data: { uploadUrl: null, publicUrl: null, path, note: 'Supabase not configured' },
        meta: { timestamp: new Date().toISOString() },
      };
    }

    // Generate a signed upload URL via Supabase REST API
    const resp = await fetch(
      `${this.supabaseUrl}/storage/v1/object/upload/sign/${this.bucket}/${path}`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.serviceKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ upsert: true }),
      },
    );

    if (!resp.ok) {
      const txt = await resp.text();
      throw new Error(`Supabase sign error: ${txt}`);
    }

    const json = await resp.json() as { signedURL: string };
    const publicUrl = `${this.supabaseUrl}/storage/v1/object/public/${this.bucket}/${path}`;

    return {
      success: true,
      data: { uploadUrl: `${this.supabaseUrl}${json.signedURL}`, publicUrl, path },
      meta: { timestamp: new Date().toISOString() },
    };
  }
}

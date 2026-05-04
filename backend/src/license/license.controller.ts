import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { LicenseService } from './license.service';

@Controller('license')
@UseGuards(JwtAuthGuard)
export class LicenseController {
  constructor(private readonly svc: LicenseService) {}

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', { storage: undefined })) // buffer storage
  uploadLicense(
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
    @Body('licenseNumber') licenseNumber?: string,
  ) {
    return this.svc.upload(user, file, licenseNumber);
  }

  @Get(':lawyerId/stream')
  async streamLicense(
    @Param('lawyerId') lawyerId: string,
    @CurrentUser() admin: JwtPayload,
    @Res() res: Response,
  ) {
    const { buffer, mime } = await this.svc.streamLicense(lawyerId, admin);
    res.set('Content-Type', mime);
    res.set('Content-Disposition', 'inline');
    res.set('Cache-Control', 'no-store');
    res.send(buffer);
  }
}

import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { LicenseController } from './license.controller';
import { LicenseService } from './license.service';

@Module({
  imports: [
    MulterModule.register({ storage: memoryStorage() }),
  ],
  controllers: [LicenseController],
  providers: [LicenseService],
})
export class LicenseModule {}

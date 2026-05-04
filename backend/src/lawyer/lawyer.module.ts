import { Module } from '@nestjs/common';
import { LawyerController } from './lawyer.controller';
import { LawyerService } from './lawyer.service';

@Module({
  controllers: [LawyerController],
  providers: [LawyerService],
  exports: [LawyerService],
})
export class LawyerModule {}

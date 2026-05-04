import { Module } from '@nestjs/common';
import { ConsultationController } from './consultation.controller';
import { ConsultationService } from './consultation.service';

@Module({
  controllers: [ConsultationController],
  providers: [ConsultationService],
})
export class ConsultationModule {}

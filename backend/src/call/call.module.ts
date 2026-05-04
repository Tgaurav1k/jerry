import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ChatModule } from '../chat/chat.module';
import { AgoraService } from './agora.service';
import { CallController } from './call.controller';
import { CallService } from './call.service';

@Module({
  imports: [AuthModule, ChatModule],
  controllers: [CallController],
  providers: [CallService, AgoraService],
  exports: [CallService],
})
export class CallModule {}

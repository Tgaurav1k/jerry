import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { CallModule } from './call/call.module';
import { ChatModule } from './chat/chat.module';
import { ConsultationModule } from './consultation/consultation.module';
import { LawyerModule } from './lawyer/lawyer.module';
import { LicenseModule } from './license/license.module';
import { MediaModule } from './media/media.module';
import { NotificationModule } from './notification/notification.module';
import { PaymentModule } from './payment/payment.module';
import { PrismaModule } from './prisma/prisma.module';
import { RatingModule } from './rating/rating.module';
import { RedisModule } from './redis/redis.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    RedisModule,
    NotificationModule,
    AuthModule,
    UserModule,
    LawyerModule,
    LicenseModule,
    AdminModule,
    ChatModule,
    CallModule,
    ConsultationModule,
    RatingModule,
    MediaModule,
    PaymentModule,
  ],
})
export class AppModule {}

import { Controller, Get } from '@nestjs/common';

@Controller('payment')
export class PaymentController {
  @Get('status')
  status() {
    return {
      success: true,
      data: { enabled: false, message: 'Payments not enabled in MVP' },
      meta: { timestamp: new Date().toISOString() },
    };
  }
}

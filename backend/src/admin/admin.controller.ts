import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsEmail, IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';
import { Type } from 'class-transformer';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { AdminService } from './admin.service';

class RejectDto {
  @IsString() @MinLength(5) reason!: string;
}

class SuspendDto {
  @IsString() targetType!: 'USER' | 'LAWYER';
}

class CreateAdminDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(2) fullName!: string;
  @IsString() @MinLength(8) password!: string;
}

class PageQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number;
}

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminController {
  constructor(private readonly svc: AdminService) {}

  @Get('dashboard')
  dashboard(@CurrentUser() user: JwtPayload) {
    return this.svc.getDashboard(user);
  }

  @Get('queue')
  queue(@CurrentUser() user: JwtPayload, @Query() q: PageQueryDto) {
    return this.svc.getPendingQueue(user, q.page, q.limit);
  }

  @Post('lawyers/:id/approve')
  approve(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.approveLawyer(user, id);
  }

  @Post('lawyers/:id/reject')
  reject(@CurrentUser() user: JwtPayload, @Param('id') id: string, @Body() dto: RejectDto) {
    return this.svc.rejectLawyer(user, id, dto.reason);
  }

  @Post('lawyers/:id/suspend')
  suspendLawyer(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.suspendUser(user, id, true, 'LAWYER');
  }

  @Post('lawyers/:id/unsuspend')
  unsuspendLawyer(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.suspendUser(user, id, false, 'LAWYER');
  }

  @Post('users/:id/suspend')
  suspendUser(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.suspendUser(user, id, true, 'USER');
  }

  @Post('users/:id/unsuspend')
  unsuspendUser(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.svc.suspendUser(user, id, false, 'USER');
  }

  @Get('users')
  listUsers(@CurrentUser() user: JwtPayload, @Query() q: PageQueryDto) {
    return this.svc.listUsers(user, q.page, q.limit);
  }

  @Get('lawyers')
  listLawyers(@CurrentUser() user: JwtPayload, @Query() q: PageQueryDto) {
    return this.svc.listLawyers(user, q.page, q.limit);
  }

  @Get('audit')
  auditLog(@CurrentUser() user: JwtPayload, @Query() q: PageQueryDto) {
    return this.svc.getAuditLog(user, q.page, q.limit);
  }

  @Get('admins')
  listAdmins(@CurrentUser() user: JwtPayload) {
    return this.svc.listAdmins(user);
  }

  @Post('admins')
  createAdmin(@CurrentUser() user: JwtPayload, @Body() dto: CreateAdminDto) {
    return this.svc.createAdmin(user, dto.email, dto.fullName, dto.password);
  }

  @Patch('admins/:id/toggle')
  toggleAdmin(@CurrentUser() user: JwtPayload, @Param('id') id: string, @Body('isActive') isActive: boolean) {
    return this.svc.toggleAdmin(user, id, isActive);
  }
}

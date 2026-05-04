import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { JwtPayload } from '../auth/jwt.strategy';
import { LawyerQueryDto } from './dto/lawyer-query.dto';
import { UpdateLawyerDto } from './dto/update-lawyer.dto';
import { LawyerService } from './lawyer.service';
import { IsArray, IsBoolean, IsString } from 'class-validator';

class SetSpecialtiesDto {
  @IsArray()
  @IsString({ each: true })
  specialtyIds!: string[];
}

class AvailabilityDto {
  @IsBoolean()
  isOnline!: boolean;
}

@Controller('lawyers')
export class LawyerController {
  constructor(private readonly svc: LawyerService) {}

  @Get()
  listPublic(@Query() query: LawyerQueryDto) {
    return this.svc.listPublic(query);
  }

  @Get('specialties')
  listSpecialties() {
    return this.svc.listSpecialties();
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  getMyProfile(@CurrentUser() user: JwtPayload) {
    return this.svc.getMyProfile(user);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  updateMyProfile(@CurrentUser() user: JwtPayload, @Body() dto: UpdateLawyerDto) {
    return this.svc.updateMyProfile(user, dto);
  }

  @Put('me/specialties')
  @UseGuards(JwtAuthGuard)
  setSpecialties(@CurrentUser() user: JwtPayload, @Body() dto: SetSpecialtiesDto) {
    return this.svc.setSpecialties(user, dto.specialtyIds);
  }

  @Post('me/availability')
  @UseGuards(JwtAuthGuard)
  setAvailability(@CurrentUser() user: JwtPayload, @Body() dto: AvailabilityDto) {
    return this.svc.setAvailability(user, dto.isOnline);
  }

  @Get(':id')
  getPublic(@Param('id') id: string) {
    return this.svc.getPublic(id);
  }
}

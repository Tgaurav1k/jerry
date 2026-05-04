import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

export enum LoginRole {
  USER = 'USER',
  LAWYER = 'LAWYER',
  ADMIN = 'ADMIN',
}

export class LoginDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsEnum(LoginRole)
  role!: LoginRole;

  @IsOptional()
  @IsString()
  deviceId?: string;

  @IsOptional()
  @IsBoolean()
  forceLogout?: boolean;
}

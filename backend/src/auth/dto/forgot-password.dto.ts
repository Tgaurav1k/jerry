import { IsEmail, IsEnum } from 'class-validator';
import { SignupRole } from './signup.dto';

export class ForgotPasswordDto {
  @IsEmail()
  email!: string;

  @IsEnum(SignupRole)
  role!: SignupRole;
}

import { IsEmail, IsEnum, IsString, Length, Matches, MinLength } from 'class-validator';
import { SignupRole } from './signup.dto';

export class ResetPasswordDto {
  @IsEmail()
  email!: string;

  @IsEnum(SignupRole)
  role!: SignupRole;

  @IsString()
  @Length(6, 6)
  otp!: string;

  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?])/, {
    message: 'Password must contain uppercase letter, number, and special character',
  })
  newPassword!: string;
}

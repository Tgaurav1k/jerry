import { IsIn, IsUUID } from 'class-validator';

export class InitiateCallDto {
  @IsUUID()
  lawyerId!: string;

  @IsIn(['VIDEO', 'VOICE'])
  type!: 'VIDEO' | 'VOICE';
}

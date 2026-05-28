import { IsIn, IsOptional, IsUUID } from 'class-validator';

export class InitiateCallDto {
  // The party being called. Either recipientId+recipientRole (preferred,
  // bidirectional) or the legacy lawyerId (kept so older client builds still
  // work — the service treats it as a USER->LAWYER call).
  @IsOptional()
  @IsUUID()
  recipientId?: string;

  @IsOptional()
  @IsIn(['USER', 'LAWYER'])
  recipientRole?: 'USER' | 'LAWYER';

  @IsOptional()
  @IsUUID()
  lawyerId?: string;

  @IsIn(['VIDEO', 'VOICE'])
  type!: 'VIDEO' | 'VOICE';
}

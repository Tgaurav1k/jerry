import { SetMetadata } from '@nestjs/common';
import type { JwtRole } from './auth.service';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: JwtRole[]) => SetMetadata(ROLES_KEY, roles);

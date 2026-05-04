-- ============================================================
-- Jerry App — Admin & SuperAdmin Setup
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- Run AFTER supabase_schema.sql
-- ============================================================

-- ── UPDATE RLS: Lawyer profiles — admins see ALL statuses ────

-- Drop old policy and replace with admin-aware one
drop policy if exists "Approved lawyers visible to all" on public.lawyer_profiles;

create policy "Lawyer profiles visibility"
  on public.lawyer_profiles for select to authenticated
  using (
    verification_status = 'APPROVED'
    OR auth.uid() = id
    OR (auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN')
  );

-- Admins can update verification_status and notes
drop policy if exists "Lawyers can update own lawyer profile" on public.lawyer_profiles;

create policy "Lawyer profiles update"
  on public.lawyer_profiles for update to authenticated
  using (
    auth.uid() = id
    OR (auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN')
  );

-- ── UPDATE RLS: Profiles — admins see all users ──────────────

drop policy if exists "Profiles viewable by authenticated" on public.profiles;

create policy "Profiles viewable"
  on public.profiles for select to authenticated
  using (true); -- all authenticated users can read profiles (needed for chat, search)

-- Admins can update any profile (suspend/unsuspend)
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Profile update"
  on public.profiles for update to authenticated
  using (
    auth.uid() = id
    OR (auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN')
  );

-- ── AUDIT LOGS RLS ────────────────────────────────────────────

alter table public.audit_logs enable row level security;

create policy "Admins can view audit logs"
  on public.audit_logs for select to authenticated
  using ((auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN'));

create policy "Admins can insert audit logs"
  on public.audit_logs for insert to authenticated
  with check ((auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN'));

-- ── STORAGE RLS: Admins can read license documents ───────────
-- Run in: Storage → Policies → lawyer-licenses bucket

-- Allow lawyers to upload their own license
-- (path pattern: {userId}/license.{ext})
-- Allow admins to read any license

-- You can set these in the Supabase Dashboard:
-- Storage → lawyer-licenses → Policies:
--   INSERT: (auth.uid()::text) = (storage.foldername(name))[1]
--   SELECT: (auth.uid()::text) = (storage.foldername(name))[1]
--           OR (auth.jwt()->'user_metadata'->>'role') IN ('ADMIN', 'SUPERADMIN')

-- ── CREATE SUPERADMIN ACCOUNT ─────────────────────────────────
-- Option A: Sign up normally in the app with role=USER, then run this SQL
--           to upgrade the account to SUPERADMIN:
--
-- UPDATE auth.users
-- SET raw_user_meta_data = raw_user_meta_data || '{"role": "SUPERADMIN"}'::jsonb
-- WHERE email = 'superadmin@jerry.in';
--
-- UPDATE public.profiles SET role = 'SUPERADMIN' WHERE id = (
--   SELECT id FROM auth.users WHERE email = 'superadmin@jerry.in'
-- );

-- Option B: Create directly via Supabase Auth API (recommended)
-- In Supabase Dashboard → Authentication → Users → Add user
-- Then run the UPDATE above.

-- ── CREATE ADMIN ACCOUNT ──────────────────────────────────────
-- Same process — sign up, then:
--
-- UPDATE auth.users
-- SET raw_user_meta_data = raw_user_meta_data || '{"role": "ADMIN"}'::jsonb
-- WHERE email = 'admin@jerry.in';
--
-- UPDATE public.profiles SET role = 'ADMIN' WHERE id = (
--   SELECT id FROM auth.users WHERE email = 'admin@jerry.in'
-- );

-- ── HELPER VIEW: Pending lawyers with profile info ────────────
create or replace view public.pending_lawyers_view as
  select
    lp.id,
    lp.license_url,
    lp.license_number,
    lp.verification_status,
    lp.verification_notes,
    lp.updated_at,
    p.full_name,
    p.email,
    p.city,
    p.state,
    p.created_at as registered_at
  from public.lawyer_profiles lp
  join public.profiles p on p.id = lp.id
  join auth.users u on u.id = lp.id
  where lp.verification_status = 'PENDING_REVIEW'
  order by lp.updated_at asc;

-- ── HELPER VIEW: All users ────────────────────────────────────
create or replace view public.all_users_view as
  select
    p.id,
    p.role,
    p.full_name,
    u.email,
    p.city,
    p.state,
    p.is_suspended,
    p.suspension_reason,
    p.created_at,
    lp.verification_status,
    lp.avg_rating,
    lp.total_consultations,
    lp.is_online
  from public.profiles p
  join auth.users u on u.id = p.id
  left join public.lawyer_profiles lp on lp.id = p.id
  order by p.created_at desc;

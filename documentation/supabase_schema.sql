-- ============================================================
-- Jerry App — Supabase Schema
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── PROFILES (all users & lawyers) ──────────────────────────
create table public.profiles (
  id                  uuid references auth.users on delete cascade primary key,
  role                text not null check (role in ('USER', 'LAWYER')),
  full_name           text not null default '',
  preferred_language  text not null default 'English',
  profile_photo_url   text,
  phone               text,
  city                text,
  state               text,
  is_suspended        boolean not null default false,
  suspension_reason   text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── LAWYER PROFILES (extends profiles) ──────────────────────
create table public.lawyer_profiles (
  id                  uuid references public.profiles(id) on delete cascade primary key,
  bio                 text,
  years_experience    integer not null default 0,
  languages_spoken    text[] not null default '{}',
  rate_per_session    numeric(10,2) not null default 0,
  license_url         text,
  license_mime_type   text,
  license_number      text,
  verification_status text not null default 'PENDING_UPLOAD'
    check (verification_status in ('PENDING_UPLOAD','PENDING_REVIEW','APPROVED','REJECTED')),
  verification_notes  text,
  is_online           boolean not null default false,
  last_active_at      timestamptz,
  avg_rating          numeric(3,2) not null default 0,
  total_ratings       integer not null default 0,
  total_consultations integer not null default 0,
  updated_at          timestamptz not null default now()
);

-- ── SPECIALTIES ─────────────────────────────────────────────
create table public.specialties (
  id         uuid primary key default uuid_generate_v4(),
  name       text unique not null,
  slug       text unique not null,
  created_at timestamptz not null default now()
);

create table public.lawyer_specialties (
  lawyer_id    uuid references public.lawyer_profiles(id) on delete cascade,
  specialty_id uuid references public.specialties(id) on delete cascade,
  primary key (lawyer_id, specialty_id)
);

-- ── CONSULTATIONS ────────────────────────────────────────────
create table public.consultations (
  id                  uuid primary key default uuid_generate_v4(),
  user_id             uuid references public.profiles(id),
  lawyer_id           uuid references public.profiles(id),
  type                text not null check (type in ('CHAT','VOICE','VIDEO')),
  status              text not null default 'RINGING'
    check (status in ('RINGING','ACTIVE','ENDED','MISSED','REJECTED_BY_LAWYER','DROPPED')),
  started_at          timestamptz not null default now(),
  ended_at            timestamptz,
  duration_seconds    integer,
  agora_channel_name  text,
  amount_paid         numeric(10,2) not null default 0,
  payment_status      text not null default 'FREE',
  created_at          timestamptz not null default now()
);

create index idx_consultations_lawyer on public.consultations(lawyer_id, started_at desc);
create index idx_consultations_user   on public.consultations(user_id, started_at desc);
create index idx_consultations_status on public.consultations(status);

-- ── RATINGS ─────────────────────────────────────────────────
create table public.ratings (
  id              uuid primary key default uuid_generate_v4(),
  consultation_id uuid unique references public.consultations(id),
  user_id         uuid references public.profiles(id),
  lawyer_id       uuid references public.profiles(id),
  stars           integer not null check (stars between 1 and 5),
  review_text     text,
  created_at      timestamptz not null default now()
);

-- ── MESSAGES (Supabase Realtime chat) ───────────────────────
create table public.messages (
  id          uuid primary key default uuid_generate_v4(),
  thread_id   text not null,
  sender_id   uuid references public.profiles(id),
  receiver_id uuid references public.profiles(id),
  content     text not null,
  status      text not null default 'SENT' check (status in ('SENT','DELIVERED','READ')),
  created_at  timestamptz not null default now()
);

create index idx_messages_thread on public.messages(thread_id, created_at desc);

-- Enable Realtime on messages and consultations
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.consultations;

-- ── ROW LEVEL SECURITY ───────────────────────────────────────
alter table public.profiles         enable row level security;
alter table public.lawyer_profiles  enable row level security;
alter table public.specialties      enable row level security;
alter table public.lawyer_specialties enable row level security;
alter table public.consultations    enable row level security;
alter table public.ratings          enable row level security;
alter table public.messages         enable row level security;

-- profiles
create policy "Profiles viewable by authenticated"
  on public.profiles for select to authenticated using (true);
create policy "Users can insert own profile"
  on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update to authenticated using (auth.uid() = id);

-- lawyer_profiles
create policy "Approved lawyers visible to all"
  on public.lawyer_profiles for select to authenticated
  using (verification_status = 'APPROVED' or auth.uid() = id);
create policy "Lawyers can insert own lawyer profile"
  on public.lawyer_profiles for insert to authenticated with check (auth.uid() = id);
create policy "Lawyers can update own lawyer profile"
  on public.lawyer_profiles for update to authenticated using (auth.uid() = id);

-- specialties (public read)
create policy "Specialties are public"
  on public.specialties for select using (true);
create policy "Lawyer specialties are public"
  on public.lawyer_specialties for select using (true);

-- consultations
create policy "Parties can view their consultations"
  on public.consultations for select to authenticated
  using (auth.uid() = user_id or auth.uid() = lawyer_id);
create policy "Users can create consultations"
  on public.consultations for insert to authenticated
  with check (auth.uid() = user_id);
create policy "Parties can update consultation status"
  on public.consultations for update to authenticated
  using (auth.uid() = user_id or auth.uid() = lawyer_id);

-- ratings
create policy "Ratings viewable by authenticated"
  on public.ratings for select to authenticated using (true);
create policy "Users can insert ratings"
  on public.ratings for insert to authenticated with check (auth.uid() = user_id);

-- messages
create policy "Parties can read messages"
  on public.messages for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Sender can insert messages"
  on public.messages for insert to authenticated
  with check (auth.uid() = sender_id);

-- ── SEED: SPECIALTIES ────────────────────────────────────────
insert into public.specialties (name, slug) values
  ('Criminal Law',          'criminal-law'),
  ('Civil Law',             'civil-law'),
  ('Corporate Law',         'corporate-law'),
  ('Family Law',            'family-law'),
  ('Property Law',          'property-law'),
  ('Labour & Employment',   'labour-employment'),
  ('Tax Law',               'tax-law'),
  ('Intellectual Property', 'intellectual-property'),
  ('Consumer Protection',   'consumer-protection'),
  ('Cyber Law',             'cyber-law'),
  ('Constitutional Law',    'constitutional-law'),
  ('Immigration Law',       'immigration-law'),
  ('Banking & Finance',     'banking-finance'),
  ('Environmental Law',     'environmental-law'),
  ('Insurance Law',         'insurance-law');

-- ── Supabase Storage buckets (run separately if needed) ─────
-- Go to: Storage → New bucket
--   Name: "lawyer-licenses"   Public: OFF  (private — only lawyer + admin can read)
--   Name: "profile-photos"    Public: ON   (public CDN)

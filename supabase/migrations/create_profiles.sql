-- profiles: one row per user
create table if not exists public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  role               text not null default 'USER',
  full_name          text not null default '',
  preferred_language text not null default 'English',
  phone              text,
  city               text,
  state              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- lawyer_profiles: only lawyers get a row here
create table if not exists public.lawyer_profiles (
  id                  uuid primary key references public.profiles(id) on delete cascade,
  verification_status text not null default 'PENDING_UPLOAD',
  license_url         text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- RLS
alter table public.profiles enable row level security;
alter table public.lawyer_profiles enable row level security;

create policy "Users manage own profile"
  on public.profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Lawyers manage own lawyer profile"
  on public.lawyer_profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

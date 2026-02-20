-- Run this in Supabase: Dashboard → SQL Editor → New query → paste → Run
-- Fixes: "Could not find the table 'public.profiles' in the schema cache"

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  app_user_id uuid not null unique,
  display_name text not null,
  email text,
  aura_variant int,
  aura_palette_index int,
  glyph_grid text,
  created_at timestamptz default now(),
  streak_count int not null default 0,
  streak_last_date date
);

alter table public.profiles enable row level security;
create policy "Allow all for profiles" on public.profiles for all using (true) with check (true);

-- Unique display names (case-insensitive, trimmed).
-- If you already have duplicate display names, fix them first, e.g.:
--   update profiles set display_name = display_name || '_' || left(app_user_id::text, 8) where id in (...);
-- Then run the next line.
create unique index if not exists profiles_display_name_lower_key
  on public.profiles (lower(trim(display_name)));

-- RPC: true if another user already has this display name (case-insensitive). p_exclude_id = current user's auth id when updating; null when signing up.
create or replace function public.check_display_name_taken(p_name text, p_exclude_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1 from profiles
    where lower(trim(display_name)) = lower(trim(nullif(p_name, '')))
      and (p_exclude_id is null or id != p_exclude_id)
  );
$$;

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

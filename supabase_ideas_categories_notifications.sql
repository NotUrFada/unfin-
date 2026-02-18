-- Run this in Supabase: Dashboard → SQL Editor → New query → paste → Run
-- Creates tables needed for ideas, feed, explore, and profile. Run after supabase_profiles_only.sql (or with full SUPABASE_SETUP.md Section 3).

-- Ideas
create table if not exists public.ideas (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null,
  content text not null,
  author_id uuid not null,
  author_display_name text not null,
  created_at timestamptz not null default now(),
  contributions jsonb not null default '[]',
  attachments jsonb not null default '[]'
);

-- Categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  action_verb text not null,
  is_system boolean not null default false
);

-- Notifications
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  idea_id uuid not null,
  contribution_id uuid,
  actor_display_name text not null,
  target_display_name text not null,
  created_at timestamptz not null default now(),
  is_read boolean not null default false
);

-- RLS
alter table public.ideas enable row level security;
alter table public.categories enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Allow all for ideas" on public.ideas;
create policy "Allow all for ideas" on public.ideas for all using (true) with check (true);

drop policy if exists "Allow all for categories" on public.categories;
create policy "Allow all for categories" on public.categories for all using (true) with check (true);

drop policy if exists "Allow all for notifications" on public.notifications;
create policy "Allow all for notifications" on public.notifications for all using (true) with check (true);

-- Push tokens (for iOS remote notifications)
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  app_user_id uuid not null,
  device_token text not null,
  created_at timestamptz not null default now(),
  unique(app_user_id, device_token)
);
alter table public.push_tokens enable row level security;
drop policy if exists "Allow all for push_tokens" on public.push_tokens;
create policy "Allow all for push_tokens" on public.push_tokens for all using (true) with check (true);

-- Storage bucket for attachments (ignore if already exists)
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;
drop policy if exists "Allow all for attachments" on storage.objects;
create policy "Allow all for attachments" on storage.objects for all using (bucket_id = 'attachments') with check (bucket_id = 'attachments');

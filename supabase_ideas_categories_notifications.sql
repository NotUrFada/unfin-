-- Run this in Supabase: Dashboard → SQL Editor → New query → paste → Run
-- Creates tables needed for ideas, feed, explore, and profile. Run after supabase_profiles_only.sql (or with full SUPABASE_SETUP.md Section 3).

-- Ideas (voice_path: optional storage path for voice-recorded idea)
create table if not exists public.ideas (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null,
  content text not null,
  voice_path text,
  author_id uuid not null,
  author_display_name text not null,
  created_at timestamptz not null default now(),
  contributions jsonb not null default '[]',
  attachments jsonb not null default '[]'
);
alter table public.ideas add column if not exists voice_path text;
alter table public.ideas add column if not exists finished_at timestamptz;
alter table public.ideas add column if not exists is_sensitive boolean not null default false;
alter table public.ideas add column if not exists average_rating real;
alter table public.ideas add column if not exists rating_count int not null default 0;
alter table public.ideas add column if not exists drawing_path text;
alter table public.ideas add column if not exists completion_percentage int not null default 0;
alter table public.ideas add column if not exists closes_at timestamptz;

-- Idea ratings (1–5 stars per user per idea; distinguishes “idea maker” quality from “contributor” quality)
create table if not exists public.idea_ratings (
  idea_id uuid not null references public.ideas(id) on delete cascade,
  rater_id uuid not null,
  rating int not null check (rating >= 1 and rating <= 5),
  created_at timestamptz not null default now(),
  primary key (idea_id, rater_id)
);
create index if not exists idea_ratings_idea_id on public.idea_ratings(idea_id);
create index if not exists idea_ratings_rater_id on public.idea_ratings(rater_id);
alter table public.idea_ratings enable row level security;
drop policy if exists "Allow all for idea_ratings" on public.idea_ratings;
create policy "Allow all for idea_ratings" on public.idea_ratings for all using (true) with check (true);

create or replace function public.update_idea_rating_aggregate()
returns trigger language plpgsql as $$
declare
  target_id uuid;
begin
  if TG_OP = 'DELETE' then
    target_id := OLD.idea_id;
  else
    target_id := NEW.idea_id;
  end if;
  update public.ideas
  set
    average_rating = (select avg(rating)::real from public.idea_ratings where idea_id = target_id),
    rating_count = (select count(*)::int from public.idea_ratings where idea_id = target_id)
  where id = target_id;
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end;
$$;
drop trigger if exists tr_idea_ratings_aggregate on public.idea_ratings;
create trigger tr_idea_ratings_aggregate
  after insert or update or delete on public.idea_ratings
  for each row execute function public.update_idea_rating_aggregate();

-- Categories
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  action_verb text not null,
  is_system boolean not null default false
);
alter table public.categories add column if not exists creator_id uuid;

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

-- Reports (for later moderation; no in-app action yet)
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null,
  idea_id uuid not null references public.ideas(id) on delete cascade,
  contribution_id uuid,
  reason text not null,
  details text,
  created_at timestamptz not null default now()
);
create index if not exists reports_idea_id on public.reports(idea_id);
create index if not exists reports_reporter_id on public.reports(reporter_id);
alter table public.reports enable row level security;
drop policy if exists "Allow all for reports" on public.reports;
create policy "Allow all for reports" on public.reports for all using (true) with check (true);

-- User-hidden ideas (per-user "don't show this again")
create table if not exists public.user_hidden_ideas (
  user_id uuid not null,
  idea_id uuid not null references public.ideas(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, idea_id)
);
create index if not exists user_hidden_ideas_user_id on public.user_hidden_ideas(user_id);
alter table public.user_hidden_ideas enable row level security;
drop policy if exists "Allow all for user_hidden_ideas" on public.user_hidden_ideas;
create policy "Allow all for user_hidden_ideas" on public.user_hidden_ideas for all using (true) with check (true);

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

-- Streaks (profiles: consecutive days with at least one idea, contribution, or comment)
alter table public.profiles add column if not exists streak_count int not null default 0;
alter table public.profiles add column if not exists streak_last_date date;

-- Storage bucket for attachments (ignore if already exists)
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;
drop policy if exists "Allow all for attachments" on storage.objects;
create policy "Allow all for attachments" on storage.objects for all using (bucket_id = 'attachments') with check (bucket_id = 'attachments');

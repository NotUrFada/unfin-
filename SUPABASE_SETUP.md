# Supabase setup for Unfin

The app uses **Supabase** for auth, database (Postgres), and storage instead of Firebase.

**If you see:** *"Could not find the table 'public.profiles' in the schema cache"* → run the SQL in **Section 3** or `supabase_profiles_only.sql` in **Supabase Dashboard → SQL Editor**.

**If ideas don’t save or don’t show in feed/explore/profile** → the `ideas` (and related) tables are missing. Run **Section 3** or `supabase_ideas_categories_notifications.sql` in **Supabase Dashboard → SQL Editor**.

**Voice ideas and edit/delete** → the schema includes `voice_path` on ideas and voice/edited fields in contributions and comments (JSONB). If you already ran the SQL before, run `supabase_ideas_categories_notifications.sql` again (it uses `add column if not exists`) or run: `alter table public.ideas add column if not exists voice_path text;`

**Streaks** → profiles need `streak_count` and `streak_last_date`. Run the migration in `supabase_ideas_categories_notifications.sql` (add column if not exists) or: `alter table public.profiles add column if not exists streak_count int not null default 0; alter table public.profiles add column if not exists streak_last_date date;`

## 1. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) and create a project.
2. In **Project Settings → API**, copy:
   - **Project URL** (e.g. `https://xxxx.supabase.co`)
   - **anon public** key

## 2. Configure the app

1. Open **Afterlight/Supabase-Info.plist** in Xcode (or the `Afterlight` folder in the project).
2. Set:
   - **SUPABASE_URL** → your Project URL
   - **SUPABASE_ANON_KEY** → your anon public key

## 3. Database schema

Run this SQL in the Supabase **SQL Editor** (Dashboard → SQL Editor) to create the tables and storage bucket:

```sql
-- Profiles (extends auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  app_user_id uuid not null unique,
  display_name text not null,
  email text,
  aura_variant int,
  aura_palette_index int,
  glyph_grid text,
  created_at timestamptz default now()
);

-- Ideas
create table public.ideas (
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
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  action_verb text not null,
  is_system boolean not null default false
);

-- Notifications
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  idea_id uuid not null,
  contribution_id uuid,
  actor_display_name text not null,
  target_display_name text not null,
  created_at timestamptz not null default now(),
  is_read boolean not null default false
);

-- RLS (allow anon for now; tighten in production)
alter table public.profiles enable row level security;
alter table public.ideas enable row level security;
alter table public.categories enable row level security;
alter table public.notifications enable row level security;

create policy "Allow all for profiles" on public.profiles for all using (true) with check (true);
create policy "Allow all for ideas" on public.ideas for all using (true) with check (true);
create policy "Allow all for categories" on public.categories for all using (true) with check (true);
create policy "Allow all for notifications" on public.notifications for all using (true) with check (true);

-- Storage bucket for attachments
insert into storage.buckets (id, name, public) values ('attachments', 'attachments', false);
create policy "Allow all for attachments" on storage.objects for all using (bucket_id = 'attachments') with check (bucket_id = 'attachments');
```

## 4. Push notifications (optional)

The app registers for remote push when the user is logged in and saves the device token to Supabase (`push_tokens` table). The SQL in **Section 3** (or `supabase_ideas_categories_notifications.sql`) includes the `push_tokens` table. In Xcode, add **Push Notifications** under **Signing & Capabilities** if you don’t already have it (the project includes `Unfin.entitlements` with `aps-environment`). To *send* push notifications when new rows are inserted into `notifications`, you need a server that calls APNs (e.g. a Supabase Edge Function with an Apple .p8 key, or a separate push provider).

## 5. Build and run

Open **Afterlight.xcodeproj** in Xcode, ensure the **Supabase** package has resolved, then build (⌘B) and run (⌘R). Sign up or log in with email/password; the app will create a profile and sync ideas, categories, and notifications with Supabase.

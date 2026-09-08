-- =========================================================
-- Momentum — Supabase schema
-- Run this in the Supabase SQL editor (or via `supabase db push`)
-- =========================================================

-- Needed for gen_random_uuid()
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------
-- HABITS
-- ---------------------------------------------------------
create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  icon text not null default 'star',            -- icon key rendered client-side
  color text not null default '#6C5CE7',        -- hex color for the habit
  frequency text not null default 'daily'        -- 'daily' | 'weekly' | 'custom'
      check (frequency in ('daily', 'weekly', 'custom')),
  custom_days int[] default null,               -- ISO weekdays 1=Mon..7=Sun, used when frequency='custom'
  target_per_period int not null default 1,     -- e.g. "3x per week"
  reminder_time time,                           -- local reminder time, nullable
  archived boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists habits_user_id_idx on public.habits (user_id);

-- ---------------------------------------------------------
-- HABIT LOGS  (one row per completed day; delete row = "un-tick")
-- ---------------------------------------------------------
create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,                       -- the calendar day being ticked (supports backdating)
  completed_at timestamptz not null default now(),
  note text,
  unique (habit_id, log_date)
);

create index if not exists habit_logs_habit_id_idx on public.habit_logs (habit_id);
create index if not exists habit_logs_user_date_idx on public.habit_logs (user_id, log_date);

-- ---------------------------------------------------------
-- JOURNAL ENTRIES (notes + photos, optionally linked to a habit)
-- ---------------------------------------------------------
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  habit_id uuid references public.habits (id) on delete set null,
  entry_date date not null default current_date,
  title text,
  body text,
  image_paths text[] default '{}',              -- storage object paths in 'journal-media' bucket
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists journal_user_id_idx on public.journal_entries (user_id);
create index if not exists journal_habit_id_idx on public.journal_entries (habit_id);

-- ---------------------------------------------------------
-- USER SETTINGS (theme, default home view, etc.)
-- ---------------------------------------------------------
create table if not exists public.user_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  theme_mode text not null default 'system' check (theme_mode in ('system', 'light', 'dark')),
  home_view text not null default 'streak' check (home_view in ('streak', 'list')),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_habits_updated_at on public.habits;
create trigger trg_habits_updated_at before update on public.habits
  for each row execute function public.set_updated_at();

drop trigger if exists trg_journal_updated_at on public.journal_entries;
create trigger trg_journal_updated_at before update on public.journal_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------
-- Auto-create a settings row when a user signs up
-- ---------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.user_settings (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================
alter table public.habits enable row level security;
alter table public.habit_logs enable row level security;
alter table public.journal_entries enable row level security;
alter table public.user_settings enable row level security;

-- habits
create policy "habits_select_own" on public.habits for select using (auth.uid() = user_id);
create policy "habits_insert_own" on public.habits for insert with check (auth.uid() = user_id);
create policy "habits_update_own" on public.habits for update using (auth.uid() = user_id);
create policy "habits_delete_own" on public.habits for delete using (auth.uid() = user_id);

-- habit_logs
create policy "logs_select_own" on public.habit_logs for select using (auth.uid() = user_id);
create policy "logs_insert_own" on public.habit_logs for insert with check (auth.uid() = user_id);
create policy "logs_update_own" on public.habit_logs for update using (auth.uid() = user_id);
create policy "logs_delete_own" on public.habit_logs for delete using (auth.uid() = user_id);

-- journal_entries
create policy "journal_select_own" on public.journal_entries for select using (auth.uid() = user_id);
create policy "journal_insert_own" on public.journal_entries for insert with check (auth.uid() = user_id);
create policy "journal_update_own" on public.journal_entries for update using (auth.uid() = user_id);
create policy "journal_delete_own" on public.journal_entries for delete using (auth.uid() = user_id);

-- user_settings
create policy "settings_select_own" on public.user_settings for select using (auth.uid() = user_id);
create policy "settings_update_own" on public.user_settings for update using (auth.uid() = user_id);
create policy "settings_insert_own" on public.user_settings for insert with check (auth.uid() = user_id);

-- =========================================================
-- STORAGE: bucket for journal photos
-- =========================================================
insert into storage.buckets (id, name, public)
values ('journal-media', 'journal-media', false)
on conflict (id) do nothing;

-- Users can only read/write files under a folder named after their own uid:
-- journal-media/<user_id>/<filename>
create policy "journal_media_select_own"
  on storage.objects for select
  using (bucket_id = 'journal-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "journal_media_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'journal-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "journal_media_delete_own"
  on storage.objects for delete
  using (bucket_id = 'journal-media' and (storage.foldername(name))[1] = auth.uid()::text);

-- =========================================================
-- Convenience view: today's habits with completion + current streak
-- (used by the app and by the Android widget's lightweight fetch)
-- =========================================================
create or replace view public.today_habit_status as
select
  h.id as habit_id,
  h.user_id,
  h.name,
  h.icon,
  h.color,
  h.frequency,
  h.target_per_period,
  exists (
    select 1 from public.habit_logs l
    where l.habit_id = h.id and l.log_date = current_date
  ) as done_today
from public.habits h
where h.archived = false;

comment on view public.today_habit_status is
  'One row per active habit with whether it has been ticked off today. Streaks are computed client-side from habit_logs for full flexibility.';

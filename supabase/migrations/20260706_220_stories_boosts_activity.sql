-- ================================================
-- Stories, profile boosts, and Silver+ activity center
-- Run in Supabase SQL Editor.
-- Safe to re-run (all guards are idempotent).
-- Handles tables left over from partial previous runs.
-- ================================================

-- 1. Extend users table with boost & seed columns
alter table public.users
    add column if not exists show_in_public boolean not null default true,
    add column if not exists boost_expires_at timestamptz,
    add column if not exists boost_score integer not null default 0,
    add column if not exists boost_started_at timestamptz,
    add column if not exists is_seed_profile boolean not null default false;

create index if not exists users_boost_expires_idx on public.users (boost_expires_at desc);
create index if not exists users_seed_public_idx on public.users (is_seed_profile, show_in_public);

-- 2. Profile views
create table if not exists public.profile_views (
    id uuid primary key default gen_random_uuid(),
    viewed_id uuid not null references public.users(id) on delete cascade,
    viewer_id uuid references public.users(id) on delete set null,
    viewer_key text,
    source text not null default 'member',
    created_at timestamptz not null default now()
);

-- Backfill columns if table existed from a partial run
alter table public.profile_views add column if not exists viewed_id uuid references public.users(id) on delete cascade;
alter table public.profile_views add column if not exists viewer_id uuid references public.users(id) on delete set null;
alter table public.profile_views add column if not exists viewer_key text;
alter table public.profile_views add column if not exists source text not null default 'member';
alter table public.profile_views add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'profile_views_viewed_viewer_source_created_key'
    ) then
        alter table public.profile_views
            add constraint profile_views_viewed_viewer_source_created_key
            unique (viewed_id, viewer_id, source, created_at);
    end if;
end $$;

create index if not exists profile_views_viewed_created_idx on public.profile_views (viewed_id, created_at desc);
create index if not exists profile_views_viewer_created_idx on public.profile_views (viewer_id, created_at desc);

-- 3. Profile boosts
create table if not exists public.profile_boosts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    tier text not null default 'silver',
    status text not null default 'active',
    source text not null default 'member',
    starts_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours'),
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.profile_boosts add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.profile_boosts add column if not exists tier text not null default 'silver';
alter table public.profile_boosts add column if not exists status text not null default 'active';
alter table public.profile_boosts add column if not exists source text not null default 'member';
alter table public.profile_boosts add column if not exists starts_at timestamptz not null default now();
alter table public.profile_boosts add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');
alter table public.profile_boosts add column if not exists created_at timestamptz not null default now();

create index if not exists profile_boosts_active_idx on public.profile_boosts (status, expires_at desc);
create index if not exists profile_boosts_user_idx on public.profile_boosts (user_id, created_at desc);

-- 4. User stories
create table if not exists public.user_stories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    caption text,
    media_url text not null,
    media_type text not null default 'image',
    background text,
    status text not null default 'active',
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '24 hours')
);

-- Backfill columns
alter table public.user_stories add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.user_stories add column if not exists caption text;
alter table public.user_stories add column if not exists media_url text;
alter table public.user_stories add column if not exists media_type text not null default 'image';
alter table public.user_stories add column if not exists background text;
alter table public.user_stories add column if not exists status text not null default 'active';
alter table public.user_stories add column if not exists created_at timestamptz not null default now();
alter table public.user_stories add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');

create index if not exists user_stories_active_idx on public.user_stories (status, expires_at desc, created_at desc);
create index if not exists user_stories_user_idx on public.user_stories (user_id, created_at desc);

-- 5. Story views
create table if not exists public.story_views (
    id uuid primary key default gen_random_uuid(),
    story_id uuid not null references public.user_stories(id) on delete cascade,
    viewer_id uuid references public.users(id) on delete set null,
    viewer_key text,
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.story_views add column if not exists story_id uuid references public.user_stories(id) on delete cascade;
alter table public.story_views add column if not exists viewer_id uuid references public.users(id) on delete set null;
alter table public.story_views add column if not exists viewer_key text;
alter table public.story_views add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'story_views_story_id_viewer_id_key'
    ) then
        alter table public.story_views
            add constraint story_views_story_id_viewer_id_key
            unique (story_id, viewer_id);
    end if;
end $$;

create index if not exists story_views_story_idx on public.story_views (story_id, created_at desc);
create index if not exists story_views_viewer_idx on public.story_views (viewer_id, created_at desc);

-- 6. Story likes
create table if not exists public.story_likes (
    id uuid primary key default gen_random_uuid(),
    story_id uuid not null references public.user_stories(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

-- Backfill columns
alter table public.story_likes add column if not exists story_id uuid references public.user_stories(id) on delete cascade;
alter table public.story_likes add column if not exists user_id uuid references public.users(id) on delete cascade;
alter table public.story_likes add column if not exists created_at timestamptz not null default now();

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'story_likes_story_id_user_id_key'
    ) then
        alter table public.story_likes
            add constraint story_likes_story_id_user_id_key
            unique (story_id, user_id);
    end if;
end $$;

create index if not exists story_likes_story_idx on public.story_likes (story_id, created_at desc);
create index if not exists story_likes_user_idx on public.story_likes (user_id, created_at desc);

-- 7. Storage bucket for story media
insert into storage.buckets (id, name, public)
values ('story-media', 'story-media', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Story media public read" on storage.objects;
create policy "Story media public read"
on storage.objects for select
using (bucket_id = 'story-media');

drop policy if exists "Story media authenticated insert" on storage.objects;
create policy "Story media authenticated insert"
on storage.objects for insert
with check (bucket_id = 'story-media');

-- 8. RLS for new tables
alter table public.profile_views enable row level security;
alter table public.profile_boosts enable row level security;
alter table public.user_stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

-- Permissive policies (service-role bypasses RLS for admin routes)
do $$
declare t text;
begin
    foreach t in array array[
        'profile_views','profile_boosts','user_stories','story_views','story_likes'
    ] loop
        execute format('drop policy if exists "app all %1$s" on public.%1$I', t);
        execute format('create policy "app all %1$s" on public.%1$I for all using (true) with check (true)', t);
    end loop;
end $$;

-- 9. Realtime for stories (optional, skip if already added)
do $$
begin
    begin alter publication supabase_realtime add table public.user_stories; exception when duplicate_object or undefined_table then null; end;
    begin alter publication supabase_realtime add table public.story_views; exception when duplicate_object or undefined_table then null; end;
    begin alter publication supabase_realtime add table public.story_likes; exception when duplicate_object or undefined_table then null; end;
end $$;

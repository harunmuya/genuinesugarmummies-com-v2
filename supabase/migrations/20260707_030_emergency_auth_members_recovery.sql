-- Emergency auth/members recovery for existing production data.
-- Safe to rerun. Does not delete client data.

create extension if not exists pgcrypto;

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'users' and column_name = 'id' and data_type = 'uuid'
    ) then
        execute 'alter table public.users alter column id set default gen_random_uuid()';
    elsif exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'users' and column_name = 'id'
    ) then
        execute 'alter table public.users alter column id set default gen_random_uuid()::text';
    end if;
end $$;

alter table if exists public.users
    add column if not exists username text,
    add column if not exists password_hash text,
    add column if not exists password_updated_at timestamptz,
    add column if not exists avatar_url text,
    add column if not exists bio text,
    add column if not exists description text,
    add column if not exists age integer,
    add column if not exists location text,
    add column if not exists city text,
    add column if not exists country text,
    add column if not exists phone text,
    add column if not exists phone_number text,
    add column if not exists show_in_public boolean not null default false,
    add column if not exists admin_approved boolean not null default true,
    add column if not exists package_locked boolean not null default false,
    add column if not exists is_banned boolean not null default false,
    add column if not exists is_suspended boolean not null default false,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now(),
    add column if not exists last_seen_at timestamptz,
    add column if not exists last_seen timestamptz,
    add column if not exists verification_status text not null default 'unsubmitted',
    add column if not exists subscription_tier text not null default 'free';

update public.users
set
    username = coalesce(nullif(username, ''), lower(regexp_replace(split_part(coalesce(email, id::text), '@', 1), '[^a-zA-Z0-9_]+', '_', 'g'))),
    phone_number = coalesce(nullif(phone_number, ''), phone),
    phone = coalesce(nullif(phone, ''), phone_number),
    bio = coalesce(bio, description),
    description = coalesce(description, bio),
    city = coalesce(nullif(city, ''), location),
    updated_at = coalesce(updated_at, now())
where id is not null;

with duplicate_usernames as (
    select id, username, row_number() over (partition by lower(username) order by created_at nulls last, id) as duplicate_number
    from public.users
    where username is not null and username <> ''
)
update public.users u
set username = left(duplicate_usernames.username, 17) || '_' || left(replace(u.id::text, '-', ''), 6)
from duplicate_usernames
where u.id = duplicate_usernames.id and duplicate_usernames.duplicate_number > 1;

create unique index if not exists users_email_unique_idx on public.users (lower(email)) where email is not null and email <> '';
create unique index if not exists users_username_unique_idx on public.users (lower(username)) where username is not null and username <> '';
create index if not exists users_public_status_idx on public.users (show_in_public, is_banned, is_suspended, created_at desc);
create index if not exists users_login_email_idx on public.users (lower(email), password_hash);

insert into storage.buckets (id, name, public)
values ('profile-media', 'profile-media', true), ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

alter table if exists public.users enable row level security;

drop policy if exists "Users public read safe" on public.users;
create policy "Users public read safe" on public.users for select using (show_in_public = true or auth.uid() = auth_user_id);
-- Safe profile visibility repair for existing users.
-- This does not delete users, photos, messages, payments, or verification data.

alter table public.users
    add column if not exists show_in_public boolean default true,
    add column if not exists is_banned boolean default false,
    add column if not exists is_suspended boolean default false,
    add column if not exists username text;

update public.users
set is_banned = false
where is_banned is null;

update public.users
set is_suspended = false
where is_suspended is null;

update public.users
set show_in_public = true
where show_in_public is null
  and coalesce(is_banned, false) = false
  and coalesce(is_suspended, false) = false;

create index if not exists users_active_profiles_idx
    on public.users (is_banned, is_suspended, created_at desc);

create index if not exists users_username_lookup_idx
    on public.users (lower(username))
    where username is not null;

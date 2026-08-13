-- GS production hardening foundation.
-- Safe for live databases: additive schema changes only, no deletes, no truncates, no reseeding.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users: stable profile, consent, category, seed, and visibility metadata.
-- ---------------------------------------------------------------------------

alter table if exists public.users
    add column if not exists username text,
    add column if not exists display_name text,
    add column if not exists email text,
    add column if not exists avatar_url text,
    add column if not exists bio text,
    add column if not exists description text,
    add column if not exists age integer,
    add column if not exists location text,
    add column if not exists city text,
    add column if not exists country text,
    add column if not exists phone text,
    add column if not exists phone_number text,
    add column if not exists profile_label text,
    add column if not exists member_category text,
    add column if not exists looking_for text,
    add column if not exists wants text,
    add column if not exists needed_qualities text,
    add column if not exists age_range_preference text,
    add column if not exists auth_user_id uuid,
    add column if not exists show_in_public boolean default true,
    add column if not exists admin_approved boolean default true,
    add column if not exists package_locked boolean default false,
    add column if not exists is_banned boolean default false,
    add column if not exists is_suspended boolean default false,
    add column if not exists is_seed_profile boolean not null default false,
    add column if not exists boost_expires_at timestamptz,
    add column if not exists boost_score integer not null default 0,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists updated_at timestamptz not null default now(),
    add column if not exists account_type text,
    add column if not exists profile_intent text,
    add column if not exists profile_completion_status text not null default 'incomplete',
    add column if not exists profile_completed_at timestamptz,
    add column if not exists terms_accepted_at timestamptz,
    add column if not exists privacy_accepted_at timestamptz,
    add column if not exists community_guidelines_accepted_at timestamptz,
    add column if not exists last_prompted_complete_profile_at timestamptz,
    add column if not exists location_consent_at timestamptz,
    add column if not exists precise_location_consent_at timestamptz,
    add column if not exists device_latitude numeric(10, 7),
    add column if not exists device_longitude numeric(10, 7),
    add column if not exists ip_latitude numeric(10, 7),
    add column if not exists ip_longitude numeric(10, 7),
    add column if not exists location_source text,
    add column if not exists seed_category text,
    add column if not exists seed_source_path text,
    add column if not exists seed_media_ok boolean not null default true,
    add column if not exists seed_repaired_at timestamptz,
    add column if not exists real_user boolean not null default true,
    add column if not exists profile_sort_bucket integer not null default 0,
    add column if not exists featured_until timestamptz,
    add column if not exists last_engagement_at timestamptz,
    add column if not exists account_deleted_at timestamptz;

alter table if exists public.users
    alter column show_in_public set default true,
    alter column admin_approved set default true,
    alter column package_locked set default false,
    alter column is_banned set default false,
    alter column is_suspended set default false;

update public.users
set
    real_user = case
        when coalesce(is_seed_profile, false) = true then false
        when email ilike 'seed+%' then false
        else coalesce(real_user, true)
    end,
    account_type = coalesce(nullif(account_type, ''), nullif(member_category, ''), nullif(profile_label, '')),
    profile_intent = coalesce(nullif(profile_intent, ''), nullif(looking_for, ''), nullif(wants, '')),
    show_in_public = coalesce(show_in_public, true),
    admin_approved = coalesce(admin_approved, true),
    package_locked = coalesce(package_locked, false),
    is_banned = coalesce(is_banned, false),
    is_suspended = coalesce(is_suspended, false)
where id is not null;

update public.users
set profile_completion_status = case
    when coalesce(display_name, '') <> ''
     and coalesce(avatar_url, '') <> ''
     and coalesce(age, 0) >= 18
     and coalesce(location, city, '') <> ''
     and coalesce(account_type, member_category, profile_label, '') <> ''
     and coalesce(profile_intent, looking_for, '') <> ''
    then 'complete'
    else 'incomplete'
end
where coalesce(is_seed_profile, false) = false;

update public.users
set
    profile_completion_status = 'complete',
    profile_completed_at = coalesce(profile_completed_at, now()),
    real_user = false
where coalesce(is_seed_profile, false) = true
   or email ilike 'seed+%';

create index if not exists users_public_runtime_idx
    on public.users (show_in_public, is_banned, is_suspended, profile_completion_status, created_at desc);

create index if not exists users_category_runtime_idx
    on public.users (account_type, member_category, profile_label, created_at desc);

create index if not exists users_seed_runtime_idx
    on public.users (is_seed_profile, seed_category, seed_media_ok);

create index if not exists users_featured_runtime_idx
    on public.users (featured_until desc, boost_expires_at desc, last_engagement_at desc);

-- ---------------------------------------------------------------------------
-- Package tier columns expected by the current application code.
-- ---------------------------------------------------------------------------

create table if not exists public.package_tiers (
    id text primary key,
    name text not null,
    price_ksh integer not null default 0,
    sort_order integer not null default 0,
    is_active boolean not null default true,
    created_at timestamptz not null default now()
);

alter table if exists public.package_tiers
    add column if not exists features jsonb default '[]'::jsonb,
    add column if not exists daily_like_limit integer default 5,
    add column if not exists daily_super_like_limit integer default 0,
    add column if not exists daily_swipe_limit integer default 10,
    add column if not exists daily_profile_view_limit integer default 10,
    add column if not exists can_see_who_liked boolean default false,
    add column if not exists can_see_who_viewed boolean default false,
    add column if not exists can_send_voice_notes boolean default false,
    add column if not exists can_send_images boolean default false,
    add column if not exists can_go_live boolean default false,
    add column if not exists can_send_gifts boolean default false,
    add column if not exists can_use_nearby boolean default false,
    add column if not exists max_gift_tier integer default 0,
    add column if not exists starting_credits integer default 0,
    add column if not exists badge_label text default '',
    add column if not exists badge_color text default '',
    add column if not exists description text default '',
    add column if not exists updated_at timestamptz not null default now();

update public.package_tiers
set
    daily_like_limit = coalesce(daily_like_limit, 5),
    daily_super_like_limit = coalesce(daily_super_like_limit, 0),
    daily_swipe_limit = coalesce(daily_swipe_limit, 10),
    daily_profile_view_limit = coalesce(daily_profile_view_limit, 10),
    can_see_who_liked = coalesce(can_see_who_liked, false),
    can_see_who_viewed = coalesce(can_see_who_viewed, false),
    can_send_voice_notes = coalesce(can_send_voice_notes, false),
    can_send_images = coalesce(can_send_images, false),
    can_go_live = coalesce(can_go_live, false),
    can_send_gifts = coalesce(can_send_gifts, false),
    can_use_nearby = coalesce(can_use_nearby, false),
    max_gift_tier = coalesce(max_gift_tier, 0),
    starting_credits = coalesce(starting_credits, 0),
    features = coalesce(features, '[]'::jsonb),
    updated_at = now()
where id is not null;

-- ---------------------------------------------------------------------------
-- Legacy chat compatibility repair.
-- ---------------------------------------------------------------------------

create table if not exists public.conversations (
    id uuid primary key default gen_random_uuid(),
    user_one_id uuid references public.users(id) on delete cascade,
    user_two_id uuid references public.users(id) on delete cascade,
    status text not null default 'active',
    last_message_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table if exists public.conversations
    add column if not exists user_one_id uuid references public.users(id) on delete cascade,
    add column if not exists user_two_id uuid references public.users(id) on delete cascade,
    add column if not exists status text not null default 'active',
    add column if not exists last_message_at timestamptz,
    add column if not exists updated_at timestamptz not null default now();

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'conversations' and column_name = 'user_id'
    ) then
        execute 'alter table public.conversations alter column user_id drop not null';
    end if;
end $$;

create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid references public.conversations(id) on delete cascade,
    sender_id uuid references public.users(id) on delete set null,
    receiver_id uuid references public.users(id) on delete set null,
    body text default '',
    message_type text not null default 'text',
    status text not null default 'sent',
    read_at timestamptz,
    delivered_at timestamptz,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

alter table if exists public.messages
    add column if not exists conversation_id uuid references public.conversations(id) on delete cascade,
    add column if not exists sender_id uuid references public.users(id) on delete set null,
    add column if not exists receiver_id uuid references public.users(id) on delete set null,
    add column if not exists body text default '',
    add column if not exists message_type text not null default 'text',
    add column if not exists status text not null default 'sent',
    add column if not exists read_at timestamptz,
    add column if not exists delivered_at timestamptz,
    add column if not exists metadata jsonb not null default '{}'::jsonb,
    add column if not exists created_at timestamptz not null default now();

update public.messages
set body = coalesce(nullif(body, ''), '')
where body is null;

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'messages' and column_name = 'content'
    ) then
        execute 'update public.messages set content = coalesce(nullif(content, ''''), nullif(body, ''''), '''') where content is null or content = ''''';
        execute 'alter table public.messages alter column content set default ''''';
        execute 'alter table public.messages alter column content set not null';
    end if;
end $$;

create index if not exists conversations_users_runtime_idx
    on public.conversations (user_one_id, user_two_id, updated_at desc);

create index if not exists messages_runtime_idx
    on public.messages (conversation_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Consent, reminders, admin attention, payments, and usage audit foundations.
-- ---------------------------------------------------------------------------

create table if not exists public.user_terms_acceptances (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    terms_version text not null default '2026-07-10',
    privacy_version text not null default '2026-07-10',
    community_version text not null default '2026-07-10',
    ip_address text,
    user_agent text,
    accepted_at timestamptz not null default now()
);

create table if not exists public.profile_completion_reminders (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    email text,
    reminder_type text not null default 'complete_profile',
    status text not null default 'queued',
    attempts integer not null default 0,
    last_error text default '',
    scheduled_for timestamptz not null default now(),
    sent_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.admin_attention_items (
    id uuid primary key default gen_random_uuid(),
    section text not null,
    item_type text not null,
    user_id uuid references public.users(id) on delete set null,
    severity text not null default 'normal',
    title text not null,
    body text default '',
    status text not null default 'open',
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    resolved_at timestamptz
);

create table if not exists public.payment_provider_configs (
    id uuid primary key default gen_random_uuid(),
    provider text not null,
    is_active boolean not null default false,
    display_name text not null,
    public_metadata jsonb not null default '{}'::jsonb,
    private_metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique(provider)
);

create table if not exists public.payment_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete set null,
    provider text not null,
    package_id text,
    amount_ksh integer,
    provider_reference text,
    status text not null default 'pending',
    raw_payload jsonb not null default '{}'::jsonb,
    reviewed_by uuid references public.users(id) on delete set null,
    reviewed_at timestamptz,
    created_at timestamptz not null default now()
);

create table if not exists public.package_usage_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.users(id) on delete cascade,
    package_id text not null default 'free',
    feature text not null,
    action text not null,
    allowed boolean not null default true,
    reason text default '',
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists public.system_health_events (
    id uuid primary key default gen_random_uuid(),
    source text not null,
    level text not null default 'info',
    message text not null,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists user_terms_user_created_idx
    on public.user_terms_acceptances (user_id, accepted_at desc);

create index if not exists profile_completion_reminders_due_idx
    on public.profile_completion_reminders (status, scheduled_for);

create index if not exists admin_attention_open_idx
    on public.admin_attention_items (status, section, severity, created_at desc);

create index if not exists payment_events_user_created_idx
    on public.payment_events (user_id, created_at desc);

create index if not exists package_usage_user_feature_idx
    on public.package_usage_events (user_id, feature, created_at desc);

create index if not exists system_health_source_created_idx
    on public.system_health_events (source, created_at desc);

alter table public.user_terms_acceptances enable row level security;
alter table public.profile_completion_reminders enable row level security;
alter table public.admin_attention_items enable row level security;
alter table public.payment_provider_configs enable row level security;
alter table public.payment_events enable row level security;
alter table public.package_usage_events enable row level security;
alter table public.system_health_events enable row level security;

drop policy if exists "Users read own terms acceptances" on public.user_terms_acceptances;
create policy "Users read own terms acceptances"
on public.user_terms_acceptances for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own reminders" on public.profile_completion_reminders;
create policy "Users read own reminders"
on public.profile_completion_reminders for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own payment events" on public.payment_events;
create policy "Users read own payment events"
on public.payment_events for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Users read own package usage" on public.package_usage_events;
create policy "Users read own package usage"
on public.package_usage_events for select
using (auth.uid() in (select auth_user_id from public.users where id = user_id));

drop policy if exists "Public read active payment providers" on public.payment_provider_configs;
create policy "Public read active payment providers"
on public.payment_provider_configs for select
using (is_active = true);

-- Service role bypasses RLS in Supabase and should perform admin writes through server routes only.

insert into public.system_health_events (source, level, message, metadata)
values (
    'migration',
    'info',
    'Production hardening foundation migration installed',
    jsonb_build_object('migration', '20260710_010_production_hardening_foundation')
);

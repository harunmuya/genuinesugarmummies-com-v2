-- Record authentication attempts, so they can be throttled.
--
-- Nothing limited them. Login accepted unlimited password guesses against any
-- address, and password reset was worse: createResetCode returns a six digit
-- number, so 900,000 possibilities, and reset_password would check as many
-- guesses as anyone cared to send.
--
-- That is a complete account takeover path against any email on the platform.
-- Request a reset for the address, then walk the code space. At a hundred
-- requests a second it averages about seventy five minutes, and nothing
-- anywhere would have noticed or slowed down.
--
-- The table is deliberately small and dumb: one row per attempt, read back over
-- a short window. No counters to keep in step, and nothing to reset by hand
-- when somebody is locked out — the window simply passes.

create table if not exists public.auth_attempts (
    id uuid primary key default gen_random_uuid(),
    -- 'login:someone@example.com' or 'reset:someone@example.com'. Scoped by
    -- address rather than by IP: an attacker moves between addresses easily,
    -- and locking an IP would take out everyone behind a shared connection,
    -- which in Kenya is most mobile users.
    scope text not null,
    succeeded boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists auth_attempts_scope_time_idx
    on public.auth_attempts (scope, created_at desc);

alter table public.auth_attempts enable row level security;

-- No policy at all, so only the service role reaches it. The API routes are the
-- only thing that should ever read or write this, and a member being able to
-- read it would hand them a list of which addresses exist.
revoke all on public.auth_attempts from anon, authenticated;

-- Old rows are useless once the window has passed, and this table grows on
-- every sign-in on the busiest path in the app.
create or replace function public.prune_auth_attempts()
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.auth_attempts where created_at < now() - interval '24 hours';
$$;

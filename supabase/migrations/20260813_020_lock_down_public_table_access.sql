-- Close the tables that the public anon key can currently read and write.
--
-- NEXT_PUBLIC_SUPABASE_ANON_KEY ships inside the JavaScript bundle. It is meant
-- to be public, and that is fine only while row level security actually
-- constrains it. Here it did not.
--
-- Twenty four tables carry a policy of the form
--
--     CREATE POLICY "..." ON public.<table> FOR ALL USING (true) WITH CHECK (true);
--
-- Several are named "Service role manages ...", but a policy with no TO clause
-- applies to every role, anon included. The name records an intention that the
-- SQL never expressed.
--
-- 20260703_110 revoked eleven of those tables from anon and authenticated, which
-- is what has been holding this together. The rest were left open.
--
-- The worst of them is password_reset_codes. It holds email, code_hash,
-- expires_at and used_at, and the reset flow in src/app/api/members/route.js
-- accepts a reset when it finds a matching, unused, unexpired row:
--
--   codeHash = sha256(email + ':' + code)      six digit code, no salt
--   select ... where email = ? and code_hash = ? and used_at is null
--                and expires_at > now()
--
-- With write access to that table an attacker does not need to intercept
-- anything or wait for a victim to request a reset. They insert their own row
-- for any email with a code_hash they computed, then call the public
-- reset_password endpoint with that code. That is account takeover on demand.
-- Read access alone is nearly as bad: the hash is unsalted over a known email
-- and a 900,000 value space, so recovering the code is seconds of work.
--
-- Nothing in the app writes to these tables from the browser. Every write goes
-- through an API route holding the service role key, which bypasses RLS. So
-- revoking anon and authenticated costs the app nothing.
--
-- The exception is realtime. Supabase delivers postgres_changes through RLS, so
-- a table the browser subscribes to must remain selectable by anon. Four
-- subscriptions exist:
--
--   call_sessions    IncomingCallManager
--   call_signals     the active call screen
--   live_comments    the live stream screen
--   live_gifts       the live stream screen
--   messages         the chat thread
--
-- messages is already restricted by a policy keyed on auth.uid(). This app does
-- not use Supabase Auth at all — it verifies passwords against its own users
-- table — so auth.uid() is null for every visitor and that subscription has
-- never delivered a single row. Polling has always been what actually worked,
-- which is why the intervals were tuned so low.
--
-- call_sessions and call_signals cannot be scoped to a viewer for the same
-- reason: with no auth.uid() there is no way for a policy to tell one member
-- from another, so leaving them selectable means every member's call metadata
-- and WebRTC signalling is readable by anyone with the public key. Twenty five
-- seconds of ring latency is not worth that, so they are closed and the app
-- polls instead. See the matching change to POLL.INCOMING_CALLS.
--
-- live_comments and live_gifts stay readable. They are public by nature: they
-- are what a live stream shows to everyone watching it.

begin;

-- ---------------------------------------------------------------------------
-- Server-only tables.
-- ---------------------------------------------------------------------------
do $$
declare
    t text;
    p record;
    server_only text[] := array[
        -- Account takeover risk, in order of severity.
        'password_reset_codes',
        'email_outbox',
        'broadcasts',
        'admin_logs',
        'app_limits',
        -- Call plumbing. Written by the API, no longer subscribed to.
        'call_sessions',
        'call_signals',
        'call_events',
        'call_requests',
        -- Member activity, all written through API routes.
        'member_follows',
        'member_gifts',
        'member_likes',
        'member_messages',
        'member_saves',
        'member_swipes',
        'profile_views',
        'user_interactions',
        'user_settings',
        'user_daily_usage',
        'package_requests',
        'support_tickets',
        'ticket_responses',
        'user_notifications'
    ];
begin
    foreach t in array server_only loop
        if to_regclass('public.' || t) is null then
            continue;
        end if;

        execute format('alter table public.%I enable row level security', t);

        -- Drop every existing policy rather than naming them. The blanket
        -- policies were created under several different names across
        -- migrations, and a DROP POLICY IF EXISTS list would silently miss any
        -- that were renamed.
        for p in
            select policyname from pg_policies
            where schemaname = 'public' and tablename = t
        loop
            execute format('drop policy %I on public.%I', p.policyname, t);
        end loop;

        -- The service role bypasses RLS, so no policy is needed for the API.
        -- No policy at all means no other role can read or write anything.
        execute format('revoke all on public.%I from anon, authenticated', t);
    end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Public live stream content: readable, never writable.
-- ---------------------------------------------------------------------------
do $$
declare
    t text;
    p record;
    read_only text[] := array['live_comments', 'live_gifts', 'live_streams'];
begin
    foreach t in array read_only loop
        if to_regclass('public.' || t) is null then
            continue;
        end if;

        execute format('alter table public.%I enable row level security', t);

        for p in
            select policyname from pg_policies
            where schemaname = 'public' and tablename = t
        loop
            execute format('drop policy %I on public.%I', p.policyname, t);
        end loop;

        -- SELECT only, and only for reading. Comments and gifts are still
        -- inserted by the API with the service role.
        execute format('revoke all on public.%I from anon, authenticated', t);
        execute format('grant select on public.%I to anon, authenticated', t);
        execute format(
            'create policy %I on public.%I for select to anon, authenticated using (true)',
            t || '_public_read', t);
    end loop;
end $$;

commit;

-- After running this, confirm nothing is left open:
--
--   select tablename, policyname, roles, cmd, qual
--   from pg_policies
--   where schemaname = 'public'
--     and (qual = 'true' or qual is null)
--   order by tablename;
--
-- Anything listed there with cmd = 'ALL' and roles including anon is another
-- instance of the problem this migration exists to fix.

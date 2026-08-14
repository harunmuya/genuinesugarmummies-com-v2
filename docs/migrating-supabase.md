# Moving this app to another Supabase project

Written 13 August 2026, while `xiqfrvjasvcwywdyszta` is restricted for
`exceed_egress_quota`.

## Read this part first

**A restricted project will not let you export your data.** Every read returns
402, including the ones you would use to take a backup:

```
$ curl -H "apikey: <anon>" ".../rest/v1/users?select=id&limit=1"
402  Service for this project is restricted due to the following violations:
     exceed_egress_quota.
```

So creating a new project and pointing the app at it today does not move the
app. It replaces it with an empty one. Every member account, message, match,
wallet balance, package approval and verification submission stays behind in a
project nobody can read.

On the app carrying most of the users, that is not a migration, it is a reset.

## The reason to move has mostly gone

The quota was exhausted by polling, and that is fixed:

| | Before | Now |
|---|---|---|
| Requests per hour, one open tab | 3,960 | 1,010 |
| While the app is backgrounded | the same rate | none at all |
| Member list first load | 240 rows | 24 per page |
| Repeat reads across screens | every time | cached and deduped |

The usage that burned 6.03 GB lands near 1.5 GB at the new rate, before caching
and pagination are counted, against a 5 GB allowance. The billing period resets
23 August. Waiting costs ten days and no data.

## If you still want to move

Do it **after** service resumes, so the data can come with it. The order below
matters: nothing points at the new project until its data is verified.

### 1. Create the project

Same region as the old one if you can, so latency does not change.

### 2. Build the schema

Paste `supabase/bootstrap/schema.sql` into the new project's SQL Editor and run
it once. That is all 26 migrations in order. Then run, in this order:

```
supabase/migrations/20260813_020_lock_down_public_table_access.sql
supabase/migrations/20260813_030_collapse_repeated_reminders.sql
```

The first is not optional. Without it `password_reset_codes` is readable and
writable by anyone holding the public anon key, which is account takeover on
demand.

### 3. Move the data

Once the old project answers again, from the old project's SQL Editor:

```sql
select json_agg(t) from public.users t;
```

Save the result, and repeat per table. Do the small ones first to prove the
process, and keep `users` last since everything references it. Insert into the
new project in dependency order: `users`, then `conversations`, `messages`,
`matches`, `member_likes`, `member_swipes`, `user_settings`, the wallet tables,
then the rest.

Row ids must be preserved. `matches`, `messages` and every `*_id` column
reference `users.id`, so regenerating ids silently detaches every relationship.

### 4. Move storage

Two buckets, `story-media` and `message-attachments`, about 5 MB in total.
Recreate both in the new project and copy the objects. Profile photos are **not**
here: they are served from genuinesugarmummies.com, so they need nothing.

### 5. Point the app at it

Three variables, all in the Vercel project `genuinesugarmummies-com-v2`:

```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```

Set them yourself, in the Vercel dashboard or with `npx vercel env add`, so the
keys are never pasted into a chat or written to a file. The service role key
bypasses row level security entirely; treat it like the database password.

Also update `next.config.js`, where `remotePatterns` and the CSP `connect-src`
both list Supabase hostnames. The new one has to be added or images and API
calls are blocked by the browser before they leave.

The Vercel URL does not change, so the installed Android app follows
automatically: it loads `https://genuinesugarmummies-com-v2.vercel.app`
remotely. No new APK.

### 6. Verify before trusting it

```
curl -s https://genuinesugarmummies-com-v2.vercel.app/api/members?per_page=1
```

Expect members, not `serviceRestricted`. Then sign in as a real member and check
that messages, matches and package tier are all there. Row counts matching is
not the same as the app working.

Keep the old project until you are sure. It costs nothing on the free plan, and
it is the only copy of anything the export missed.

## What does not move

- **The anon key changes.** It is baked into the deployed bundle, so a redeploy
  is required, which step 5 causes anyway.
- **Auth users.** This app does not use Supabase Auth: it verifies passwords
  against `users.password_hash` itself. So passwords travel with the `users`
  table and nobody has to reset anything. It is also why `auth.uid()` is null
  everywhere, which is why two realtime subscriptions never delivered.
- **The APK.** Unchanged, because the shell loads the Vercel URL.

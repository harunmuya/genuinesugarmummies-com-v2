# Switching to the new Supabase project

New project: `vcckezsguaoukqwtwlup`. Written 13 August 2026.

## Before you start

**Do not delete the old project (`xiqfrvjasvcwywdyszta`).**

It is restricted, not gone. Every existing member account, message, match,
wallet balance, package approval and verification submission is in it, and a
restricted project refuses the reads a backup needs, so none of it can be moved
today. On 23 August the billing period resets, the restriction lifts, and it can
all be exported into the new project.

Delete it and that is permanent.

So: the app comes back today with the schema and the demo profiles, and the real
member data is recovered on 23 August. Anyone who signed up before then will
need to sign up again in the meantime, or wait for their account to be restored.

## 1. Build the schema

In the new project's SQL Editor, run these in order, waiting for each:

```
supabase/bootstrap/schema-part-1.sql      80 KB
supabase/bootstrap/schema-part-2.sql      95 KB
supabase/bootstrap/schema-part-3.sql      29 KB
```

That is every migration except the demo profiles. Three pastes and the app has
somewhere to store things.

Then the two that close the security holes, in this order:

```
supabase/migrations/20260813_020_lock_down_public_table_access.sql
supabase/migrations/20260813_030_collapse_repeated_reminders.sql
```

The first is not optional. Without it `password_reset_codes` is readable and
writable by anyone holding the public anon key, which is account takeover on
demand for any address.

## 2. Demo profiles, optional

`supabase/bootstrap/seed-batch-01.sql` through `seed-batch-16.sql`, 181 profiles
in batches of twelve. They are what makes the app look populated rather than
empty. Skip them if you would rather start clean; they can be added later, and
re-running a batch is safe.

## 3. Storage buckets

Create two, both **public**, matching what the code writes to:

```
story-media            24 hour stories
message-attachments    images and voice notes in chat
```

Profile photos need nothing: they are served from genuinesugarmummies.com.

## 4. Environment variables

Three, on the Vercel project `genuinesugarmummies-com-v2`. Set them yourself —
the service role key bypasses row level security completely, so it should not
travel through a chat window or sit in a file in the repository.

```bash
npx vercel env rm NEXT_PUBLIC_SUPABASE_URL production
npx vercel env add NEXT_PUBLIC_SUPABASE_URL production
# paste: https://vcckezsguaoukqwtwlup.supabase.co

npx vercel env rm NEXT_PUBLIC_SUPABASE_ANON_KEY production
npx vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production
# paste: the anon public key

npx vercel env rm SUPABASE_SERVICE_ROLE_KEY production
npx vercel env add SUPABASE_SERVICE_ROLE_KEY production
# paste: the service_role secret
```

Use the `service_role` JWT, not the newer `sb_secret_...` key. The code calls
`createClient(url, key)` from supabase-js, which expects the JWT form.

Nothing in `next.config.js` needs editing. The image allowlist and the CSP both
derive the Supabase host from `NEXT_PUBLIC_SUPABASE_URL` now, so they follow
whatever you set.

## 5. Redeploy and check

```bash
npx vercel --prod
curl -s "https://genuinesugarmummies-com-v2.vercel.app/api/members?per_page=1"
```

`serviceRestricted: true` means the old project is still configured. An empty
`members` array with no error means the new one is live and simply has no
profiles yet.

The Vercel URL does not change, so the installed Android app picks this up on
its next launch. No new APK.

## 6. Rotate the keys

The database password and the service role key for this project were pasted
into a chat window. Rotate both once the app is running, in Settings, API and
Settings, Database. The anon and publishable keys are public by design and do
not matter.

## 7. On 23 August

Follow `docs/migrating-supabase.md` section 3 to export from the old project and
import here. Row ids must be preserved: `matches`, `messages` and every `*_id`
column reference `users.id`, so regenerating ids silently detaches every
relationship in the app.

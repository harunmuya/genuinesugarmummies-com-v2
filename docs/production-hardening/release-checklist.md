# Release Checklist

## Database

1. Run `supabase/migrations/20260710_010_production_hardening_foundation.sql`.
2. Confirm package tiers have all feature columns.
3. Confirm `messages` accepts chat inserts when legacy `content` exists.
4. Confirm `conversations` accepts two-user rows without legacy `user_id` failure.
5. Confirm RLS is enabled on new tables.
6. Confirm admin attention queue can be populated.

## Web

1. Login works for existing users.
2. Signup creates an account and redirects to profile completion.
3. Profile photo upload persists after refresh.
4. Completed real users appear in members.
5. Home swipe uses preference rules and advances after pass, like, and super like.
6. Members list shows all categories mixed.
7. Single profile view opens the selected profile.
8. Messaging, gifts, calls, live, stories, follows, and boosts show real feedback.
9. Package limits redirect to `/packages` with a clear message when exhausted.
10. Paid Silver and Gold users unlock their features after admin approval.

## Android

1. App ID, app name, icon, and target URL are correct for the target brand.
2. Location permissions are added and tested.
3. Camera and microphone permissions are tested for live, video calls, voice calls, and voice notes.
4. Push notifications work after login.
5. Offline page appears instead of a raw Vercel/browser error.
6. APK is tested on at least Android 10, 12, 14, and 15.

## Security

1. Service role key is server-only.
2. RLS is enabled on all user-owned tables.
3. Public seed/media storage is intentional.
4. Private verification documents are not public.
5. Admin actions are logged.
6. Account deletion removes app rows, auth identity, media, and email locks where required.

## Deployment

1. Build passes locally.
2. Vercel deployment uses the correct Supabase project.
3. Cache and service worker versions are bumped.
4. Smoke tests pass on production URL.
5. APK is regenerated after verified web/API stability.


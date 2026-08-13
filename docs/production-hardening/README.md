# GS Production Hardening Pack

This folder tracks the rebuild and stabilization work for the live GS app without destroying existing users, payments, messages, or verification records.

## Scope

The current codebase is a Next.js app with a Capacitor Android wrapper, Supabase database/storage/realtime, and Vercel deployment. The master rebuild request asks for:

1. Working login, signup, profile completion, and account deletion.
2. Accurate members, home swipe, matches, profile viewing, seeded profile handling, and package gating.
3. Real messaging, gifts, voice notes, voice/video calls, live video, stories, follows, boosts, notifications, and admin control.
4. Legal pages, privacy controls, permissions, email reminders, support flows, payment tracking, analytics, caching, and observability.
5. A native Android upgrade that does not depend on a Vercel WebView before release.

## Current Status

Critical blockers found in this repository:

1. `capacitor.config.json` still points the Android shell to `https://genuinesugarmummies-com-v2.vercel.app`.
2. `native-shell/index.html` is only a connection/loading shell, not a native/offline implementation of the app.
3. Android permissions now include internet, notifications, camera, microphone, audio settings, coarse location, and fine location.
4. Package enforcement is partly centralized in `src/lib/packageAccess.js`, but every route still needs a route-by-route gate audit.
5. Chat code writes `messages.body`, while some live databases may still have a non-null `messages.content` column from older migrations.
6. Chat code uses `conversations.user_one_id` and `conversations.user_two_id`, while some live databases may still have a required legacy `conversations.user_id`.
7. Email asset links in `src/lib/email.js` default to the `.com` Vercel URL.
8. Calls, live, voice notes, and media are currently web/browser implementations, not native Android SDK implementations.

## Files Added

1. `docs/production-hardening/current-audit.md`
2. `docs/production-hardening/target-architecture.md`
3. `docs/production-hardening/package-entitlements.md`
4. `docs/production-hardening/release-checklist.md`
5. `supabase/migrations/20260710_010_production_hardening_foundation.sql`

## Safe Rollout Order

1. Run the new foundation SQL migration in Supabase SQL Editor.
2. Confirm login, signup, profile edit, messaging, package visibility, and member profile loading.
3. Audit route gates and fix any endpoint that bypasses `getUserPackageAccess`.
4. Replace hardcoded `.com` URLs for the target app before Android release.
5. Only after web production is stable, start the native Android rewrite or deep Capacitor plugin implementation.

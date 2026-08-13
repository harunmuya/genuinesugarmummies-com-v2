# Current Production Audit

## Architecture Observed

The repository currently runs as:

1. Next.js frontend and API routes.
2. Supabase for auth-adjacent user records, database, storage, and realtime.
3. Vercel for web hosting and API execution.
4. Capacitor Android wrapper with `webDir` set to `native-shell` and a remote `server.url`.

This means the Android app is not yet independent from Vercel. It behaves as a WebView shell pointed at a hosted URL.

## High Severity Findings

1. Android target URL mismatch

`capacitor.config.json` points to `https://genuinesugarmummies-com-v2.vercel.app`. The master brief targets `https://genuine-sugarmummies-app.vercel.app`. Releasing an APK from this config would open the wrong app.

2. Native implementation is not present

`native-shell/index.html` is a fallback/loading page only. There are no native Android screens for auth, discovery, profile editing, messages, calls, live, packages, payments, or admin.

3. Background location is not implemented

`AndroidManifest.xml` now includes fine and coarse location. Background location is intentionally not added until the app has a fully justified background-location flow and Google Play review copy.

4. Database drift is likely

The app has many migrations from several repair phases. Live errors reported by Supabase, including missing package columns and `messages.content` not-null failures, show that production databases may not match route expectations.

5. Package gating needs full coverage audit

`src/lib/packageAccess.js` is the right center point, but feature gates must be confirmed across chat, profiles, calls, live, gifts, wallet, activity, and member actions.

6. Seeded and real user integrity needs a single source of truth

The app needs strict profile category fields and seed source metadata so the UI never guesses gender/category from names or photo paths.

## Medium Severity Findings

1. Email templates still use `.com` public asset defaults.
2. Calls and live are browser WebRTC flows and need physical Android testing.
3. Voice notes use browser `MediaRecorder`; compatibility varies inside Android WebView.
4. Payment unlock appears manual/admin driven and needs provider transaction audit records.
5. Admin panel needs a formal attention queue table so sections show reliable badges.

## Immediate Stabilization Goals

1. Make database schema tolerant of older migration states.
2. Preserve existing users and messages.
3. Normalize package tier columns.
4. Fix chat insert failures caused by legacy `content` and `user_id` constraints.
5. Add consent, reminder, admin attention, and payment audit foundations without changing current UI behavior.

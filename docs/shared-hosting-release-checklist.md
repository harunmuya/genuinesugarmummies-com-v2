# .com app release checklist

The app is a separate Next.js deployment for `app.genuinesugarmummies.com`. It does not use the `.co.ke` VPS. The WordPress site at `genuinesugarmummies.com` remains the primary SEO property. Public app information pages may be crawled so search engines can read their `noindex` metadata; APIs and authenticated member areas are disallowed, and the app publishes no sitemap. This keeps app content out of search results without blocking the signal that removes known URLs. If a URL is already indexed, monitor it in Search Console; a temporary removal request may be used for urgent cleanup.

Before deploying the app to its shared-hosting Node.js runtime:

- Set `NEXT_PUBLIC_APP_URL=https://app.genuinesugarmummies.com` and configure the existing Supabase server and session secrets for this app.
- Configure `RESEND_API_KEY`, a verified `RESEND_FROM_EMAIL`, and `ADMIN_EMAIL` if email delivery and finance alerts are expected.
- Apply `20261029_010_basic_standard_price_and_claim_offer.sql` and `20261029_020_web_push_subscriptions.sql` after the existing app migrations.
- For browser/PWA push, create a VAPID key pair and set `NEXT_PUBLIC_VAPID_PUBLIC_KEY`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, and `VAPID_SUBJECT` in the app runtime. Keep the private key server-only.
- Mobile-money payments remain manual: the member submits a transaction reference and an administrator checks the provider record. No Safaricom or Airtel payment API credentials are configured in this project.

Release status as of 29 October 2026:

- A signed 1.5.1 APK has been built for a fresh install. It uses a newly generated signing key because the previous release key was unavailable. Preserve `android/keystores/gs-global-release.jks` and `android/keystores/release-keystore.properties` in secure backups; future upgrades must use this same key. Existing installs signed with the old key cannot be upgraded in place.
- cPanel now has `app.genuinesugarmummies.com` attached to the separate document root `/home/genuine1/app.genuinesugarmummies.com`. Its A record resolves to `65.98.127.160` from both 1.1.1.1 and 8.8.8.8 (TTL 7200).
- cPanel has a Node.js 20.20.2 production application entry for `app.genuinesugarmummies.com`, with `server.js` as the startup file. The process is stopped until the deployable build and runtime configuration are ready.
- The app hostname currently returns HTTP 404 from the shared host, so do not publish a website download link or enable in-app updates yet. The connected Supabase project dashboard reports that its grace period has ended and it cannot serve requests; restore that project before app release.
- The existing file at `public/downloads/genuine-sugar-mummies.apk` was not replaced. Publish the new APK under a versioned filename after the app host and update flow are verified.
- Native Android push still needs Firebase project configuration; browser/PWA VAPID delivery alone does not enable FCM in a native shell.

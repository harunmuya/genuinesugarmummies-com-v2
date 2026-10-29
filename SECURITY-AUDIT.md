# Genuine Sugarmummies.com App Audit

This audit covers the `.com` Next.js app and its WordPress profile-feed integration. It does not include the `.co.ke` VPS. The WordPress feed change was made on the `.com` shared host only.

## Changes verified

- Listing feed returns only the two profile categories. List rows omit rendered post HTML; detail requests return it. A public testimonial post was checked against the profile endpoint and returned 404.
- New accounts are assigned the free tier by the server, regardless of a submitted `subscription_tier` value.
- Admin sign-in no longer has a built-in email/password fallback. Tokens are HMAC-signed and expire after eight hours. Set `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and preferably a dedicated `ADMIN_SESSION_SECRET` in the deployment environment; the Supabase service-role key is used only as a signing-secret fallback.
- App metadata no longer claims manual verification, no longer applies `/` as the canonical URL for every route, and uses the supplied Genuine Sugarmummies assets.

## Release blockers still open

1. **Member API identity is not consistently server-bound.** Several API routes accept `userId`, `actorUserId`, or related account identifiers from request JSON/query parameters while using the Supabase service-role client. The browser currently stores its member object in local storage; that object is not proof of identity. This can permit impersonation or access to another account's data. A signed, HttpOnly member session and per-route authorization checks are required before treating member operations as production-secure.
2. **Admin bearer token remains in local storage.** The new signature and expiry prevent token forgery and bound its lifetime, but an XSS bug could still read it. Move admin auth to a server-managed HttpOnly session and add login throttling before calling the admin surface hardened.
3. **Supabase policies and deployment secrets were not remotely audited.** Confirm that the service-role key is server-only, review RLS policies for every exposed table, and configure a unique `ADMIN_SESSION_SECRET`. No production secret values were read or changed in this work.
4. **No production release was deployed.** The local app build and tests passed, and the WordPress feed plugin was saved on the `.com` shared host. Deployment of the Next.js app, database migrations, Android signing, and end-to-end account/payment testing still require the corresponding release environments and credentials.

Do not describe the app as fully security-audited or production-hardened until the open items above are completed and tested.

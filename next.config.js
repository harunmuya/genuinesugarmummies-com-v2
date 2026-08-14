/*
  The Supabase host this deployment actually talks to, taken from the same
  variable the app itself uses.

  It was hardcoded, and had fallen behind: remotePatterns listed
  tislsfajzqcctjcrmnlg and rmsvyhfpiytcffjkozje, two projects this deployment
  no longer uses, and not xiqfrvjasvcwywdyszta, which it does. next/image
  refuses a host that is not listed, so story media and chat attachments from
  the live project could not render at all.

  Deriving it means the list cannot drift again, and moving to another Supabase
  project needs no edit here — changing NEXT_PUBLIC_SUPABASE_URL is enough. The
  old hosts stay listed so images already stored against them keep working.
*/
function supabaseHost() {
    try {
        const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
        return url ? new URL(url).hostname : null;
    } catch {
        // A malformed URL must not take the build down.
        return null;
    }
}

const SUPABASE_HOST = supabaseHost();

/** @type {import('next').NextConfig} */
const nextConfig = {
    turbopack: {
        root: __dirname,
    },

    images: {
        remotePatterns: [
            {
                protocol: 'https',
                hostname: 'genuinesugarmummies.com',
            },
            {
                protocol: 'https',
                hostname: '*.wp.com',
            },
            {
                protocol: 'https',
                hostname: 'secure.gravatar.com',
            },
            {
                protocol: 'https',
                hostname: 'lh3.googleusercontent.com',
            },
            // Whatever project this deployment is configured for.
            ...(SUPABASE_HOST ? [{ protocol: 'https', hostname: SUPABASE_HOST }] : []),
            // Earlier projects, so anything already stored against them still loads.
            {
                protocol: 'https',
                hostname: 'tislsfajzqcctjcrmnlg.supabase.co',
            },
            {
                protocol: 'https',
                hostname: 'rmsvyhfpiytcffjkozje.supabase.co',
            },
        ],
    },

    async rewrites() {
        return [
            { source: '/base-release.apk', destination: '/downloads/genuine-sugar-mummies.apk' },
            { source: '/base-realese.apk', destination: '/downloads/genuine-sugar-mummies.apk' },
        ];
    },
    // Security headers
    async headers() {
        return [
            {
                /*
                  The APK must never be served from cache.

                  /base-release.apk is a rewrite onto the real file, and the CDN
                  cached the rewrite: after shipping versionCode 4, that alias
                  kept handing out the previous build while the direct path
                  served the new one. Anyone following the update prompt would
                  have downloaded the APK they already had, and concluded the
                  update was broken.
                */
                source: '/:path*.apk',
                headers: [
                    {
                        key: 'Cache-Control',
                        value: 'public, max-age=0, must-revalidate',
                    },
                ],
            },
            {
                source: '/(.*)',
                headers: [
                    {
                        key: 'X-Frame-Options',
                        value: 'DENY',
                    },
                    {
                        key: 'X-Content-Type-Options',
                        value: 'nosniff',
                    },
                    {
                        key: 'Referrer-Policy',
                        value: 'no-referrer-when-downgrade',
                    },
                    {
                        key: 'X-DNS-Prefetch-Control',
                        value: 'on',
                    },
                    {
                        key: 'Strict-Transport-Security',
                        value: 'max-age=63072000; includeSubDomains; preload',
                    },
                    {
                        /*
                          This read `microphone=()`. An empty allowlist is not
                          "no third parties" — it disables the feature for
                          everyone, this origin included. The browser refuses
                          getUserMedia before Android is ever consulted, so
                          voice calls and the audio half of video calls could
                          not work whatever the manifest declared or the user
                          granted.

                          `self` is the value that was meant: this origin may
                          use the microphone, embedded third parties may not.
                        */
                        key: 'Permissions-Policy',
                        value: 'camera=(self), microphone=(self), geolocation=(self), display-capture=(self), interest-cohort=()',
                    },
                    {
                        key: 'Content-Security-Policy',
                        value: [
                            "default-src 'self'",
                            "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com",
                            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
                            "font-src 'self' https://fonts.gstatic.com",
                            "img-src 'self' data: blob: https:",
                            "connect-src 'self' https://genuinesugarmummies.com https://*.wp.com "
                                + (SUPABASE_HOST ? `https://${SUPABASE_HOST} wss://${SUPABASE_HOST} ` : '')
                                + "https://tislsfajzqcctjcrmnlg.supabase.co https://rmsvyhfpiytcffjkozje.supabase.co https://xiqfrvjasvcwywdyszta.supabase.co https://t.me",
                            "frame-src 'self'",
                            "frame-ancestors 'none'",
                            "base-uri 'self'",
                            "form-action 'self'",
                        ].join('; '),
                    },
                ],
            },
        ];
    },
};

module.exports = nextConfig;



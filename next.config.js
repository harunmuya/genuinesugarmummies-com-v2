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
                        key: 'Permissions-Policy',
                        value: 'camera=(self), microphone=(), geolocation=(self), interest-cohort=()',
                    },
                    {
                        key: 'Content-Security-Policy',
                        value: [
                            "default-src 'self'",
                            "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com",
                            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
                            "font-src 'self' https://fonts.gstatic.com",
                            "img-src 'self' data: blob: https:",
                            "connect-src 'self' https://genuinesugarmummies.com https://*.wp.com https://tislsfajzqcctjcrmnlg.supabase.co https://rmsvyhfpiytcffjkozje.supabase.co https://xiqfrvjasvcwywdyszta.supabase.co https://t.me",
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



export default function robots() {
    return {
        rules: [
            {
                userAgent: '*',
                allow: [
                    '/',
                    '/auth/login',
                    '/terms',
                    '/privacy',
                    '/safety',
                    '/community-guidelines',
                    '/contact',
                ],
                disallow: [
                    '/api/',
                    '/admin',
                    '/discover',
                    '/members',
                    '/messages',
                    '/calls',
                    '/wallet',
                    '/live',
                    '/alerts',
                    '/profile',
                ],
            },
        ],
    };
}

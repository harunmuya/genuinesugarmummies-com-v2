import './globals.css';

import { AuthProvider } from '@/contexts/AuthContext';
import NotificationManager from '@/components/NotificationManager';

export const viewport = {
    width: 'device-width',
    initialScale: 1,
    maximumScale: 1,
    userScalable: false,
    viewportFit: 'cover',
    themeColor: '#7C3AED',
};

export const metadata = {
    title: 'Genuine Sugar Mummies - Find Your Perfect Match',
    description: 'The #1 premium dating app for genuine sugar mummy connections. Swipe, match, and connect with verified profiles worldwide. Safe, secure, and real.',
    keywords: ['sugar mummy', 'dating app', 'connections', 'match', 'verified profiles', 'genuine sugar mummies'],
    authors: [{ name: 'Genuine Sugar Mummies' }],
    creator: 'Genuine Sugar Mummies',
    metadataBase: new URL('https://genuinesugarmummies.com'),
    alternates: {
        canonical: '/',
    },
    openGraph: {
        title: 'Genuine Sugar Mummies - Find Your Perfect Match',
        description: 'The premium dating app for genuine sugar mummy connections. Swipe, match, and connect with verified profiles.',
        url: 'https://genuinesugarmummies.com',
        siteName: 'Genuine Sugar Mummies',
        locale: 'en_US',
        type: 'website',
    },
    twitter: {
        card: 'summary_large_image',
        title: 'Genuine Sugar Mummies',
        description: 'Premium dating app for genuine connections',
    },
    manifest: '/manifest.json',
    icons: {
        icon: '/gs-logo.png',
        apple: '/gs-logo.png',
    },
    appleWebApp: {
        capable: true,
        statusBarStyle: 'default',
        title: 'GS Mummies',
    },
};

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <head>
                <link rel="preconnect" href="https://fonts.googleapis.com" />
                <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
                <link
                    href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800;900&display=swap"
                    rel="stylesheet"
                />
                <meta name="apple-mobile-web-app-capable" content="yes" />
                <meta name="mobile-web-app-capable" content="yes" />
            </head>
            <body className="antialiased" suppressHydrationWarning>
                <AuthProvider>
                    <NotificationManager />
                    {children}
                </AuthProvider>

                {/* Register Service Worker */}
                <script
                    dangerouslySetInnerHTML={{
                        __html: `
                            if ('serviceWorker' in navigator) {
                                window.addEventListener('load', () => {
                                    navigator.serviceWorker.register('/sw.js').catch(() => {});
                                });
                            }
                        `,
                    }}
                />
            </body>
        </html>
    );
}

import './globals.css';

import { AuthProvider } from '@/contexts/AuthContext';
import NotificationManager from '@/components/NotificationManager';

export const viewport = {
    width: 'device-width',
    initialScale: 1,
    /*
      Pinch-zoom was blocked here with maximumScale: 1 and userScalable: false.
      That fails WCAG 2.1 SC 1.4.4 and is a real problem on a dating app, where
      people zoom into photos and read bios on small screens. The layout is
      responsive and never relied on a locked viewport, so allowing zoom costs
      nothing.
    */
    maximumScale: 5,
    userScalable: true,
    viewportFit: 'cover',
    // Matches --color-bg-dark, so the system chrome meets the app cleanly.
    themeColor: '#09090B',
    colorScheme: 'dark',
};

export const metadata = {
    title: {
        default: 'Genuine Sugarmummies | Adult Introductions',
        template: '%s | Genuine Sugarmummies',
    },
    description: 'Discover adult profiles, set your preferences, and start conversations through Genuine Sugarmummies. Membership and paid features are explained in the app.',
    authors: [{ name: 'Genuine Sugar Mummies' }],
    creator: 'Genuine Sugar Mummies',
    metadataBase: new URL('https://app.genuinesugarmummies.com'),
    robots: {
        index: false,
        follow: false,
        noarchive: true,
        nosnippet: true,
        googleBot: { index: false, follow: false, noimageindex: true, noarchive: true, nosnippet: true },
    },
    openGraph: {
        title: 'Genuine Sugarmummies | Adult Introductions',
        description: 'Discover adult profiles, set your preferences, and start conversations through Genuine Sugarmummies.',
        siteName: 'Genuine Sugar Mummies',
        locale: 'en_KE',
        type: 'website',
    },
    twitter: {
        card: 'summary_large_image',
        title: 'Genuine Sugarmummies',
        description: 'Adult introductions and member profiles',
    },
    manifest: '/manifest.json',
    icons: {
        icon: '/gs-logo.png',
        apple: '/gs-logo.png',
    },
    appleWebApp: {
        capable: true,
        statusBarStyle: 'black-translucent',
        title: 'Genuine Sugarmummies',
    },
};

export default function RootLayout({ children }) {
    return (
        <html lang="en">
            <head>
                <link rel="preconnect" href="https://fonts.googleapis.com" />
                <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
                {/*
                  Manrope for body, Space Grotesk for headings and numerals.
                  Outfit was here, and V1 also sets Outfit, which was most of why
                  the two apps read as one product.

                  Only the weights actually used are requested. The previous link
                  pulled seven Outfit weights, of which the app used three.
                */}
                <link
                    href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=Space+Grotesk:wght@500;600;700&display=swap"
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
                                    navigator.serviceWorker.getRegistrations?.().then((regs) => regs.forEach((reg) => reg.update?.())).catch(() => {});
                                    navigator.serviceWorker.register('/sw.js?v=20260626-5', { updateViaCache: 'none' }).catch(() => {});
                                });
                            }
                        `,
                    }}
                />
            </body>
        </html>
    );
}




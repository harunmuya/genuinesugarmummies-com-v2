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
    themeColor: '#0A0E12',
    colorScheme: 'dark',
};

/*
  The title and description here were byte-identical to V1's, on a different
  domain. Two properties telling search engines they are the same thing is the
  worst of both worlds: neither ranks, and whichever loses looks like a copy of
  the other. This copy describes what this app actually is, the global one, in
  its own words.
*/
export const metadata = {
    title: 'GS Global | Meet Verified Sugar Mummies & Sugar Daddies',
    description: 'Real profiles, verified by hand. Meet sugar mummies and sugar daddies near you, message safely, and go live. Free to join.',
    keywords: ['sugar mummy', 'sugar daddy', 'verified dating', 'live video dating', 'gs global'],
    authors: [{ name: 'Genuine Sugar Mummies' }],
    creator: 'Genuine Sugar Mummies',
    metadataBase: new URL('https://genuinesugarmummies.com'),
    alternates: {
        canonical: '/',
    },
    openGraph: {
        title: 'GS Global | Meet Verified Sugar Mummies & Sugar Daddies',
        description: 'Real profiles, verified by hand. Message safely, go live, and meet people near you.',
        url: 'https://genuinesugarmummies.com',
        siteName: 'Genuine Sugar Mummies',
        locale: 'en_US',
        type: 'website',
    },
    twitter: {
        card: 'summary_large_image',
        title: 'GS Global',
        description: 'Verified sugar mummy and sugar daddy dating',
    },
    manifest: '/manifest.json',
    icons: {
        icon: '/gs-logo.png',
        apple: '/gs-logo.png',
    },
    appleWebApp: {
        capable: true,
        statusBarStyle: 'black-translucent',
        title: 'GS Global',
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




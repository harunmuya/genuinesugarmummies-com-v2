import { NextResponse } from 'next/server';

/**
 * What the current Android shell is, and where to get it.
 *
 * The web layer redeploys constantly and reaches everybody on the next reload,
 * because the Capacitor shell loads a remote URL. The shell itself only changes
 * when somebody installs an APK, and until now nothing told members that a
 * newer one existed. There was no version endpoint and no prompt, so
 * versionCode 3 has been sitting on phones with no camera or microphone
 * permissions and no way to hear about the build that has them.
 *
 * Keep CURRENT in step with android/app/build.gradle. scripts/verify-android.mjs
 * fails if they drift, because an endpoint advertising a version nobody can
 * download is worse than no endpoint: it prompts people into a loop.
 */

const CURRENT = {
    versionCode: 5,
    versionName: '1.1.1',

    /*
      Served from this deployment rather than the WordPress site.

      The site is on cPanel and its APK is updated by hand, so it lags. This
      path is the file in public/downloads, deployed with the app, and it is
      covered by the no-cache header in next.config.js so nobody is handed a
      stale build.
    */
    url: 'https://genuinesugarmummies-com-v2.vercel.app/base-release.apk',

    /*
      Shown in the prompt. Members are being asked to allow an install from
      outside Play and will see a Play Protect warning, so the reason has to be
      concrete enough to be worth it.
    */
    notes: [
        'Camera and microphone now work, so video and voice calls can connect',
        'Choose photos from your gallery when editing your profile',
        'Bluetooth headsets and car speakers work during calls',
        'Faster, and uses far less of your data in the background',
    ],

    /*
      Whether the app should insist. Reserved for a build that fixes something
      members cannot work around; a nagging prompt for a routine release is how
      people learn to dismiss the important one.
    */
    mandatory: false,
};

export function GET() {
    return NextResponse.json(CURRENT, {
        headers: {
            // Small, and checked on launch. A minute of staleness is fine; a
            // day of it means the prompt lags the release it announces.
            'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
        },
    });
}

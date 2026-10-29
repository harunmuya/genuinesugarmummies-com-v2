import { NextResponse } from 'next/server';

/**
 * Version 1.5.1 is signed with a new key and therefore requires a fresh
 * install. Do not advertise it as an in-place update to existing installs.
 */

const CURRENT = {
    versionCode: 6,
    versionName: '1.5.1',
    available: false,

    // Do not publish an in-app update target: this fresh-install build uses a different signer.
    url: '',
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

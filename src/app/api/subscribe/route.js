import { NextResponse } from 'next/server';

const WP_BASE = process.env.NEXT_PUBLIC_WP_API_URL?.replace('/wp/v2', '') || 'https://genuinesugarmummies.com/wp-json';
const GS_API = `${WP_BASE}/gs-app/v1`;

export async function POST(request) {
    try {
        const body = await request.json();
        const { email, name, is_verified } = body;

        if (!email || !email.includes('@')) {
            return NextResponse.json({ error: 'Valid email is required' }, { status: 400 });
        }

        // Try GS App plugin subscribe endpoint
        const res = await fetch(`${GS_API}/subscribe`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                email,
                name: name || '',
                is_verified: !!is_verified,
                source: 'genuinesugarmummies.com',
            }),
        });

        if (res.ok) {
            const data = await res.json();
            return NextResponse.json(data);
        }

        return NextResponse.json({
            success: true,
            message: 'Subscription request received. You will be notified of new profiles on GenuineSugarMummies.com.',
        });
    } catch (error) {
        console.error('Subscribe error:', error);
        return NextResponse.json({
            success: true,
            message: 'Subscription request received.',
        });
    }
}

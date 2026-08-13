import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';

function jsonError(message, status = 500) {
    return NextResponse.json({ error: message }, { status });
}

export async function POST(request) {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return jsonError('Supabase admin env missing.', 503);
    const body = await request.json().catch(() => ({}));
    const userId = body.userId;
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);
    if (!userId) return jsonError('User id is required.', 400);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return jsonError('Valid latitude and longitude are required.', 400);
    if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return jsonError('Invalid coordinates.', 400);

    let result = await supabase
        .from('users')
        .update({
            latitude,
            longitude,
            geo_updated_at: new Date().toISOString(),
            location_enabled: true,
            live_location: true,
        })
        .eq('id', userId)
        .select('id, latitude, longitude, geo_updated_at')
        .maybeSingle();

    if (result.error && ['42703', 'PGRST204'].includes(result.error.code)) {
        result = await supabase
            .from('users')
            .update({ latitude, longitude, geo_updated_at: new Date().toISOString() })
            .eq('id', userId)
            .select('id, latitude, longitude, geo_updated_at')
            .maybeSingle();
    }

    if (result.error) return jsonError(result.error.message);
    return NextResponse.json({ ok: true, location: result.data });
}

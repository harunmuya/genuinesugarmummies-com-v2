import { NextResponse } from 'next/server';
import { createServerSupabaseClient } from '@/lib/supabaseAdmin';
import { defaultPackageTiers } from '@/lib/packageAccess';

export async function GET() {
    const supabase = createServerSupabaseClient({ admin: true });
    if (!supabase) return NextResponse.json({ ok: true, packages: defaultPackageTiers() });
    try {
        const { data, error } = await supabase
            .from('package_tiers')
            .select('*')
            .eq('is_active', true)
            .in('id', ['basic', 'silver', 'gold'])
            .order('sort_order', { ascending: true });
        if (error || !data?.length) return NextResponse.json({ ok: true, packages: defaultPackageTiers() });
        const packages = data.map((tier) => tier.id === 'basic' ? { ...tier, price_ksh: 750 } : tier);
        return NextResponse.json({ ok: true, packages });
    } catch {
        return NextResponse.json({ ok: true, packages: defaultPackageTiers() });
    }
}

import { NextResponse } from 'next/server';
import { fetchProfiles, fetchSingleProfile } from '@/lib/wordpress';

export async function GET(request) {
    try {
        const { searchParams } = new URL(request.url);
        const id = searchParams.get('id');
        const page = parseInt(searchParams.get('page') || '1');
        const perPage = Math.min(parseInt(searchParams.get('per_page') || '25'), 100);

        if (id) {
            const profile = await fetchSingleProfile(id);
            if (!profile) {
                return NextResponse.json({ error: 'Profile not found' }, { status: 404 });
            }
            return NextResponse.json({ profiles: [profile] }, {
                headers: { 'Cache-Control': 'public, s-maxage=120, stale-while-revalidate=300' },
            });
        }

        const result = await fetchProfiles(page, perPage);

        const withImg = (result.profiles || []).filter(p => p.imageUrl).length;
        const total = (result.profiles || []).length;
        console.log(`[Profiles API] page=${page} total=${total} withImage=${withImg}`);
        // Debug: log first 3 profiles' image URLs
        (result.profiles || []).slice(0, 3).forEach((p, i) => {
            console.log(`[Profile ${i}] name="${p.name}" imageUrl="${p.imageUrl}" wpId=${p.wpId}`);
        });

        return NextResponse.json(result, {
            headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600' },
        });
    } catch (error) {
        console.error('Profiles API error:', error);
        return NextResponse.json({ error: 'Failed to fetch profiles' }, { status: 500 });
    }
}

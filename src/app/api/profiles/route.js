import { NextResponse } from 'next/server';
import { fetchProfiles, fetchSingleProfile } from '@/lib/wordpress';

export async function GET(request) {
    try {
        const { searchParams } = new URL(request.url);
        const id = searchParams.get('id');
        const page = parseInt(searchParams.get('page') || '1', 10);
        const perPage = Math.min(parseInt(searchParams.get('per_page') || '25', 10), 100);
        const random = searchParams.get('random') === '1';

        if (id) {
            const profile = await fetchSingleProfile(id);
            if (!profile) return NextResponse.json({ error: 'Profile not found' }, { status: 404 });
            return NextResponse.json({ profiles: [profile] }, {
                headers: { 'Cache-Control': 'public, s-maxage=120, stale-while-revalidate=300' },
            });
        }

        if (random) {
            const first = await fetchProfiles(1, perPage);
            const totalPages = Math.max(1, first.totalPages || 1);
            const pages = new Set([1]);
            const maxPages = Math.min(totalPages, 8);
            while (pages.size < maxPages) pages.add(1 + Math.floor(Math.random() * totalPages));

            const extraResults = await Promise.all(
                [...pages]
                    .filter((item) => item !== 1)
                    .map((item) => fetchProfiles(item, perPage).catch(() => ({ profiles: [] })))
            );
            const byId = new Map();
            [first, ...extraResults].forEach((result) => {
                (result.profiles || []).forEach((profile) => {
                    if (profile?.wpId && profile.imageUrl && !byId.has(profile.wpId)) byId.set(profile.wpId, profile);
                });
            });
            const profiles = [...byId.values()].sort(() => Math.random() - 0.5).slice(0, perPage);
            return NextResponse.json({ profiles, totalPages, totalPosts: first.totalPosts || profiles.length, random: true }, {
                headers: { 'Cache-Control': 'private, no-store' },
            });
        }

        const result = await fetchProfiles(page, perPage);
        return NextResponse.json(result, {
            headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600' },
        });
    } catch (error) {
        console.error('Profiles API error:', error);
        return NextResponse.json({ error: 'Failed to fetch profiles' }, { status: 500 });
    }
}

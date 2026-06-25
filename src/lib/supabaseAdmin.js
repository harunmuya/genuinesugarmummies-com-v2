import { createClient } from '@supabase/supabase-js';

export function getServerSupabaseConfig() {
    return {
        url: process.env.NEXT_PUBLIC_SUPABASE_URL || '',
        anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '',
        serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
    };
}

export function createServerSupabaseClient({ admin = false } = {}) {
    const { url, anonKey, serviceRoleKey } = getServerSupabaseConfig();
    const key = admin ? serviceRoleKey : anonKey;

    if (!url || !key) {
        return null;
    }

    return createClient(url, key, {
        auth: {
            persistSession: false,
            autoRefreshToken: false,
        },
    });
}
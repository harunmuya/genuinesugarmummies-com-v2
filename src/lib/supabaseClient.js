import { createClient } from '@supabase/supabase-js';

let browserClient;

export function getSupabaseConfig() {
    return {
        url: process.env.NEXT_PUBLIC_SUPABASE_URL || '',
        anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '',
    };
}

export function isSupabaseConfigured() {
    const { url, anonKey } = getSupabaseConfig();
    return Boolean(url && anonKey);
}

export function createBrowserSupabaseClient() {
    const { url, anonKey } = getSupabaseConfig();

    if (!url || !anonKey) {
        throw new Error('Supabase public environment variables are not configured.');
    }

    if (!browserClient) {
        browserClient = createClient(url, anonKey, {
            auth: {
                persistSession: true,
                autoRefreshToken: true,
                detectSessionInUrl: true,
            },
        });
    }

    return browserClient;
}
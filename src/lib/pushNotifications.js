import webpush from 'web-push';

let configured = false;

function configureWebPush() {
    const publicKey = process.env.VAPID_PUBLIC_KEY || process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    const privateKey = process.env.VAPID_PRIVATE_KEY;
    const subject = process.env.VAPID_SUBJECT || 'mailto:support@genuinesugarmummies.com';
    if (!publicKey || !privateKey) return false;
    if (!configured) {
        webpush.setVapidDetails(subject, publicKey, privateKey);
        configured = true;
    }
    return true;
}

export async function sendPushToUser(supabase, userId, payload) {
    if (!supabase || !userId || !configureWebPush()) return { sent: 0, skipped: true };
    const { data: subscriptions, error } = await supabase
        .from('push_subscriptions')
        .select('id, endpoint, p256dh, auth')
        .eq('user_id', userId)
        .eq('permission', 'granted')
        .limit(20);
    if (error || !subscriptions?.length) return { sent: 0, skipped: true };

    const results = await Promise.allSettled(subscriptions.map(async (row) => {
        try {
            await webpush.sendNotification({
                endpoint: row.endpoint,
                keys: { p256dh: row.p256dh, auth: row.auth },
            }, JSON.stringify({
                title: String(payload.title || 'Genuine Sugarmummies').slice(0, 100),
                body: String(payload.body || '').slice(0, 240),
                url: String(payload.url || '/alerts').slice(0, 300),
                tag: String(payload.tag || 'gs-activity').slice(0, 80),
                count: Math.max(1, Number(payload.count || 1)),
            }), { TTL: 60 * 60 });
            return true;
        } catch (sendError) {
            if (sendError?.statusCode === 404 || sendError?.statusCode === 410) {
                await supabase.from('push_subscriptions').delete().eq('id', row.id);
            }
            return false;
        }
    }));
    return { sent: results.filter((result) => result.status === 'fulfilled' && result.value).length, skipped: false };
}

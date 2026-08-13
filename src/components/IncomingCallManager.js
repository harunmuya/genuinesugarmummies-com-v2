'use client';

import { useEffect, useMemo, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { PhoneCall, PhoneOff, Video } from 'lucide-react';
import { startPolling, POLL } from '@/lib/poll';
import { useAuth } from '@/contexts/AuthContext';
import UserAvatar from '@/components/UserAvatar';

export default function IncomingCallManager() {
    const { user } = useAuth();
    const router = useRouter();
    const pathname = usePathname();
    const [sessions, setSessions] = useState([]);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');

    const incoming = useMemo(() => {
        if (pathname?.startsWith('/calls/')) return null;
        return (sessions || []).find((session) => (
            session.incoming &&
            session.status === 'ringing' &&
            session.receiver_id === user?.id &&
            session.caller_id &&
            session.caller_id !== user?.id
        )) || null;
    }, [pathname, sessions, user?.id]);

    async function loadCalls() {
        if (!user?.id) return;
        try {
            const res = await fetch(`/api/calls?userId=${encodeURIComponent(user.id)}`);
            const data = await res.json().catch(() => ({}));
            if (res.ok) setSessions(data.sessions || []);
        } catch {}
    }

    useEffect(() => {
        if (!user?.id) return;

        /*
          This component is mounted from (main)/layout.js, so it runs on every
          signed-in page, and it polled /api/calls every 3 seconds: 1200
          requests an hour per tab, foreground and background alike. That was a
          large part of the egress overage that got this project restricted.

          There was also a realtime subscription on call_sessions here, and it
          was removed rather than relied on.

          It did deliver, but only because call_sessions carried
          FOR ALL USING (true) WITH CHECK (true) with no TO clause. Despite
          being named "Service role manages call sessions", a policy with no TO
          clause applies to every role, so anyone with the anon key out of the
          JavaScript bundle could read, alter and delete every member's call
          rows. With no Supabase Auth session in this app there is no auth.uid()
          to scope a policy by, so the table cannot be both subscribable and
          private. It is now private, and the subscription cannot work.

          So the poll is the delivery path, at 8 seconds rather than 3. A caller
          waits at most that long, and the visibility gate means a backgrounded
          app costs nothing.
        */
        const stopPolling = startPolling(loadCalls, POLL.INCOMING_CALLS);
        return () => stopPolling();
    }, [user?.id]);

    async function setCallStatus(status) {
        if (!incoming?.id || busy) return null;
        setBusy(true);
        setError('');
        try {
            const res = await fetch('/api/calls', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ action: 'status', sessionId: incoming.id, userId: user.id, status }),
            });
            const data = await res.json().catch(() => ({}));
            if (!res.ok) {
                setError(data.error || 'Call action failed. Refresh and try again.');
                return null;
            }
            await loadCalls();
            return data.session || null;
        } catch {
            setError('Network error. Refresh and try again.');
            return null;
        } finally {
            setBusy(false);
        }
    }

    async function acceptCall() {
        const session = await setCallStatus('accepted');
        const call = session || incoming;
        if (call?.caller_id && call.caller_id !== user?.id) router.push(`/calls/${call.caller_id}?session=${call.id}&role=receiver&accept=1`);
    }

    async function declineCall() {
        await setCallStatus('declined');
    }

    if (!incoming) return null;

    const caller = incoming.caller || {};
    const callerPhoto = caller.avatar_url || caller.photos?.[0] || '';
    const isVideo = incoming.call_type === 'video';

    return (
        <div className="fixed inset-0 z-[80] flex items-end justify-center bg-black/55 px-4 pb-24 backdrop-blur-sm sm:items-center sm:pb-4">
            <div className="w-full max-w-sm overflow-hidden rounded-[28px] bg-bg-card shadow-2xl">
                <div className="gradient-primary p-5 text-white">
                    <div className="flex items-center gap-3">
                        <UserAvatar name={caller.display_name || 'Member'} src={callerPhoto} size={58} />
                        <div className="min-w-0 flex-1">
                            <p className="text-xs font-bold uppercase tracking-wide text-white/75">Incoming {isVideo ? 'video' : 'voice'} call</p>
                            <h2 className="truncate text-xl font-black">{caller.display_name || 'GS Member'}</h2>
                            <p className="text-xs text-white/80">Answer inside GS App</p>
                        </div>
                        {isVideo ? <Video size={24} /> : <PhoneCall size={24} />}
                    </div>
                </div>
                <div className="space-y-4 p-5">
                    <p className="text-sm text-text-secondary">This call is ringing through your GS account. Accept to open the secure call room, or decline to notify the caller.</p>
                    {error && <p className="rounded-2xl bg-danger/10 p-3 text-xs font-bold text-danger">{error}</p>}
                    <div className="grid grid-cols-2 gap-3">
                        <button disabled={busy} onClick={declineCall} className="flex h-12 items-center justify-center gap-2 rounded-2xl bg-danger px-4 py-3 font-black text-white disabled:opacity-60"><PhoneOff size={18} /> Decline</button>
                        <button disabled={busy} onClick={acceptCall} className="flex h-12 items-center justify-center gap-2 rounded-2xl bg-success px-4 py-3 font-black text-white disabled:opacity-60"><PhoneCall size={18} /> Accept</button>
                    </div>
                </div>
            </div>
        </div>
    );
}

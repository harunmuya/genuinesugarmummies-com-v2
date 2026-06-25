'use client';

import { useEffect, useMemo, useState } from 'react';
import {
    Activity,
    Ban,
    BarChart3,
    Bell,
    Check,
    Crown,
    Database,
    Eye,
    Gift,
    Lock,
    Mail,
    Megaphone,
    MessageCircle,
    RefreshCw,
    ShieldCheck,
    SlidersHorizontal,
    Unlock,
    UserCheck,
    Users,
    X,
} from 'lucide-react';
import Logo from '@/components/Logo';

const TABS = [
    { id: 'users', label: 'Users', icon: Users },
    { id: 'seed', label: 'Seed Mgmt', icon: Database },
    { id: 'verification', label: 'Verification', icon: ShieldCheck },
    { id: 'finance', label: 'Finance', icon: Crown },
    { id: 'analytics', label: 'Analytics', icon: BarChart3 },
    { id: 'tickets', label: 'Tickets', icon: MessageCircle },
    { id: 'broadcast', label: 'Broadcast', icon: Megaphone },
    { id: 'limits', label: 'Ads & Limits', icon: SlidersHorizontal },
    { id: 'logs', label: 'Logs', icon: Activity },
];

const TIERS = ['free', 'basic', 'silver', 'gold'];

function tierText(value) {
    return String(value || 'free').toUpperCase();
}

function statusColor(user) {
    if (user.is_suspended || user.is_banned) return 'text-danger bg-danger/10';
    if (user.verified || user.admin_approved) return 'text-success bg-success/10';
    if (user.verification_status === 'pending_admin') return 'text-gold bg-amber-100';
    return 'text-text-muted bg-gray-100';
}

function dateText(date) {
    if (!date) return 'N/A';
    return new Date(date).toLocaleString();
}

export default function AdminPage() {
    const [email, setEmail] = useState('admin@genuinesugarmummies.com');
    const [password, setPassword] = useState('');
    const [token, setToken] = useState('');
    const [activeTab, setActiveTab] = useState('users');
    const [data, setData] = useState({ users: [], messages: [], gifts: [], packageRequests: [], tickets: [], broadcasts: [], logs: [], callRequests: [], emailOutbox: [], notifications: [], ticketResponses: [], limits: [], stats: {}, tableErrors: {} });
    const [error, setError] = useState('');
    const [notice, setNotice] = useState('');
    const [loading, setLoading] = useState(false);
    const [broadcast, setBroadcast] = useState({ title: '', body: '', targetSegment: 'all' });
    const [ticket, setTicket] = useState({ subject: '', body: '', priority: 'normal' });
    const [ticketReplies, setTicketReplies] = useState({});
    const [emailForms, setEmailForms] = useState({});
    const [testEmail, setTestEmail] = useState('principlessmart@gmail.com');
    const [limits, setLimits] = useState({ dailyMessageLimit: 30, dailyGiftLimit: 20, maxPhotosPerUser: 6, requireManualVerification: true, adsEnabled: false });

    useEffect(() => {
        const saved = localStorage.getItem('gs_admin_token');
        if (saved) setToken(saved);
    }, []);

    useEffect(() => {
        if (token) loadAdmin();
    }, [token]);

    const stats = data.stats || {};
    const pendingUsers = useMemo(() => (data.users || []).filter((user) => !user.admin_approved || user.verification_status === 'pending_admin'), [data.users]);
    const verificationRequests = useMemo(() => data.verificationRequests || pendingUsers.filter((user) => user.verification_selfie_url || user.verification_document_url), [data.verificationRequests, pendingUsers]);

    async function login(event) {
        event.preventDefault();
        setError('');
        const res = await fetch('/api/admin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'login', email, password }),
        });
        const body = await res.json();
        if (!res.ok) { setError(body.error || 'Login failed'); return; }
        localStorage.setItem('gs_admin_token', body.token);
        setToken(body.token);
    }

    async function loadAdmin() {
        setLoading(true);
        setError('');
        const res = await fetch('/api/admin', { headers: { 'x-admin-token': token } });
        const body = await res.json().catch(() => ({}));
        setLoading(false);
        if (!res.ok) { setError(body.error || 'Could not load admin data'); return; }
        setData(body);
        const firstLimit = body.limits?.[0];
        if (firstLimit) {
            setLimits({
                dailyMessageLimit: firstLimit.daily_message_limit || 30,
                dailyGiftLimit: firstLimit.daily_gift_limit || 20,
                maxPhotosPerUser: firstLimit.max_photos_per_user || 6,
                requireManualVerification: firstLimit.require_manual_verification !== false,
                adsEnabled: Boolean(firstLimit.ads_enabled),
            });
        }
    }

    async function adminAction(payload, success = 'Saved.') {
        setError('');
        setNotice('');
        const res = await fetch('/api/admin', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-admin-token': token },
            body: JSON.stringify(payload),
        });
        const body = await res.json().catch(() => ({}));
        if (!res.ok) { setError(body.error || 'Action failed. Run the admin SQL if this table is missing.'); return false; }
        setNotice(success);
        await loadAdmin();
        return true;
    }

    if (!token) {
        return (
            <main className="min-h-dvh flex items-center justify-center px-5" style={{ background: 'linear-gradient(180deg,#f5f3ff,#fff)' }}>
                <form onSubmit={login} className="w-full max-w-sm rounded-2xl p-5 space-y-4" style={{ background: 'white', border: '1px solid rgba(124,58,237,.15)' }}>
                    <Logo size={48} />
                    <h1 className="text-xl font-black text-text-primary">Admin Login</h1>
                    <input className="w-full rounded-xl px-3 py-3" style={{ border: '1px solid #ddd' }} value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
                    <input className="w-full rounded-xl px-3 py-3" style={{ border: '1px solid #ddd' }} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" type="password" />
                    {error && <p className="text-sm text-danger">{error}</p>}
                    <button className="w-full rounded-xl py-3 text-white font-bold gradient-primary">Login</button>
                </form>
            </main>
        );
    }

    return (
        <main className="min-h-dvh bg-bg-dark px-4 py-4 space-y-4 max-w-7xl mx-auto">
            <header className="flex flex-wrap items-center justify-between gap-3 rounded-2xl p-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                <div className="flex items-center gap-3"><Logo size={42} /><div><h1 className="text-xl font-black text-text-primary">Admin Control Panel</h1><p className="text-xs text-text-muted">Users, verification, finance, messages, analytics, tickets, ads and limits.</p></div></div>
                <div className="flex items-center gap-2">
                    <button onClick={loadAdmin} className="px-3 py-2 rounded-xl text-sm font-bold bg-primary/10 text-primary flex items-center gap-2"><RefreshCw size={15} /> Refresh</button>
                    <button onClick={() => { localStorage.removeItem('gs_admin_token'); setToken(''); }} className="px-3 py-2 rounded-xl text-sm font-bold bg-gray-100">Logout</button>
                </div>
            </header>

            <section className="grid grid-cols-2 md:grid-cols-4 xl:grid-cols-8 gap-2">
                {[
                    ['Users', stats.totalUsers || 0], ['Pending', stats.pendingVerification || 0], ['Paid', stats.paidUsers || 0], ['Online', stats.onlineUsers || 0],
                    ['Offline', stats.offlineUsers || 0], ['Banned', stats.bannedUsers || 0], ['Male', stats.maleUsers || 0], ['Female', stats.femaleUsers || 0], ['Unread', stats.unreadMessages || 0], ['Calls', stats.pendingCallRequests || 0],
                ].map(([label, value]) => <div key={label} className="rounded-2xl p-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><p className="text-[11px] font-bold text-text-muted">{label}</p><p className="text-xl font-black text-primary">{value}</p></div>)}
            </section>

            <nav className="flex gap-2 overflow-x-auto pb-1">
                {TABS.map((tab) => {
                    const Icon = tab.icon;
                    return <button key={tab.id} onClick={() => setActiveTab(tab.id)} className={`shrink-0 rounded-xl px-3 py-2 text-xs font-black flex items-center gap-2 ${activeTab === tab.id ? 'gradient-primary text-white' : 'bg-white text-text-secondary'}`}><Icon size={15} /> {tab.label}</button>;
                })}
            </nav>

            {error && <div className="rounded-xl p-3 text-sm text-danger bg-danger/10">{error}</div>}
            {notice && <div className="rounded-xl p-3 text-sm text-success bg-success/10">{notice}</div>}
            {loading && <p className="text-sm text-primary font-bold">Loading...</p>}
            {Object.values(data.tableErrors || {}).filter(Boolean).length > 0 && <div className="rounded-xl p-3 text-xs text-gold bg-amber-100">Some admin tables are missing. Run <b>supabase/migrations/20260625_040_admin_control_packages_verification.sql</b> in Supabase SQL Editor.</div>}

            {activeTab === 'users' && (
                <section className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
                    {(data.users || []).map((user) => (
                        <article key={user.id} className="rounded-2xl p-3 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            <div className="flex gap-3">
                                {user.avatar_url ? <img src={user.avatar_url} alt="" className="w-16 h-16 rounded-xl object-cover" /> : <div className="w-16 h-16 rounded-xl bg-gray-100" />}
                                <div className="min-w-0 flex-1">
                                    <p className="font-black truncate">{user.display_name || user.email}</p>
                                    <p className="text-xs text-text-muted truncate">{user.email}</p>
                                    <p className="text-xs text-text-muted truncate">{user.profile_label || user.member_category || 'member'} - {user.phone_number || user.phone || 'no phone'}</p>
                                    <div className="flex flex-wrap gap-1 mt-1">
                                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${statusColor(user)}`}>{user.verification_status || 'new'}</span>
                                        <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-primary/10 text-primary">{tierText(user.subscription_tier)}</span>
                                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${user.show_in_public ? 'bg-success/10 text-success' : 'bg-gray-100 text-text-muted'}`}>{user.show_in_public ? 'PUBLIC' : 'HIDDEN'}</span>
                                        {user.package_locked && <span className="px-2 py-0.5 rounded-full text-[10px] font-black bg-danger/10 text-danger">PACKAGE LOCKED</span>}
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-2">
                                <button onClick={() => adminAction({ action: 'approve_user', userId: user.id, subscriptionTier: user.subscription_tier || 'basic' }, 'User verified and approved')} className="rounded-xl py-2 text-xs font-black text-white bg-success flex items-center justify-center gap-1"><Check size={13} /> Verify</button>
                                <button onClick={() => adminAction({ action: user.verified ? 'revoke_verification' : 'reject_verification', userId: user.id, reason: 'Rejected by admin.' }, user.verified ? 'Verification revoked' : 'Verification rejected')} className="rounded-xl py-2 text-xs font-black text-white bg-danger flex items-center justify-center gap-1"><X size={13} /> {user.verified ? 'Revoke' : 'Reject'}</button>
                                <button onClick={() => adminAction({ action: user.show_in_public ? 'hide_user' : 'show_user', userId: user.id }, user.show_in_public ? 'User hidden' : 'User shown')} className="rounded-xl py-2 text-xs font-black bg-primary/10 text-primary">{user.show_in_public ? 'Hide Profile' : 'Show Public'}</button>
                                <button onClick={() => adminAction({ action: user.package_locked ? 'unlock_package' : 'lock_package', userId: user.id }, user.package_locked ? 'Package unlocked' : 'Package locked')} className="rounded-xl py-2 text-xs font-black bg-amber-100 text-gold flex items-center justify-center gap-1">{user.package_locked ? <Unlock size={13} /> : <Lock size={13} />} Package</button>
                            </div>

                            <div className="grid grid-cols-4 gap-1.5">
                                {TIERS.map((tier) => <button key={tier} onClick={() => adminAction({ action: 'set_package', userId: user.id, tier, locked: tier === 'free' }, `${tier} package set`)} className={`px-2 py-2 rounded-lg text-[10px] font-black ${String(user.subscription_tier || 'free') === tier ? 'gradient-primary text-white' : 'bg-gray-100 text-text-secondary'}`}>{tier}</button>)}
                            </div>

                            <div className="grid grid-cols-2 gap-2">
                                <button onClick={() => adminAction({ action: user.is_suspended || user.is_banned ? 'restore_user' : 'suspend_user', userId: user.id }, user.is_suspended || user.is_banned ? 'User restored' : 'User suspended')} className="rounded-xl py-2 text-xs font-black bg-gray-900 text-white">{user.is_suspended || user.is_banned ? 'Restore Account' : 'Suspend Account'}</button>
                                <button onClick={() => adminAction({ action: user.is_banned ? 'unban_user' : 'ban_user', userId: user.id }, user.is_banned ? 'User unbanned' : 'User banned')} className="rounded-xl py-2 text-xs font-black bg-danger/10 text-danger">{user.is_banned ? 'Unban User' : 'Ban User'}</button>
                            </div>

                            <div className="rounded-xl p-2 space-y-2 bg-surface">
                                <input value={emailForms[user.id]?.subject || ''} onChange={(e) => setEmailForms({ ...emailForms, [user.id]: { ...(emailForms[user.id] || {}), subject: e.target.value } })} placeholder="Email subject" className="w-full rounded-lg p-2 text-xs bg-white" />
                                <textarea value={emailForms[user.id]?.message || ''} onChange={(e) => setEmailForms({ ...emailForms, [user.id]: { ...(emailForms[user.id] || {}), message: e.target.value } })} placeholder="Message to user account and email" className="w-full rounded-lg p-2 text-xs bg-white resize-none" rows={2} />
                                <button onClick={() => adminAction({ action: 'email_user', userId: user.id, subject: emailForms[user.id]?.subject || 'Message from Genuine Sugar Mummies', message: emailForms[user.id]?.message || 'Admin sent you a message.' }, 'Email and account message sent')} className="w-full rounded-lg py-2 text-xs font-black bg-sky-100 text-sky-700">Email User + Inbox</button>
                            </div>
                        </article>
                    ))}
                </section>
            )}
            {activeTab === 'seed' && <Panel title="Seed Management" items={[`Seeded profiles: ${(data.users || []).filter((u) => u.email?.startsWith('seed+')).length}`, `Public profiles: ${(data.users || []).filter((u) => u.show_in_public).length}`, `Sugar mummies: ${(data.users || []).filter((u) => u.profile_label === 'sugar_mummy').length}`, `Sugar daddies: ${(data.users || []).filter((u) => u.profile_label === 'sugar_daddy').length}`, `Mistresses: ${(data.users || []).filter((u) => u.profile_label === 'mistress').length}`]} />}

            {activeTab === 'verification' && (
                <section className="grid gap-3 md:grid-cols-2">
                    {verificationRequests.map((user) => (
                        <article key={user.id} className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>
                            <div className="flex items-center justify-between gap-3"><div><h2 className="font-black">{user.display_name || user.email}</h2><p className="text-xs text-text-muted">{user.verification_phone || user.phone_number || user.phone || 'No phone'}</p></div><span className="text-xs font-black text-primary bg-primary/10 rounded-full px-2 py-1">{user.verification_document_type || 'document'}</span></div>
                            <div className="grid grid-cols-2 gap-2">{user.verification_selfie_url && <img src={user.verification_selfie_url} alt="Selfie" className="w-full aspect-square object-cover rounded-xl" />}{user.verification_document_url && <img src={user.verification_document_url} alt="Document" className="w-full aspect-square object-cover rounded-xl" />}</div>
                            <div className="flex gap-2"><button onClick={() => adminAction({ action: 'approve_user', userId: user.id, subscriptionTier: user.subscription_tier || 'basic' }, 'Verification approved')} className="flex-1 rounded-xl py-2 text-xs font-black text-white bg-success flex items-center justify-center gap-1"><Check size={14} /> Approve</button><button onClick={() => adminAction({ action: 'reject_verification', userId: user.id, reason: 'Please upload clearer verification documents.' }, 'Verification rejected')} className="flex-1 rounded-xl py-2 text-xs font-black text-white bg-danger flex items-center justify-center gap-1"><X size={14} /> Reject</button></div>
                        </article>
                    ))}
                </section>
            )}

            {activeTab === 'finance' && (
                <section className="space-y-3">
                    {(data.packageRequests || []).map((request) => <article key={request.id} className="rounded-2xl p-4 flex flex-wrap items-center justify-between gap-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><div><h2 className="font-black">{request.display_name || request.email}</h2><p className="text-xs text-text-muted">{tierText(request.tier)} - KSh {request.amount_ksh} - {request.status}</p><p className="text-xs text-text-muted">Ref: {request.payment_reference || 'N/A'}</p></div><div className="flex gap-2"><button onClick={() => adminAction({ action: 'approve_package_request', requestId: request.id, userId: request.user_id, tier: request.tier }, 'Package approved')} className="px-3 py-2 rounded-xl text-xs font-black text-white bg-success">Approve</button><button onClick={() => adminAction({ action: 'reject_package_request', requestId: request.id }, 'Package rejected')} className="px-3 py-2 rounded-xl text-xs font-black text-white bg-danger">Reject</button></div></article>)}
                </section>
            )}

            {activeTab === 'analytics' && <Panel title="Analytics" items={[`Profile views: ${(data.users || []).reduce((sum, user) => sum + (user.total_profile_views || 0), 0)}`, `Followers: ${(data.users || []).reduce((sum, user) => sum + (user.followers_count || 0), 0)}`, `Gifts sent: ${(data.gifts || []).length}`, `Saved messages: ${(data.messages || []).length}`, `Pending package requests: ${stats.pendingPackageRequests || 0}`]} />}

            {activeTab === 'tickets' && <ActionList title="Tickets" items={data.tickets || []} empty="No tickets yet." render={(item) => <><h2 className="font-black">{item.subject}</h2><p className="text-sm text-text-secondary">{item.body}</p><p className="text-xs text-text-muted">{item.status} - {dateText(item.created_at)}</p><div className="mt-3 space-y-2"><textarea value={ticketReplies[item.id] || ''} onChange={(e) => setTicketReplies({ ...ticketReplies, [item.id]: e.target.value })} placeholder="Reply to this user" className="w-full rounded-xl p-3 text-sm bg-surface resize-none" rows={2} /><div className="flex gap-2"><button onClick={() => adminAction({ action: 'respond_ticket', ticketId: item.id, message: ticketReplies[item.id] || '' }, 'Ticket response sent to account and email queue')} className="px-3 py-2 rounded-xl text-xs font-black text-white gradient-primary">Respond</button>{item.status !== 'closed' && <button onClick={() => adminAction({ action: 'close_ticket', ticketId: item.id }, 'Ticket closed')} className="px-3 py-2 rounded-xl text-xs font-black bg-gray-100">Close</button>}</div></div></>} footer={<div className="rounded-2xl p-4 space-y-2" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><input value={ticket.subject} onChange={(e) => setTicket({ ...ticket, subject: e.target.value })} placeholder="Ticket subject" className="w-full rounded-xl p-3 text-sm bg-surface" /><textarea value={ticket.body} onChange={(e) => setTicket({ ...ticket, body: e.target.value })} placeholder="Ticket note" className="w-full rounded-xl p-3 text-sm bg-surface" /><button onClick={() => adminAction({ action: 'create_ticket', ...ticket }, 'Ticket created')} className="rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary">Create Ticket</button></div>} />}
            {activeTab === 'broadcast' && <ActionList title="Broadcasts" items={data.broadcasts || []} empty="No broadcasts yet." render={(item) => <><h2 className="font-black">{item.title}</h2><p className="text-sm text-text-secondary">{item.body}</p><p className="text-xs text-text-muted">{item.target_segment} - {dateText(item.created_at)}</p></>} footer={<div className="rounded-2xl p-4 space-y-3" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><input value={broadcast.title} onChange={(e) => setBroadcast({ ...broadcast, title: e.target.value })} placeholder="Broadcast title" className="w-full rounded-xl p-3 text-sm bg-surface" /><textarea value={broadcast.body} onChange={(e) => setBroadcast({ ...broadcast, body: e.target.value })} placeholder="Message to users and email inboxes" className="w-full rounded-xl p-3 text-sm bg-surface" /><select value={broadcast.targetSegment} onChange={(e) => setBroadcast({ ...broadcast, targetSegment: e.target.value })} className="w-full rounded-xl p-3 text-sm bg-surface"><option value="all">All users</option><option value="free">Free users</option><option value="basic">Basic users</option><option value="silver">Silver users</option><option value="gold">Gold users</option><option value="sugar_mummy">Sugar mummies</option><option value="sugar_daddy">Sugar daddies</option><option value="mistress">Mistresses</option><option value="toyboy">Toyboys</option></select><div className="flex flex-wrap gap-2"><button onClick={() => adminAction({ action: 'create_broadcast', ...broadcast }, 'Broadcast sent to accounts and emails')} className="rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary">Send Broadcast</button><button onClick={() => adminAction({ action: 'send_subscription_reminders' }, 'Subscription reminders sent')} className="rounded-xl px-4 py-2 text-xs font-black bg-amber-100 text-gold">Send Subscription Reminders</button></div><div className="flex gap-2"><input value={testEmail} onChange={(e) => setTestEmail(e.target.value)} placeholder="Test email" className="min-w-0 flex-1 rounded-xl p-3 text-sm bg-surface" /><button onClick={() => adminAction({ action: 'test_email', to: testEmail }, 'Test email sent')} className="rounded-xl px-4 py-2 text-xs font-black bg-sky-100 text-sky-700">Send Test</button></div></div>} />}

            {activeTab === 'limits' && <section className="rounded-2xl p-4 space-y-3 max-w-xl" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="font-black">Ads & Limits</h2>{[['dailyMessageLimit', 'Daily messages'], ['dailyGiftLimit', 'Daily gifts'], ['maxPhotosPerUser', 'Max photos']].map(([key, label]) => <label key={key} className="block text-xs font-bold text-text-muted">{label}<input type="number" value={limits[key]} onChange={(e) => setLimits({ ...limits, [key]: e.target.value })} className="mt-1 w-full rounded-xl p-3 text-sm bg-surface text-text-primary" /></label>)}<label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={limits.requireManualVerification} onChange={(e) => setLimits({ ...limits, requireManualVerification: e.target.checked })} /> Require manual verification</label><label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={limits.adsEnabled} onChange={(e) => setLimits({ ...limits, adsEnabled: e.target.checked })} /> Ads enabled</label><button onClick={() => adminAction({ action: 'update_limits', ...limits }, 'Limits updated')} className="rounded-xl px-4 py-2 text-xs font-black text-white gradient-primary">Save Limits</button></section>}

            {activeTab === 'logs' && <ActionList title="Logs, Messages & Gifts" items={[...(data.messages || []).map((m) => ({ ...m, type: 'message' })), ...(data.gifts || []).map((g) => ({ ...g, type: 'gift' })), ...(data.callRequests || []).map((c) => ({ ...c, type: 'call' })), ...(data.emailOutbox || []).map((e) => ({ ...e, type: 'email' })), ...(data.notifications || []).map((n) => ({ ...n, type: 'account message' })), ...(data.logs || []).map((l) => ({ ...l, type: 'log' }))]} empty="No logs yet." render={(item) => <><p className="text-xs font-black text-primary">{item.type}</p><p className="text-sm text-text-primary">{item.body || item.gift_name || item.action || `${item.call_type || ''} call request`}</p><p className="text-xs text-text-muted">{item.sender_name || item.requester_name || item.to_email || item.sender_key || item.requester_key || ''} {dateText(item.created_at)}</p></>} />}
        </main>
    );
}

function Panel({ title, items }) {
    return <section className="rounded-2xl p-4 space-y-3 max-w-xl" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}><h2 className="font-black">{title}</h2>{items.map((item) => <p key={item} className="text-sm text-text-secondary flex items-center gap-2"><Eye size={14} className="text-primary" /> {item}</p>)}</section>;
}

function ActionList({ title, items, empty, render, footer }) {
    return <section className="space-y-3"><div className="flex items-center gap-2"><Mail size={17} className="text-primary" /><h2 className="font-black">{title}</h2></div>{footer}{items.length === 0 && <p className="text-sm text-text-muted">{empty}</p>}<div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">{items.map((item) => <article key={`${item.type || 'item'}-${item.id}`} className="rounded-2xl p-4" style={{ background: 'var(--color-bg-card)', border: 'var(--card-border)' }}>{render(item)}</article>)}</div></section>;
}






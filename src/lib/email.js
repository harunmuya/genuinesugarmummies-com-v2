const DEFAULT_FROM = process.env.RESEND_FROM_EMAIL || 'Genuine Sugar Mummies <onboarding@resend.dev>';

function escapeHtml(value = '') {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function textToHtml(text = '') {
    return `<p>${escapeHtml(text).replace(/\n/g, '<br />')}</p>`;
}

export async function sendEmail({ to, subject, html, text, from = DEFAULT_FROM }) {
    const apiKey = process.env.RESEND_API_KEY;
    const toEmail = String(to || '').trim();
    const cleanSubject = String(subject || '').trim();
    const bodyHtml = html || textToHtml(text || '');

    if (!apiKey) return { ok: false, skipped: true, error: 'RESEND_API_KEY is not configured.' };
    if (!toEmail || !toEmail.includes('@')) return { ok: false, error: 'Valid recipient email is required.' };
    if (!cleanSubject) return { ok: false, error: 'Email subject is required.' };

    try {
        const response = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ from, to: toEmail, subject: cleanSubject, html: bodyHtml }),
        });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) return { ok: false, status: response.status, error: data.message || data.error || 'Resend email failed.', data };
        return { ok: true, data };
    } catch (error) {
        return { ok: false, error: error.message || 'Resend email failed.' };
    }
}

export async function sendAndLogEmail(supabase, payload) {
    const message = {
        to: payload.to || payload.to_email,
        subject: payload.subject,
        html: payload.html,
        text: payload.text || payload.body,
        from: payload.from,
    };
    let outboxId = payload.outboxId || null;

    if (supabase && !outboxId) {
        try {
            const { data } = await supabase.from('email_outbox').insert({
                to_email: message.to,
                subject: message.subject,
                body: message.html || message.text || '',
                status: 'queued',
            }).select('id').maybeSingle();
            outboxId = data?.id || null;
        } catch {}
    }

    const result = await sendEmail(message);

    if (supabase && outboxId) {
        try {
            await supabase.from('email_outbox').update({
                status: result.ok ? 'sent' : (result.skipped ? 'queued' : 'failed'),
                provider_response: JSON.stringify(result.data || result.error || result).slice(0, 2000),
                sent_at: result.ok ? new Date().toISOString() : null,
            }).eq('id', outboxId);
        } catch {}
    }

    return { ...result, outboxId };
}

export function emailHtml(title, body) {
    return `
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111827;max-width:620px;margin:0 auto;padding:24px">
            <h1 style="font-size:22px;margin:0 0 12px;color:#0f766e">${escapeHtml(title)}</h1>
            <div style="font-size:15px">${textToHtml(body)}</div>
            <p style="font-size:12px;color:#6b7280;margin-top:24px">Genuine Sugar Mummies Admin</p>
        </div>
    `;
}
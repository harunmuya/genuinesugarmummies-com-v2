const DEFAULT_FROM = process.env.RESEND_FROM_EMAIL || 'Genuine Sugar Mummies <feedback@genuinesugarmummies.com>';
const BRAND_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://genuinesugarmummies.com';
const PUBLIC_ASSET_URL = process.env.NEXT_PUBLIC_ASSET_URL || 'https://genuinesugarmummies-com-v2.vercel.app';
const LOGO_URL = process.env.EMAIL_LOGO_URL || `${PUBLIC_ASSET_URL.replace(/\/$/, '')}/gs-logo.png`;

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

function looksLikeHtml(value = '') {
    return /<\/?[a-z][\s\S]*>/i.test(String(value || ''));
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

export function emailHtml(title, body, options = {}) {
    const safeTitle = escapeHtml(title || 'Genuine Sugar Mummies');
    const content = looksLikeHtml(body) ? String(body) : textToHtml(body || '');
    const preview = escapeHtml(options.preview || title || 'Genuine Sugar Mummies update');
    const action = options.actionUrl && options.actionLabel
        ? `<a href="${escapeHtml(options.actionUrl)}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:800;border-radius:14px;padding:13px 18px;margin-top:8px">${escapeHtml(options.actionLabel)}</a>`
        : '';

    return `
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${preview}</div>
        <div style="margin:0;padding:0;background:#f4fbf9;font-family:Arial,Helvetica,sans-serif;color:#111827">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4fbf9;padding:26px 12px">
                <tr>
                    <td align="center">
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;background:#ffffff;border:1px solid #dbeafe;border-radius:22px;overflow:hidden;box-shadow:0 14px 40px rgba(15,118,110,0.12)">
                            <tr>
                                <td style="padding:24px 24px 14px;background:linear-gradient(135deg,#ecfeff,#fff7ed)">
                                    <img src="${escapeHtml(LOGO_URL)}" alt="Genuine Sugar Mummies" width="92" style="display:block;width:92px;height:auto;margin:0 auto 12px" />
                                    <h1 style="font-size:24px;line-height:1.2;margin:0;text-align:center;color:#0f172a;font-weight:900">${safeTitle}</h1>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:24px;font-size:15px;line-height:1.65;color:#1f2937">
                                    ${content}
                                    ${action}
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:18px 24px;background:#0f766e;color:#ffffff;text-align:center;font-size:12px;line-height:1.5">
                                    Genuine Sugar Mummies<br />Secure account updates, support messages, and package notifications.
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </div>
    `;
}




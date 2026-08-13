const DEFAULT_FROM = process.env.RESEND_FROM_EMAIL || 'Genuine Sugar Mummies <feedback@genuinesugarmummies.com>';
const BRAND_URL = process.env.NEXT_PUBLIC_APP_URL || 'https://genuinesugarmummies.com';
const PUBLIC_ASSET_URL = process.env.NEXT_PUBLIC_ASSET_URL || 'https://genuinesugarmummies-com-v2.vercel.app';
const LOGO_URL = process.env.EMAIL_LOGO_URL || `${PUBLIC_ASSET_URL.replace(/\/$/, '')}/gs-logo.png`;
const APP_URL = (process.env.NEXT_PUBLIC_APP_URL || PUBLIC_ASSET_URL || BRAND_URL).replace(/\/$/, '');

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

export function appLink(path = '/') {
    const value = String(path || '/').trim();
    if (/^https?:\/\//i.test(value)) return value;
    return `${APP_URL}${value.startsWith('/') ? value : `/${value}`}`;
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
    const safeAccountName = escapeHtml(options.accountName || options.userName || 'GS Member');
    const safeAccountEmail = escapeHtml(options.accountEmail || '');
    const safeBadge = escapeHtml(options.badge || 'Official account notice');
    const safeOnlineName = escapeHtml(options.onlineName || options.hostName || '');
    const action = options.actionUrl && options.actionLabel
        ? `<a href="${escapeHtml(appLink(options.actionUrl))}" style="display:inline-block;background:#0f766e;color:#ffffff;text-decoration:none;font-weight:900;border-radius:14px;padding:13px 18px;margin-top:10px;box-shadow:0 10px 24px rgba(15,118,110,.22)">${escapeHtml(options.actionLabel)}</a>`
        : '';
    const secondaryAction = options.secondaryActionUrl && options.secondaryActionLabel
        ? `<a href="${escapeHtml(appLink(options.secondaryActionUrl))}" style="display:inline-block;color:#0f766e;text-decoration:none;font-weight:800;margin-left:12px;margin-top:10px">${escapeHtml(options.secondaryActionLabel)}</a>`
        : '';
    const accountBlock = options.accountName || options.accountEmail || options.onlineName
        ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:0 0 18px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px">
                <tr>
                    <td style="padding:14px 16px">
                        <p style="margin:0 0 6px;color:#64748b;font-size:11px;font-weight:900;text-transform:uppercase;letter-spacing:.08em">${safeBadge}</p>
                        <p style="margin:0;color:#0f172a;font-size:15px;font-weight:900">Account: ${safeAccountName}</p>
                        ${safeAccountEmail ? `<p style="margin:4px 0 0;color:#64748b;font-size:12px">${safeAccountEmail}</p>` : ''}
                        ${safeOnlineName ? `<p style="margin:10px 0 0;color:#0f766e;font-size:13px;font-weight:900">Online now: ${safeOnlineName}</p>` : ''}
                    </td>
                </tr>
            </table>`
        : '';
    const metaRows = Array.isArray(options.metaRows) && options.metaRows.length
        ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:16px 0;background:#ffffff;border:1px solid #e5e7eb;border-radius:14px;overflow:hidden">
                ${options.metaRows.map((row) => `<tr><td style="padding:10px 12px;border-bottom:1px solid #eef2f7;color:#64748b;font-size:12px;font-weight:800;width:38%">${escapeHtml(row.label)}</td><td style="padding:10px 12px;border-bottom:1px solid #eef2f7;color:#0f172a;font-size:12px;font-weight:900">${escapeHtml(row.value)}</td></tr>`).join('')}
            </table>`
        : '';

    return `
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${preview}</div>
        <div style="margin:0;padding:0;background:#eef8f6;font-family:Arial,Helvetica,sans-serif;color:#111827">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#eef8f6;padding:28px 12px">
                <tr>
                    <td align="center">
                        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border:1px solid #dbeafe;border-radius:22px;overflow:hidden;box-shadow:0 18px 48px rgba(15,118,110,0.16)">
                            <tr>
                                <td style="padding:26px 24px 18px;background:linear-gradient(135deg,#042f2e,#0f766e 58%,#f59e0b);color:#ffffff">
                                    <img src="${escapeHtml(LOGO_URL)}" alt="Genuine Sugar Mummies" width="92" style="display:block;width:92px;height:auto;margin:0 auto 12px" />
                                    <p style="margin:0 0 7px;text-align:center;color:#ccfbf1;font-size:11px;font-weight:900;text-transform:uppercase;letter-spacing:.12em">Genuine Sugar Mummies</p>
                                    <h1 style="font-size:25px;line-height:1.2;margin:0;text-align:center;color:#ffffff;font-weight:900">${safeTitle}</h1>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:24px;font-size:15px;line-height:1.65;color:#1f2937">
                                    ${accountBlock}
                                    ${content}
                                    ${metaRows}
                                    ${action}${secondaryAction}
                                    <p style="margin:18px 0 0;color:#64748b;font-size:12px;line-height:1.55">This is an official GS account message. For your safety, use the button above to open the app and never send money or documents outside official GS support routes.</p>
                                </td>
                            </tr>
                            <tr>
                                <td style="padding:18px 24px;background:#0f172a;color:#ffffff;text-align:center;font-size:12px;line-height:1.5">
                                    Genuine Sugar Mummies<br />Secure account updates, live alerts, support messages, and package notifications.<br />
                                    <a href="${escapeHtml(appLink('/safety'))}" style="color:#99f6e4;text-decoration:none;font-weight:800">Safety</a>
                                    &nbsp;•&nbsp;
                                    <a href="${escapeHtml(appLink('/terms'))}" style="color:#99f6e4;text-decoration:none;font-weight:800">Terms</a>
                                    &nbsp;•&nbsp;
                                    <a href="${escapeHtml(appLink('/contact'))}" style="color:#99f6e4;text-decoration:none;font-weight:800">Contact</a>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
            </table>
        </div>
    `;
}




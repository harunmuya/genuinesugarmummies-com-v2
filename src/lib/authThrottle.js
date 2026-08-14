/**
 * Slow down repeated authentication attempts.
 *
 * Nothing limited them. Login took unlimited password guesses against any
 * address, and password reset was worse: the code is six digits, so 900,000
 * possibilities, and reset_password checked as many guesses as were sent.
 *
 * That is account takeover against any email on the platform. Request a reset
 * for the address, then walk the code space; at a hundred requests a second it
 * averages about seventy five minutes, and nothing would have slowed down or
 * noticed.
 *
 * Attempts are counted per address rather than per IP. An attacker changes IP
 * trivially, and blocking one would take out everybody behind a shared mobile
 * connection, which here is most people.
 *
 * A successful attempt clears the count, so somebody who mistypes their
 * password four times and then gets it right is not left locked out.
 */

/** How many failures are allowed, and over what window, per kind of attempt. */
export const THROTTLES = {
    /*
      Generous, because people genuinely forget which password they used and a
      wrong guess here costs an attacker one of 10^n, not one of 900,000.
    */
    login: { max: 10, windowMs: 15 * 60 * 1000, lockMs: 15 * 60 * 1000 },

    /*
      Tight, because the search space is small and known. Five wrong codes in
      an hour is nothing like normal use: the code is in an email in front of
      them, and getting it wrong five times means it is not their code.
    */
    reset: { max: 5, windowMs: 60 * 60 * 1000, lockMs: 60 * 60 * 1000 },

    /*
      How often a reset code can be requested at all. Without this, an attacker
      keeps issuing fresh codes to widen the pool of valid ones, and the owner
      of the address is buried in email.
    */
    resetRequest: { max: 5, windowMs: 60 * 60 * 1000, lockMs: 60 * 60 * 1000 },
};

const scopeFor = (kind, identifier) => `${kind}:${String(identifier || '').trim().toLowerCase()}`;

/**
 * Is this address currently locked out?
 *
 * Fails open. If the table is missing, or the database refuses, sign-in still
 * works: a throttle that cannot be read should not lock every member out of
 * their account, which would turn a smaller problem into an outage.
 *
 * @returns {Promise<{ blocked: boolean, retryAfterMs?: number, error?: string }>}
 */
export async function checkThrottle(supabase, kind, identifier) {
    const rule = THROTTLES[kind];
    if (!supabase || !rule || !identifier) return { blocked: false };

    try {
        const since = new Date(Date.now() - rule.windowMs).toISOString();
        const { data, error } = await supabase
            .from('auth_attempts')
            .select('created_at, succeeded')
            .eq('scope', scopeFor(kind, identifier))
            .gte('created_at', since)
            .order('created_at', { ascending: false })
            .limit(rule.max + 1);

        if (error || !data) return { blocked: false };

        /*
          Only failures since the last success count. Getting in correctly is
          proof the account is theirs, and holding earlier fumbles against them
          afterwards is just punishing a bad memory.
        */
        const failures = [];
        for (const row of data) {
            if (row.succeeded) break;
            failures.push(row);
        }
        if (failures.length < rule.max) return { blocked: false };

        const oldest = new Date(failures[failures.length - 1].created_at).getTime();
        const retryAfterMs = Math.max(0, oldest + rule.lockMs - Date.now());
        if (retryAfterMs <= 0) return { blocked: false };

        return {
            blocked: true,
            retryAfterMs,
            error: kind === 'login'
                ? `Too many sign-in attempts. Try again in ${Math.ceil(retryAfterMs / 60000)} minutes.`
                : `Too many attempts. Try again in ${Math.ceil(retryAfterMs / 60000)} minutes.`,
        };
    } catch {
        return { blocked: false };
    }
}

/**
 * Record an attempt.
 *
 * Never throws and never blocks the caller's own result: failing to write an
 * audit row is not a reason to refuse somebody the sign-in they just completed
 * correctly.
 */
export async function recordAttempt(supabase, kind, identifier, succeeded) {
    if (!supabase || !THROTTLES[kind] || !identifier) return;
    try {
        await supabase.from('auth_attempts').insert({
            scope: scopeFor(kind, identifier),
            succeeded: Boolean(succeeded),
        });
    } catch { /* the sign-in already happened */ }
}

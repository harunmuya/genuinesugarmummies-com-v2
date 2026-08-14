/**
 * Work out what a Supabase error actually means before telling anyone about it.
 *
 * The app had two failure messages and used them for everything.
 *
 * The members API set `setupRequired: true` on any error at all, and the admin
 * screen showed "Some admin tables are missing. Run
 * supabase/migrations/20260625_040_..." whenever a table query failed for any
 * reason. Both are the right message for exactly one cause: a database that has
 * not had its migrations run.
 *
 * When this project exceeded its egress quota, Supabase began returning 402 to
 * every request, and the app reported that the schema was missing and named a
 * migration to run. The migration had been run months earlier. Anyone following
 * that instruction would re-run SQL against a healthy database looking for a
 * fault that was not there, while the actual cause — a billing limit — was not
 * mentioned anywhere.
 *
 * A wrong diagnosis costs more than a vague one, so this separates the cases.
 */

/** Postgres and PostgREST codes that genuinely mean "the schema is not there". */
const MISSING_SCHEMA_CODES = new Set([
    '42P01',   // undefined_table
    '42703',   // undefined_column
    'PGRST204', // column not found in schema cache
    'PGRST205', // table not found in schema cache
]);

/**
 * Classify a Supabase error.
 *
 * @returns {{ kind: 'none'|'quota'|'schema'|'unknown', message: string, actionable: string }}
 *   `message` is safe to show a member. `actionable` is for an operator and is
 *   empty when there is nothing useful for them to do.
 */
export function classifySupabaseError(error) {
    if (!error) return { kind: 'none', message: '', actionable: '' };

    const code = String(error.code || '');
    const text = `${error.message || ''} ${error.details || ''} ${error.hint || ''}`.toLowerCase();
    const status = Number(error.status || error.statusCode || 0);

    /*
      Restriction comes back as 402 with a body naming the violation. The
      wording has varied, so this matches on several signals rather than one
      exact string: getting this wrong sends an operator back to the schema
      explanation, which is the failure this file exists to prevent.
    */
    const quota = status === 402
        || text.includes('exceed_egress_quota')
        || text.includes('egress quota')
        || text.includes('quota')
        || text.includes('restricted due to')
        || text.includes('spend cap');

    if (quota) {
        return {
            kind: 'quota',
            message: 'The app is paused while our database plan resets. Nothing has been lost, and your account is safe.',
            actionable: 'Supabase has restricted this project for exceeding its plan quota. '
                + 'Upgrade the plan or wait for the billing period to reset. Running migrations will not help.',
        };
    }

    if (MISSING_SCHEMA_CODES.has(code)) {
        return {
            kind: 'schema',
            message: 'This part of the app is still being set up.',
            actionable: 'A table or column is missing. Run the pending migrations in supabase/migrations.',
        };
    }

    return {
        kind: 'unknown',
        message: 'Something went wrong loading this. Please try again.',
        actionable: error.message || 'Unrecognised database error.',
    };
}

/** True when the schema really is the problem, and a migration is the fix. */
export function isMissingSchema(error) {
    return classifySupabaseError(error).kind === 'schema';
}

/** True when the project is restricted and no code change will help. */
export function isQuotaRestricted(error) {
    return classifySupabaseError(error).kind === 'quota';
}

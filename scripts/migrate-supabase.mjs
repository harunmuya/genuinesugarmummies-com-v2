/**
 * Copy every row from one Supabase project to another.
 *
 * Credentials come from the environment, never from arguments, so they do not
 * end up in shell history or in a screenshot:
 *
 *   OLD_SUPABASE_URL   OLD_SUPABASE_SERVICE_KEY
 *   NEW_SUPABASE_URL   NEW_SUPABASE_SERVICE_KEY
 *
 *   node scripts/migrate-supabase.mjs --dry-run    # count everything, write nothing
 *   node scripts/migrate-supabase.mjs              # copy
 *
 * Both service role keys are required because this reads and writes straight
 * past row level security. Run it, then remove them from your shell.
 *
 * Two things make this harder than a loop over tables.
 *
 * Order. `matches`, `messages` and every *_id column reference users.id, so
 * users has to exist before anything that points at it. TABLES below is in
 * dependency order and must stay that way.
 *
 * Ids. Rows are inserted with their original primary keys. Letting the new
 * project generate fresh ones silently detaches every relationship in the app:
 * matches would point at members who do not exist, conversations would lose
 * their messages, and nothing would report an error.
 *
 * Restartable on purpose. Everything is upserted on the primary key, so a run
 * that dies halfway can simply be run again.
 */
import { createClient } from '@supabase/supabase-js';

const DRY_RUN = process.argv.includes('--dry-run');
const PAGE = 500;

/*
  Dependency order, generated from the migrations by scripts/build-migrate-list.py
  rather than written by hand.

  The hand-written list missed twenty one tables that exist in the schema, and
  named two that do not, which on a migration billed as losing nothing means
  silently leaving data behind. This is a topological sort over the REFERENCES
  in every CREATE TABLE, so a table is always copied after whatever it points
  at.
*/
const TABLES = [
    'users',
    'user_follows',
    'live_streams',
    'live_viewers',
    'live_comments',
    'live_gifts',
    'direct_conversations',
    'direct_messages',
    'notifications',
    'profile_views',
    'member_likes',
    'gifts',
    'sent_gifts',
    'token_transactions',
    'token_packages',
    'typing_indicators',
    'admin_users',
    'admin_audit_log',
    'auto_messages',
    'email_queue',
    'user_badges',
    'user_settings',
    'user_notifications',
    'conversations',
    'messages',
    'message_attachments',
    'voice_notes',
    'call_sessions',
    'call_signals',
    'gift_catalog',
    'gift_wallet',
    'gift_transactions',
    'money_wallet',
    'credit_wallet',
    'wallet_transactions',
    'push_subscriptions',
    'package_tiers',
    'package_requests',
    'member_messages',
    'member_gifts',
    'member_saves',
    'call_requests',
    'support_tickets',
    'ticket_responses',
    'user_interactions',
    'user_daily_usage',
    'app_limits',
    'admin_logs',
    'member_follows',
    'packages',
    'user_subscriptions',
    'likes',
    'super_likes',
    'swipes',
    'saved_profiles',
    'matches',
    'ticket_messages',
    'call_events',
    'user_gift_inventory',
    'email_outbox',
    'broadcasts',
    'password_reset_codes',
    'member_swipes',
    'ad_slots',
];

function need(name) {
    const value = process.env[name];
    if (!value) {
        console.error(`\n  ${name} is not set.\n`);
        console.error('  Set all four, then run again:');
        console.error('    OLD_SUPABASE_URL  OLD_SUPABASE_SERVICE_KEY');
        console.error('    NEW_SUPABASE_URL  NEW_SUPABASE_SERVICE_KEY\n');
        process.exit(1);
    }
    return value;
}

const from = createClient(need('OLD_SUPABASE_URL'), need('OLD_SUPABASE_SERVICE_KEY'), {
    auth: { persistSession: false },
});
const to = createClient(need('NEW_SUPABASE_URL'), need('NEW_SUPABASE_SERVICE_KEY'), {
    auth: { persistSession: false },
});

/** Read one table in pages. Returns null when the table is absent. */
async function readAll(table) {
    const rows = [];
    for (let offset = 0; ; offset += PAGE) {
        const { data, error } = await from
            .from(table)
            .select('*')
            .range(offset, offset + PAGE - 1);

        if (error) {
            // Absent in the source is normal: the schema grew over time.
            if (['42P01', 'PGRST205'].includes(error.code)) return null;
            /*
              402 means the source project is still restricted. Say so plainly
              rather than reporting an empty table, which would look like a
              successful migration of nothing.
            */
            if (/restricted|quota|exceed_egress/i.test(error.message || '')) {
                throw new Error(
                    'The source project is restricted and will not return data. '
                    + 'Wait for the billing period to reset, or upgrade it, then run this again.');
            }
            throw new Error(`${table}: ${error.message}`);
        }

        rows.push(...(data || []));
        if (!data || data.length < PAGE) return rows;
    }
}

async function writeAll(table, rows) {
    let written = 0;
    for (let i = 0; i < rows.length; i += PAGE) {
        const batch = rows.slice(i, i + PAGE);
        // Upsert on the primary key: original ids are preserved, and a rerun
        // after a failure does not duplicate anything.
        const { error } = await to.from(table).upsert(batch, { onConflict: 'id' });
        if (error) throw new Error(`${table}: ${error.message}`);
        written += batch.length;
    }
    return written;
}

async function main() {
    console.log(DRY_RUN
        ? '\nCounting rows in the source. Nothing will be written.\n'
        : '\nCopying. Existing rows in the destination are updated, not duplicated.\n');

    let totalRead = 0;
    let totalWritten = 0;
    const missing = [];
    const failed = [];

    for (const table of TABLES) {
        process.stdout.write(`  ${table.padEnd(24)}`);
        try {
            const rows = await readAll(table);
            if (rows === null) {
                missing.push(table);
                console.log('not in source');
                continue;
            }
            totalRead += rows.length;

            if (DRY_RUN || rows.length === 0) {
                console.log(`${String(rows.length).padStart(6)} rows`);
                continue;
            }

            const written = await writeAll(table, rows);
            totalWritten += written;
            console.log(`${String(rows.length).padStart(6)} rows -> ${written} written`);
        } catch (error) {
            failed.push(table);
            console.log(`FAILED  ${error.message}`);
            // A restricted source is fatal for every table, so stop rather than
            // printing the same message forty more times.
            if (/restricted/i.test(error.message)) break;
        }
    }

    console.log(`\n  read ${totalRead} rows`);
    if (!DRY_RUN) console.log(`  wrote ${totalWritten} rows`);
    if (missing.length) console.log(`  absent in source: ${missing.join(', ')}`);
    if (failed.length) {
        console.log(`  FAILED: ${failed.join(', ')}`);
        console.log('\n  Nothing is lost. Fix the cause and run again; every write is an upsert.');
    }

    /*
      Storage is not copied. story-media and message-attachments are about 5 MB
      and have to be moved through the storage API separately; profile photos
      are served from genuinesugarmummies.com and need nothing.
    */
    if (!DRY_RUN && !failed.length) {
        console.log('\n  Storage buckets are not copied by this script.');
        console.log('  Recreate story-media and message-attachments in the new project.');
    }

    process.exitCode = failed.length ? 1 : 0;
}

main().catch((error) => {
    console.error(`\n  ${error.message}\n`);
    process.exitCode = 1;
});

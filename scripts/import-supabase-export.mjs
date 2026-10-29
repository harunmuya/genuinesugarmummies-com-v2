/**
 * Import a locally prepared Supabase export into a fresh destination project.
 *
 * Required environment:
 *   GSM_SUPABASE_EXPORT_DIR  directory containing manifest.json, schema.sql,
 *                            data/, and storage/
 *   NEW_SUPABASE_URL
 *   NEW_SUPABASE_SERVICE_KEY
 *
 * Run with --dry-run first. Writes are restartable upserts that preserve IDs.
 */
import { readFile, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';

const DRY_RUN = process.argv.includes('--dry-run');
const PAGE = 50;
const SOURCE_PROJECT_ID = 'xiqfrvjasvcwywdyszta';
const DESTINATION_PROJECT_ID = 'spdwcsocsclucnwttdnk';
const CONFLICT_COLUMNS = {
    user_settings: 'user_id',
    gift_wallet: 'user_id',
    money_wallet: 'user_id',
    credit_wallet: 'user_id',
    live_viewers: 'stream_id,user_id',
};

function need(name) {
    const value = process.env[name];
    if (!value) throw new Error(`${name} is not set.`);
    return value;
}

function safeTableName(value) {
    return typeof value === 'string' && /^[a-z_]+$/.test(value);
}

async function main() {
    const root = path.resolve(need('GSM_SUPABASE_EXPORT_DIR'));
    const manifest = JSON.parse(await readFile(path.join(root, 'manifest.json'), 'utf8'));
    if (manifest.formatVersion !== 1 || !Array.isArray(manifest.tableOrder)) {
        throw new Error('Unsupported or invalid export manifest.');
    }
    if (manifest.sourceProjectId !== SOURCE_PROJECT_ID) {
        throw new Error('Export source does not match the expected .com source project.');
    }

    const tables = manifest.tables || {};
    for (const [table, count] of Object.entries(tables)) {
        if (!safeTableName(table) || !Number.isSafeInteger(count) || count < 0) {
            throw new Error(`Invalid table entry in export manifest: ${table}`);
        }
    }
    for (const table of Object.keys(tables)) {
        if (!manifest.tableOrder.includes(table)) {
            throw new Error(`Missing dependency order for ${table}.`);
        }
    }

    const data = new Map();
    for (const table of manifest.tableOrder) {
        if (!safeTableName(table) || !Object.hasOwn(tables, table)) continue;
        const rows = JSON.parse(await readFile(path.join(root, 'data', `${table}.json`), 'utf8'));
        if (!Array.isArray(rows) || rows.length !== tables[table]) {
            throw new Error(`${table}: export row count does not match its manifest.`);
        }
        data.set(table, rows);
    }
    if (data.size !== Object.keys(tables).length) {
        throw new Error('Not all table exports appear in the dependency order.');
    }

    const storageFiles = manifest.storage || [];
    for (const item of storageFiles) {
        if (!['story-media', 'message-attachments'].includes(item.bucket)
            || typeof item.name !== 'string'
            || path.isAbsolute(item.name)
            || item.name.includes('\0')
            || item.name.split(/[\\/]/).some((part) => !part || part === '.' || part === '..')
            || !Number.isSafeInteger(item.bytes)
            || item.bytes < 0) {
            throw new Error('Invalid storage object entry in export manifest.');
        }
        const file = path.resolve(root, 'storage', item.bucket, item.name);
        const storageRoot = path.resolve(root, 'storage', item.bucket) + path.sep;
        if (!file.startsWith(storageRoot)) throw new Error('Storage path escaped the export directory.');
        if ((await stat(file)).size !== item.bytes) {
            throw new Error(`Storage object size mismatch for ${item.bucket}/${item.name}.`);
        }
        if (item.sha256) {
            const checksum = createHash('sha256').update(await readFile(file)).digest('hex');
            if (checksum !== item.sha256) {
                throw new Error(`Storage object checksum mismatch for ${item.bucket}/${item.name}.`);
            }
        }
    }

    console.log(`Validated ${data.size} table exports and ${storageFiles.length} storage objects.`);
    if (DRY_RUN) {
        for (const [table, rows] of data) console.log(`  ${table.padEnd(24)} ${rows.length} rows`);
        console.log('Dry run only; destination was not contacted or changed.');
        return;
    }

    const destinationUrl = new URL(need('NEW_SUPABASE_URL'));
    if (destinationUrl.origin !== `https://${DESTINATION_PROJECT_ID}.supabase.co`) {
        throw new Error('Destination URL does not match the confirmed replacement project.');
    }

    const client = createClient(destinationUrl.origin, need('NEW_SUPABASE_SERVICE_KEY'), {
        auth: { persistSession: false },
    });

    const { count: existingUsers, error: usersError } = await client
        .from('users')
        .select('*', { count: 'exact', head: true });
    if (usersError) throw new Error(`Could not verify destination members: ${usersError.message}`);
    if (existingUsers !== 0) throw new Error('Destination already contains member accounts; import stopped.');

    for (const bucket of ['story-media', 'message-attachments']) {
        const { data, error } = await client.storage.from(bucket).list('', { limit: 1 });
        if (error) throw new Error(`Could not verify ${bucket}: ${error.message}`);
        if (data?.length) throw new Error(`Destination bucket ${bucket} is not empty; import stopped.`);
    }

    for (const [table, rows] of data) {
        for (let start = 0; start < rows.length; start += PAGE) {
            const batch = rows.slice(start, start + PAGE);
            const { error } = await client.from(table).upsert(batch, {
                onConflict: CONFLICT_COLUMNS[table] || 'id',
            });
            if (error) throw new Error(`${table}: ${error.message}`);
        }
        console.log(`  ${table.padEnd(24)} ${rows.length} rows imported`);
    }

    for (const item of storageFiles) {
        const file = path.join(root, 'storage', item.bucket, item.name);
        const body = await readFile(file);
        const { error } = await client.storage.from(item.bucket).upload(item.name, body, {
            contentType: item.contentType || 'application/octet-stream',
            upsert: true,
        });
        if (error) throw new Error(`${item.bucket}/${item.name}: ${error.message}`);
    }
    console.log(`  ${storageFiles.length} storage objects imported`);

    const { count: importedUsers, error: verifyUsersError } = await client
        .from('users')
        .select('*', { count: 'exact', head: true });
    if (verifyUsersError) throw new Error(`Could not verify imported members: ${verifyUsersError.message}`);
    if (importedUsers !== tables.users) {
        throw new Error(`Member verification mismatch: expected ${tables.users}, found ${importedUsers}.`);
    }
    console.log(`  Verified ${importedUsers} member accounts`);
}

main().catch((error) => {
    console.error(`\n${error.message}\n`);
    process.exitCode = 1;
});

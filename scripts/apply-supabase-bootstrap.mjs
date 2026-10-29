/** Apply the sanitized bootstrap schema to the confirmed empty destination project. */
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const PROJECT_ID = 'spdwcsocsclucnwttdnk';
const moduleAnchor = process.env.GSM_PG_MODULE_ANCHOR;
if (!moduleAnchor) throw new Error('GSM_PG_MODULE_ANCHOR is not set. Run the PowerShell migration launcher.');
const require = createRequire(path.resolve(moduleAnchor));
const { Client } = require('pg');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const password = process.env.GSM_SUPABASE_DB_PASSWORD;

if (!password) throw new Error('GSM_SUPABASE_DB_PASSWORD is not set.');

const client = new Client({
    host: 'aws-0-eu-west-1.pooler.supabase.com',
    port: 5432,
    database: 'postgres',
    user: `postgres.${PROJECT_ID}`,
    password,
    ssl: { rejectUnauthorized: true },
    connectionTimeoutMillis: 20000,
    statement_timeout: 120000,
});

function migrationAt(sql, position) {
    const beforeError = sql.slice(0, Math.max(0, Number(position) - 1));
    const matches = [...beforeError.matchAll(/^--\s*(\d{8}_[\w.-]+\.sql)\s*$/gm)];
    return matches.at(-1)?.[1] || null;
}

try {
    await client.connect();
    const { rows } = await client.query(`
        SELECT
          (SELECT count(*) FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE')::int AS public_tables,
          (SELECT count(*) FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f'))::int AS public_relations,
          (SELECT CASE c.relkind
                    WHEN 'r' THEN 'table'
                    WHEN 'p' THEN 'partitioned table'
                    WHEN 'v' THEN 'view'
                    WHEN 'm' THEN 'materialized view'
                    WHEN 'f' THEN 'foreign table'
                  END
             FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relname = 'users'
              AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
            LIMIT 1) AS users_relation,
          (SELECT string_agg(a.attname, ', ' ORDER BY a.attnum)
             FROM pg_attribute a
            WHERE a.attrelid = to_regclass('public.users')
              AND a.attnum > 0 AND NOT a.attisdropped) AS users_columns,
          (SELECT count(*) FROM auth.users)::int AS auth_users
    `);
    if (rows[0].public_relations !== 0 || rows[0].auth_users !== 0) {
        const users = rows[0].users_relation
            ? `; public.users is a ${rows[0].users_relation} with columns: ${rows[0].users_columns || '(none)'}`
            : '';
        throw new Error(`Destination is not empty (public relations: ${rows[0].public_relations}, Auth users: ${rows[0].auth_users}${users}); schema was not applied.`);
    }

    const schema = (await readFile(path.join(root, 'supabase', 'bootstrap', 'schema.sql'), 'utf8'))
        .replace(/\uFEFF/g, '');
    try {
        await client.query(schema);
    } catch (error) {
        const migration = error.position ? migrationAt(schema, error.position) : null;
        const location = migration ? ` near ${migration}` : '';
        throw new Error(`Bootstrap failed${location}: ${error.message}`);
    }

    const { rows: result } = await client.query(`
        SELECT
          (SELECT count(*) FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE')::int AS public_tables,
          (SELECT count(*) FROM public.users)::int AS members
    `);
    console.log(`Bootstrap applied to ${PROJECT_ID}: ${result[0].public_tables} public tables; ${result[0].members} member accounts.`);
} finally {
    await client.end().catch(() => {});
}

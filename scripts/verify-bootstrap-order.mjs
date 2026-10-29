import { readFileSync } from 'node:fs';

const migration = readFileSync('supabase/migrations/20260625_foundation_social_rebuild.sql', 'utf8');
const bootstrap = readFileSync('supabase/bootstrap/schema.sql', 'utf8');
const addViewerId = 'ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewer_id';
const addViewedId = 'ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewed_id';
const addViewedAt = 'ALTER TABLE public.profile_views ADD COLUMN IF NOT EXISTS viewed_at';
const index = 'CREATE INDEX IF NOT EXISTS idx_profile_views_viewed';
const policy = 'CREATE POLICY "Users can see profile views"';

let pass = 0;
let fail = 0;
const check = (label, ok) => {
    if (ok) { pass++; console.log(`  ok    ${label}`); }
    else { fail++; console.log(`  FAIL  ${label}`); }
};

console.log('\nFresh-project bootstrap migration order');
for (const column of [addViewerId, addViewedId, addViewedAt]) {
    check(`${column.split(' ').at(-1)} is added idempotently in the source migration`, migration.includes(column));
}
const sourceFix = migration.indexOf(addViewedId);
check('legacy profile_views fields are repaired before indexes and policies use them',
    sourceFix >= 0 && sourceFix < migration.indexOf(index) && sourceFix < migration.indexOf(policy));

const bootstrapMarker = '-- 20260625_foundation_social_rebuild.sql';
const bootstrapStart = bootstrap.indexOf(bootstrapMarker);
const bootstrapFix = bootstrap.indexOf(addViewedId, bootstrapStart);
check('regenerated bootstrap contains the repair before dependent statements',
    bootstrapStart >= 0 && bootstrapFix > bootstrapStart && bootstrapFix < bootstrap.indexOf(index, bootstrapStart));
check('gift catalog seed rows are deferred to the source export',
    !/\bINSERT\s+INTO\s+public\.gift_catalog\b/i.test(bootstrap));
check('the gift catalog name uniqueness constraint remains in the bootstrap',
    bootstrap.includes('gift_catalog_name_unique'));

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;

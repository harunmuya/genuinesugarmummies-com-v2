/**
 * Run every verification script, and report honestly.
 *
 * `npm run verify` runs all of them. `npm run verify -- caching` runs the ones
 * whose filename contains "caching".
 *
 * Exit code is the number of failing scripts, so this is usable in a hook or a
 * pipeline without parsing the output.
 */
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const filter = process.argv[2] || '';
const dir = 'scripts';

const scripts = readdirSync(dir)
    .filter((name) => name.startsWith('verify-') && name.endsWith('.mjs'))
    .filter((name) => !filter || name.includes(filter))
    .sort();

if (!scripts.length) {
    console.log(filter ? `No verification matches "${filter}".` : 'No verifications found.');
    process.exitCode = 1;
} else {
    let failed = 0;
    for (const name of scripts) {
        console.log(`\n${'='.repeat(64)}\n${name}\n${'='.repeat(64)}`);
        const run = spawnSync(process.execPath, [join(dir, name)], { stdio: 'inherit' });
        if (run.status !== 0) failed++;
    }

    console.log(`\n${'='.repeat(64)}`);
    console.log(failed
        ? `${failed} of ${scripts.length} verifications failed`
        : `all ${scripts.length} verifications passed`);
    // process.exit during a socket close can trip a libuv assert, so set the
    // code and let the process end on its own.
    process.exitCode = failed;
}

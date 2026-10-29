import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { distanceKm } from '../src/lib/geo.mjs';
import { profileFitsUser, targetLabelsForUser, userProfileLabel } from '../src/lib/matching.mjs';

let pass = 0;
let fail = 0;
const check = (label, ok) => {
    if (ok) { pass++; console.log(`  ok    ${label}`); }
    else { fail++; console.log(`  FAIL  ${label}`); }
};
const read = (...parts) => readFileSync(join(...parts), 'utf8');
const api = read('gs-app-api', 'gs-app-api.php');
const wordpress = read('src', 'lib', 'wordpress.js');

console.log('\nPublished WordPress profile feed');
check('only the two listing categories are queried', /'category_name'\s*=>\s*'sugarmummies,sugar-daddies'/.test(api));
check('list responses omit full post HTML', /'content'\s*=>\s*\$include_content\s*\?/.test(api));
check('single posts outside listing categories return 404', /if \(!\$profile_type\)[\s\S]{0,120}Profile not found/.test(api));
check('the app validates profile type before accepting custom API results', /typedProfiles\s*=\s*profiles\.filter/.test(wordpress));
check('the WordPress fallback constrains posts by listing category IDs', /categories=\$\{categoryIds\.join\(','\)\}/.test(wordpress));
check('single-profile fallback rejects non-listing categories', /profileTypeFromCategoryIds\(post, categories\)[\s\S]{0,100}\? \{ \.\.\.parseProfile/.test(wordpress));

console.log('\nProfile preference matching');
check('camelCase member labels are read', userProfileLabel({ profileLabel: 'sugar_mummy' }) === 'sugar_mummy');
check('toyboy preferences target sugar mummy listings', targetLabelsForUser({ preference: 'toyboy_looking_for_sugar_mummy' })?.has('sugar_mummy'));
check('sugar mummy preferences target toyboy members', profileFitsUser({ profileLabel: 'toyboy' }, { profileLabel: 'sugar_mummy' }));
check('unrecognized user labels do not hide all profiles', profileFitsUser({ profileLabel: 'sugar_daddy' }, { profileLabel: 'other' }));

console.log('\nDistance calculation');
check('missing coordinates never become the Gulf of Guinea', distanceKm({ latitude: null, longitude: null }, { latitude: 0, longitude: 0 }) === null);
check('invalid coordinates are rejected', distanceKm({ latitude: 91, longitude: 0 }, { latitude: 0, longitude: 0 }) === null);
check('valid zero coordinates remain valid', distanceKm({ latitude: 0, longitude: 0 }, { latitude: 0, longitude: 1 }) === 111);

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;

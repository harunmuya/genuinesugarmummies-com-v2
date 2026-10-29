import { existsSync, readFileSync } from 'node:fs';
import sharp from 'sharp';

let passed = 0;
let failed = 0;

function check(condition, description) {
    if (condition) {
        passed++;
        console.log(`  ok    ${description}`);
    } else {
        failed++;
        console.log(`  FAIL  ${description}`);
    }
}

const layout = readFileSync('src/app/layout.js', 'utf8');
const robots = readFileSync('src/app/robots.js', 'utf8');
const nextConfig = readFileSync('next.config.js', 'utf8');
const manifest = JSON.parse(readFileSync('public/manifest.json', 'utf8'));
const logo = readFileSync('src/components/Logo.js', 'utf8');
const admin = readFileSync('src/app/api/admin/route.js', 'utf8');
const members = readFileSync('src/app/api/members/route.js', 'utf8');
const login = readFileSync('src/app/auth/login/page.js', 'utf8');
const contact = readFileSync('src/app/contact/page.js', 'utf8');
const download = readFileSync('src/app/download/page.js', 'utf8');
const mainLayout = readFileSync('src/app/(main)/layout.js', 'utf8');
const materialIcon = readFileSync('src/components/MaterialIcon.js', 'utf8');
const materialSources = [
    download,
    contact,
    materialIcon,
    readFileSync('src/components/PolicyDocument.js', 'utf8'),
    readFileSync('src/app/terms/page.js', 'utf8'),
    readFileSync('src/app/privacy/page.js', 'utf8'),
    readFileSync('src/app/safety/page.js', 'utf8'),
    readFileSync('src/app/community-guidelines/page.js', 'utf8'),
].join('\n');

console.log('\nBrand identity and public claims');
check(layout.includes('Genuine Sugarmummies') && manifest.name === 'Genuine Sugarmummies', 'web metadata and install manifest use the .com brand');
check(!/verified by hand|meet verified sugar/i.test(`${layout}\n${manifest.description}`), 'metadata makes no unsupported verification promise');
check(!/canonical:\s*['"]\//.test(layout), 'root canonical is not incorrectly inherited by every route');
check(logo.includes('/brand/genuine-sugarmummies-wordmark-white.png'), 'app logo uses the supplied wordmark asset');
check(/index:\s*false/.test(layout) && /follow:\s*false/.test(layout), 'app pages declare noindex and nofollow');
check(/allow:[\s\S]*?\/auth\/login/.test(robots) && /disallow:[\s\S]*?\/api\//.test(robots), 'crawler can read public noindex pages but not APIs or member areas');
check(nextConfig.includes("key: 'X-Robots-Tag'") && nextConfig.includes('noindex, nofollow, noarchive'), 'API responses are excluded from search indexes');
check(!login.includes('grid grid-cols-3') && !login.includes('AnimatePresence'), 'authentication is no longer split into three tabs or staged screens');
check(login.includes('Forgot password?') && login.includes('Already registered?') && login.includes('Create account'), 'sign-in and registration cross-links are visible in context');
check(login.includes('href="/download"') && mainLayout.includes('href="/download"'), 'Android download page is linked from login and the signed-in app footer');
check(download.includes('/downloads/genuine-sugar-mummies-1.5.1.apk') && download.includes('Android app · Version 1.5.1'), 'download page points to the current versioned APK');
check(download.includes('not a Google Play or Apple App Store listing') && download.includes('Play Protect displays a warning, cancel') && download.includes('do not disable or bypass'), 'download page clearly identifies sideloading and does not advise bypassing Play Protect');
check(download.includes('MaterialIcon') && materialIcon.includes('/material-symbols/outlined/') && existsSync('public/material-symbols/outlined/person_search.svg'), 'Google Material Symbols are served locally as SVG icons');
const materialNames = new Set([
    ...[...materialSources.matchAll(/name="([a-z0-9_]+)"/g)].map((match) => match[1]),
    ...[...materialSources.matchAll(/icon:\s*'([a-z0-9_]+)'/g)].map((match) => match[1]),
    ...[...materialSources.matchAll(/\['([a-z0-9_]+)',/g)].map((match) => match[1]),
]);
const missingMaterialIcons = [...materialNames].filter((name) => !existsSync(`public/material-symbols/outlined/${name}.svg`));
check(materialNames.size >= 25 && missingMaterialIcons.length === 0, 'all referenced Material Symbols have local SVG assets');
check(contact.includes("'report'") && contact.includes("'Report a safety concern' ? 'report'"), 'report concern link resolves to a real support section');
for (const [file, minimumSections] of [
    ['src/app/terms/page.js', 7],
    ['src/app/privacy/page.js', 7],
    ['src/app/safety/page.js', 6],
    ['src/app/community-guidelines/page.js', 7],
]) {
    const content = readFileSync(file, 'utf8');
    const sections = (content.match(/icon: '/g) || []).length;
    check(sections >= minimumSections && content.includes('PolicyDocument'), `${file} has substantial, structured guidance with Material Symbols`);
}

console.log('\nBrand asset integrity');
for (const [file, expected] of [
    ['public/brand/genuine-sugarmummies-wordmark.png', [1400, 115]],
    ['public/brand/genuine-sugarmummies-wordmark-white.png', [1400, 116]],
    ['public/icons/icon-192.png', [192, 192]],
    ['public/icons/icon-512.png', [512, 512]],
]) {
    const { width, height, format } = await sharp(file).metadata();
    check(width === expected[0] && height === expected[1] && format === 'png', `${file} has the expected PNG dimensions`);
}

console.log('\nAccount controls');
check(!admin.includes('Admin@2026!') && !admin.includes('admin@genuinesugarmummies.com'), 'no built-in admin credential is shipped');
check(admin.includes('createHmac') && admin.includes('ADMIN_TOKEN_TTL_MS') && admin.includes('claims.exp > Date.now()'), 'admin token is signed and expires');
check(/subscription_tier:\s*'free'/.test(members), 'new account payload cannot choose a paid tier');

console.log(`\n${passed} passed, ${failed} failed`);
if (failed) process.exitCode = 1;

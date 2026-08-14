/**
 * Is this readable and hittable on the phone people actually use?
 *
 * The app is a Capacitor shell, so almost every session is a phone held in one
 * hand, and a large share of them are 360px wide. Two things were wrong.
 *
 * Text had been shrunk to make things fit: 101 uses of 10px, and 23 at 8, 8.5
 * or 9px. Nine pixels is not small, it is unreadable, and it is what you reach
 * for when the layout is too tight rather than when the text is unimportant.
 *
 * The members grid showed it plainly. Each card carried five action buttons in
 * a grid-cols-5, inside a card that was itself one of two columns: about 26px
 * per button on a 360px screen, with labels at 8.5px, truncated. Raising the
 * font would only have made them overflow. The fix was two actions instead of
 * five, with the rest on the profile where there is room.
 *
 * These checks encode the floor, not a preference: 11px is the smallest size
 * Apple and Google publish for incidental text, and 44px is the smallest
 * reliable touch target.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

function walk(dir) {
    const out = [];
    for (const entry of readdirSync(dir)) {
        const full = join(dir, entry);
        if (statSync(full).isDirectory()) out.push(...walk(full));
        else if (entry.endsWith('.js')) out.push(full);
    }
    return out;
}
const files = walk('src');

/*
  Comments are stripped before anything is matched.

  This is the third checker in this project to fail against its own explanation.
  A comment describing the grid-cols-5 that was removed contains the string
  "grid-cols-5", so the check reported the fix as missing. Reading prose as code
  is worse than having no check: it fails on working code, and it hides the case
  it exists to catch.
*/
const read = (f) => readFileSync(f, 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\{\/\*[\s\S]*?\*\/\}/g, '')
    .replace(/^\s*\/\/.*$/gm, '');

console.log('\nNothing is too small to read');
{
    /*
      Anything below 11px. These were badge labels, captions and button text —
      exactly the things people need to read to know what a control does.
    */
    const offenders = [];
    for (const file of files) {
        for (const m of read(file).matchAll(/text-\[(\d+(?:\.\d+)?)px\]/g)) {
            if (Number(m[1]) < 11) offenders.push(`${file.replace('src\\', '')} ${m[0]}`);
        }
    }
    check('no text below 11px', offenders.length === 0,
        offenders.length ? offenders.slice(0, 5).join(', ') : '11px is the published floor for incidental text');
}

console.log('\nControls are big enough to hit');
{
    /*
      Column count alone is the wrong test, and this checked it first and was
      wrong three times over.

      A full-width grid-cols-6 of icon buttons gives about 54px a cell on a
      360px screen, which is a fine target. discover's five-up action row, the
      live stat row and the profile's six-up action row are all like that, and
      flagging them said nothing useful.

      What actually broke was density inside something already narrow: five
      buttons in a card that was itself one of two columns, so each cell was a
      quarter of half the screen. The signal for that is not the column count,
      it is the font size the author had to drop to in order to fit a label —
      which the 11px floor above already catches, and which the members card
      check below pins to the specific place it happened.

      So the generic rule is gone rather than kept and ignored.
    */
    const buttons = [];
    for (const file of files) {
        const src = read(file);
        // An interactive element with no height class at all cannot be relied
        // on to reach 44px once its text shrinks.
        for (const m of src.matchAll(/<button[^>]*className="([^"]*)"/g)) {
            const cls = m[1];
            if (/\b(h-\d+|min-h-\d+|h-\[\d+px\]|py-\d|p-\d|aspect-)/.test(cls)) continue;
            if (/absolute|inset-|sr-only/.test(cls)) continue;
            buttons.push(`${file.replace('src\\', '')}`);
        }
    }
    const worst = [...new Set(buttons)];
    check('buttons declare a height or padding', worst.length === 0,
        worst.length ? `${worst.length} file(s): ${worst.slice(0, 3).join(', ')}` : 'nothing relies on text alone for its tap target');
}

console.log('\nThe members card was the worst of it');
{
    const members = read(join('src', 'app', '(main)', 'members', 'page.js'));
    check('its actions are no longer a five-up grid',
        !/grid-cols-5/.test(members),
        'five buttons across half a screen was about 26px each');
    check('and their labels are legible',
        !/text-\[(?:8|8\.5|9|10)px\]/.test(members));
    check('the remaining actions keep a 44px target',
        /min-h-11/.test(members),
        'min-h-11 is 44px, the smallest reliable touch target');
}

console.log('\nThe layout is not pinned to one width');
{
    /*
      A fixed pixel width wider than about 320px cannot fit the smallest
      screens in use once padding is taken off.
    */
    const rigid = [];
    for (const file of files) {
        for (const m of read(file).matchAll(/\bw-\[(\d{3,})px\]/g)) {
            if (Number(m[1]) > 320) rigid.push(`${file.replace('src\\', '')} ${m[0]}`);
        }
    }
    check('no fixed width wider than the smallest screen', rigid.length === 0,
        rigid.length ? rigid.join(', ') : '');

    check('pinch zoom is allowed', /maximumScale: 5/.test(read(join('src', 'app', 'layout.js'))),
        'it was locked at 1, which fails WCAG 1.4.4 on an app built around photos');
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;

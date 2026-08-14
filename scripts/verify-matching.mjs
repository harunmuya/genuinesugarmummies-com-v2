/**
 * Is a match a mutual like, or still a guess?
 *
 * This app had no matching system. Likes were written to member_likes and
 * nothing ever read them back the other way, so two people liking each other
 * produced two rows and no match. The matches table had existed since
 * 20260703_120 and no code had ever written to it.
 *
 * What filled the gap was worse than nothing. discover declared a match from a
 * compatibility score:
 *
 *     const score = matchScore(current, user);
 *     if (score >= 93) addMatch(profile, score);
 *
 * So the matches list filled up with people who had never seen the account,
 * while a genuine mutual like produced no match at all. The matches screen
 * separately requested the whole member directory with per_page=240 and
 * relabelled it, which is why it never resembled a matches screen.
 *
 * Every failure here is silent: a match that never fires looks exactly like
 * nobody liking you back. Hence checking the shape of the logic directly.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

/*
  Comments are stripped before anything is matched against.

  Both "is the old code gone" checks failed on their first run, against the
  comments explaining that the old code had been removed. The comment quotes
  `if (score >= 93) addMatch(...)` and mentions per_page=240 precisely because
  those are what changed, so a checker reading prose as code concludes the fix
  was never applied. That is worse than no check: it reports a fault in working
  code and hides the one case it exists to catch.
*/
const strip = (source) => source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    .replace(/\{\/\*[\s\S]*?\*\/\}/g, '');

const read = (...parts) => strip(readFileSync(join(...parts), 'utf8'));

const api = read('src', 'app', 'api', 'members', 'route.js');
const discover = read('src', 'app', '(main)', 'discover', 'page.js');
const matches = read('src', 'app', '(main)', 'matches', 'page.js');
const auth = read('src', 'contexts', 'AuthContext.js');

console.log('\nA match is created from a reciprocal like');
{
    check('the like handler looks for the other like', /recordMatchIfMutual/.test(api));
    check('by querying member_likes in the opposite direction',
        /liker_id', memberId\)[\s\S]{0,80}liked_id', actorUserId/.test(api),
        'liker and liked swapped, which is what makes it reciprocal');
    check('and writes to the matches table', /from\('matches'\)[\s\S]{0,200}upsert/.test(api),
        'the table existed for months with nothing ever writing to it');

    /*
      matches has UNIQUE(user_one_id, user_two_id), and that constraint cannot
      know the columns are interchangeable. Inserting (A,B) and (B,A) makes two
      rows for one match, and the pair then appears twice for one of the two.
    */
    check('the pair is stored in a fixed order',
        /\[actorUserId, memberId\]\.sort\(\)/.test(api),
        'otherwise (A,B) and (B,A) are two rows for one match');

    check('a like never matches with itself',
        /actorUserId === memberId/.test(api));
}

console.log('\nThe client is told, and shows it');
{
    check('the API returns whether it matched', /matched: match\.matched/.test(api));
    check('AuthContext passes that back to the caller', /matchResult/.test(auth),
        'it used to return { ok: true } and drop the answer');

    /*
      The specific regression to guard: a match declared from a compatibility
      score, about somebody who has never seen the profile.
    */
    check('discover no longer invents matches from a score',
        !/if \(score >= \d+\) addMatch/.test(discover),
        'a score says nothing about whether they liked you');
    check('and reacts to the real signal instead',
        /result\?\.matched/.test(discover));

    check('there is an It is a Match moment',
        existsSync(join('src', 'components', 'MatchCelebration.js')));
    check('and discover shows it', /MatchCelebration/.test(discover),
        'without it a mutual like silently advances to the next card');
}

console.log('\nThe matches screen shows matches');
{
    check('it asks for matches', /action: 'matches'/.test(matches));
    check('rather than listing the whole directory',
        !/per_page=240/.test(matches),
        'it used to request every member and relabel them');
    check('the endpoint exists', /action === 'matches'/.test(api));
    check('and reads the pair from either side',
        /user_one_id\.eq\.\$\{userId\},user_two_id\.eq\.\$\{userId\}/.test(api),
        'the pair is sorted, so this account can be on either side');
    /*
      A peer whose account was deleted leaves a match row pointing at nobody.
      Rendering that is a crash in the list.
    */
    check('matches with a deleted peer are dropped',
        /\.filter\(\(match\) => match\.member\)/.test(api));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;

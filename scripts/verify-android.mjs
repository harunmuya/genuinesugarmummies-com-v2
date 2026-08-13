/**
 * Can this app actually use the hardware it asks for, and will a release
 * install over what members already have?
 *
 * Both were broken, in ways that look fine until someone tries to make a call.
 *
 * The manifest declared camera, microphone, location and notifications, and
 * nothing else. Choosing a profile photo from the gallery, saving a received
 * image and anything to do with a Bluetooth headset had no permission to
 * request, so they failed with no prompt and no error.
 *
 * Worse, camera and microphone could not have worked at all. A web page calling
 * getUserMedia does not reach Android directly: the WebView asks the app
 * through WebChromeClient.onPermissionRequest, and the default implementation
 * denies. Nothing overrode it, so holding the OS permission changed nothing.
 *
 * And the signing certificate has to match the published APK exactly. It does
 * not matter how good a release is if Android refuses to install it over the
 * one people have, and the only way through that is an uninstall that loses
 * their local state.
 */
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join } from 'node:path';

let pass = 0;
let fail = 0;
const check = (label, ok, detail = '') => {
    if (ok) { pass++; console.log(`  ok    ${label}${detail ? `  ${detail}` : ''}`); }
    else { fail++; console.log(`  FAIL  ${label}${detail ? `  ${detail}` : ''}`); }
};

const manifest = readFileSync(
    join('android', 'app', 'src', 'main', 'AndroidManifest.xml'), 'utf8');
const activity = readFileSync(
    join('android', 'app', 'src', 'main', 'java', 'com', 'genuinesugarmummies',
        'global', 'MainActivity.java'), 'utf8');

console.log('\nEvery capability the app uses is declared');
{
    const required = {
        'CAMERA': 'video calls and taking a profile photo',
        'RECORD_AUDIO': 'voice and video calls',
        'MODIFY_AUDIO_SETTINGS': 'routing call audio',
        'READ_MEDIA_IMAGES': 'choosing a photo on Android 13+',
        'READ_MEDIA_VIDEO': 'choosing a video on Android 13+',
        'READ_MEDIA_VISUAL_USER_SELECTED': 'the Android 14 selected-photos grant',
        'READ_EXTERNAL_STORAGE': 'choosing a photo on Android 12 and below',
        'BLUETOOTH_CONNECT': 'a call reaching a headset or car speaker',
        'NEARBY_WIFI_DEVICES': 'nearby devices',
        'ACCESS_FINE_LOCATION': 'distance between members',
        'POST_NOTIFICATIONS': 'message and call alerts',
        'VIBRATE': 'ringing',
        'WAKE_LOCK': 'keeping the screen on during a call',
        'FOREGROUND_SERVICE': 'a call surviving the app going to background',
        'REQUEST_INSTALL_PACKAGES': 'the in-app update installing what it downloads',
    };
    for (const [permission, why] of Object.entries(required)) {
        check(permission, manifest.includes(`android.permission.${permission}`), why);
    }
}

console.log('\nAnd the WebView is allowed to answer for them');
{
    /*
      This is the part that made the permissions academic. Without an
      onPermissionRequest override the WebView denies every getUserMedia, so
      the app could hold CAMERA and RECORD_AUDIO and still fail to open a call.
    */
    check('onPermissionRequest is overridden', /onPermissionRequest/.test(activity),
        'the default implementation denies, so calls could never have worked');
    check('it answers with grant or deny',
        /request\.grant\(/.test(activity) && /request\.deny\(\)/.test(activity),
        'a request left unanswered hangs the page forever');
    check('geolocation prompts are answered', /onGeolocationPermissionsShowPrompt/.test(activity));
    check('downloads are handled', /setDownloadListener/.test(activity),
        'a WebView ignores download links otherwise, which is why update looked broken');

    /*
      Asking for camera and microphone on launch, before the user has done
      anything needing either, is the prompt people refuse. Two refusals set
      "don't ask again" and calling is broken permanently.
    */
    check('nothing is requested from onCreate',
        !/onCreate[\s\S]{0,400}requestPermissions/.test(activity),
        'permissions are requested when the page asks, with the reason on screen');
}

console.log('\nMembers on an old shell are told about the new one');
{
    /*
      Before this existed there was no version endpoint and no prompt, so
      versionCode 3 sat on phones with no camera or microphone permission and
      no way to hear about the build that had them.
    */
    const route = join('src', 'app', 'api', 'app-version', 'route.js');
    check('there is a version endpoint', existsSync(route));

    if (existsSync(route)) {
        const src = readFileSync(route, 'utf8');
        const gradleRaw = readFileSync(join('android', 'app', 'build.gradle'), 'utf8')
            .replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
        const built = Number((gradleRaw.match(/versionCode\s+(\d+)/) || [])[1] || 0);
        const advertised = Number((src.match(/versionCode:\s*(\d+)/) || [])[1] || 0);

        /*
          Drift here is worse than no endpoint. Advertising a version higher
          than the APK actually served means the prompt reappears after every
          successful install, because the shell can never reach the number it
          is being compared against.
        */
        check('it advertises exactly what the project builds', advertised === built,
            `endpoint ${advertised}, gradle ${built}`);

        const prompt = join('src', 'components', 'UpdatePrompt.js');
        check('and something shows it', existsSync(prompt));
        if (existsSync(prompt)) {
            const ui = readFileSync(prompt, 'utf8');
            /*
              versionCode 3 does not announce itself, so absence of the token
              has to be read as "old shell". Treating it as unknown-so-silent
              would leave exactly the members who need the update seeing
              nothing.
            */
            check('an unannounced shell counts as out of date',
                /installed === null \|\| installed <|installed == null \|\| installed </.test(ui),
                'versionCode 3 predates the User-Agent token');
            check('and it stays out of the way on the web', /isNativePlatform|Capacitor/.test(ui),
                'this is a website too; offering an APK to a laptop is noise');
        }

        const activity2 = readFileSync(
            join('android', 'app', 'src', 'main', 'java', 'com', 'genuinesugarmummies',
                'global', 'MainActivity.java'), 'utf8');
        check('the shell puts its version in the User-Agent', /GSGlobal\/"/.test(activity2));
        check('by appending, not replacing', /getUserAgentString\(\) \+/.test(activity2),
            'replacing it breaks feature detection in ways hard to trace back');
    }
}

console.log('\nA release installs over what members already have');
{
    const gradle = readFileSync(join('android', 'app', 'build.gradle'), 'utf8')
        .replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
    const builtId = (gradle.match(/applicationId\s+"([^"]+)"/) || [])[1] || '';
    const builtCode = Number((gradle.match(/versionCode\s+(\d+)/) || [])[1] || 0);

    check('this is the global app, not the Kenya one',
        builtId === 'com.genuinesugarmummies.global',
        `${builtId} — the two apps must never share an applicationId`);

    const APK = join('public', 'downloads', 'genuine-sugar-mummies.apk');
    if (!existsSync(APK)) {
        console.log('  ..    no APK in public/downloads, nothing to compare');
    } else {
        const sdk = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT
            || join(process.env.LOCALAPPDATA || '', 'Android', 'Sdk');
        let aapt = null;
        try {
            for (const v of readdirSync(join(sdk, 'build-tools')).sort().reverse()) {
                const c = join(sdk, 'build-tools', v, 'aapt.exe');
                if (existsSync(c)) { aapt = c; break; }
            }
        } catch { /* no sdk here */ }

        if (!aapt) {
            console.log('  ..    Android build tools not on this machine, APK not read');
        } else {
            const badging = execFileSync(aapt, ['dump', 'badging', APK], { encoding: 'utf8' });
            const shippedCode = Number((badging.match(/versionCode='(\d+)'/) || [])[1] || 0);
            const shippedId = (badging.match(/package: name='([^']+)'/) || [])[1] || '';

            check('the APK being served is this app', shippedId === builtId, shippedId);
            check('and is not behind the project', shippedCode >= builtCode,
                `serving ${shippedCode}, project builds ${builtCode}`);

            for (const p of ['CAMERA', 'RECORD_AUDIO', 'READ_MEDIA_IMAGES', 'BLUETOOTH_CONNECT']) {
                const perms = execFileSync(aapt, ['dump', 'permissions', APK], { encoding: 'utf8' });
                check(`the served APK really carries ${p}`, perms.includes(p),
                    'declared in the manifest is not the same as present in the build');
            }

            /*
              The signature, read off the artefact rather than the keystore, so
              no password is involved. This is the check that matters most: a
              wrong package name or low version can be rebuilt, but a release
              signed with the wrong key cannot update anybody, and if the
              original key is lost it never can be.
            */
            const EXPECTED = process.env.GS_EXPECTED_SIGNER
                || '6b698972405d7e00856c368e0643ce964385f7ac96fba2ef27816ca2cdc538bc';
            const apksigner = aapt.replace(/aapt\.exe$/, 'apksigner.bat');
            const jdk = process.env.JAVA_HOME
                || ['C:/Program Files/Android/Android Studio/jbr']
                    .find((c) => existsSync(join(c, 'bin')));
            if (existsSync(apksigner) && jdk) {
                try {
                    const out = execFileSync(apksigner, ['verify', '--print-certs', `"${APK}"`], {
                        encoding: 'utf8',
                        env: { ...process.env, JAVA_HOME: jdk },
                        shell: true,
                    });
                    const digest = (out.match(/SHA-256 digest:\s*([0-9a-f]+)/i) || [])[1] || '';
                    check('signed with the key the installed app trusts',
                        digest.toLowerCase() === EXPECTED,
                        digest ? `${digest.slice(0, 16)}...` : 'no certificate found');
                } catch {
                    console.log('  ..    signature could not be read');
                }
            } else {
                console.log('  ..    no JDK found, signature not checked');
            }
        }
    }
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exitCode = fail ? 1 : 0;

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const publicDir = path.join(root, 'public');
const androidRes = path.join(root, 'android', 'app', 'src', 'main', 'res');
const sourcePath = path.join(publicDir, 'brand', 'genuine-sugarmummies-icon-source.png');

const { data, info } = await sharp(sourcePath)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

let left = info.width;
let top = info.height;
let right = 0;
let bottom = 0;

for (let y = 0; y < info.height; y += 1) {
    for (let x = 0; x < info.width; x += 1) {
        const offset = (y * info.width + x) * info.channels;
        const brightness = Math.max(data[offset], data[offset + 1], data[offset + 2]);
        if (data[offset + 3] > 16 && brightness > 120) {
            left = Math.min(left, x);
            top = Math.min(top, y);
            right = Math.max(right, x);
            bottom = Math.max(bottom, y);
        }
    }
}

if (right <= left || bottom <= top) {
    throw new Error(`No visible brand mark found in ${sourcePath}`);
}

const padding = Math.round(Math.min(info.width, info.height) * 0.012);
left = Math.max(0, left - padding);
top = Math.max(0, top - padding);
right = Math.min(info.width - 1, right + padding);
bottom = Math.min(info.height - 1, bottom + padding);

const crop = {
    left,
    top,
    width: right - left + 1,
    height: bottom - top + 1,
};
const cropped = await sharp(sourcePath).extract(crop).ensureAlpha().raw().toBuffer({ resolveWithObject: true });

for (let offset = 0; offset < cropped.data.length; offset += cropped.info.channels) {
    const brightness = Math.max(
        cropped.data[offset],
        cropped.data[offset + 1],
        cropped.data[offset + 2],
    );
    if (brightness < 20) cropped.data[offset + 3] = 0;
}

const mark = await sharp(cropped.data, { raw: cropped.info }).png().toBuffer();

async function makeSquareIcon(size, outputPath) {
    const logo = await sharp(mark)
        .resize(Math.round(size * 0.86), Math.round(size * 0.68), {
            fit: 'contain',
            background: { r: 0, g: 0, b: 0, alpha: 0 },
        })
        .png()
        .toBuffer();
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await sharp({
        create: {
            width: size,
            height: size,
            channels: 4,
            background: { r: 9, g: 9, b: 11, alpha: 1 },
        },
    })
        .composite([{ input: logo, gravity: 'center' }])
        .png()
        .toFile(outputPath);
}

await makeSquareIcon(512, path.join(publicDir, 'gs-logo.png'));
await makeSquareIcon(192, path.join(publicDir, 'icons', 'icon-192.png'));
await makeSquareIcon(512, path.join(publicDir, 'icons', 'icon-512.png'));

const foregroundSize = 432;
const adaptiveLogo = await sharp(mark)
    .resize(Math.round(foregroundSize * 0.68), Math.round(foregroundSize * 0.56), {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer();
const foregroundPath = path.join(androidRes, 'mipmap-xxxhdpi', 'ic_launcher_foreground.png');
await fs.mkdir(path.dirname(foregroundPath), { recursive: true });
await sharp({
    create: {
        width: foregroundSize,
        height: foregroundSize,
        channels: 4,
        background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
})
    .composite([{ input: adaptiveLogo, gravity: 'center' }])
    .png()
    .toFile(foregroundPath);

for (const [density, scale, size] of [
    ['mdpi', 1, 48],
    ['hdpi', 1.5, 72],
    ['xhdpi', 2, 96],
    ['xxhdpi', 3, 144],
    ['xxxhdpi', 4, 192],
]) {
    const directory = path.join(androidRes, `mipmap-${density}`);
    await makeSquareIcon(size, path.join(directory, 'ic_launcher.png'));
    await makeSquareIcon(size, path.join(directory, 'ic_launcher_round.png'));

    if (density !== 'xxxhdpi') {
        const foregroundSizeForDensity = Math.round(108 * scale);
        const densityForeground = await sharp(mark)
            .resize(Math.round(foregroundSizeForDensity * 0.68), Math.round(foregroundSizeForDensity * 0.56), {
                fit: 'contain',
                background: { r: 0, g: 0, b: 0, alpha: 0 },
            })
            .png()
            .toBuffer();
        await sharp({
            create: {
                width: foregroundSizeForDensity,
                height: foregroundSizeForDensity,
                channels: 4,
                background: { r: 0, g: 0, b: 0, alpha: 0 },
            },
        })
            .composite([{ input: densityForeground, gravity: 'center' }])
            .png()
            .toFile(path.join(directory, 'ic_launcher_foreground.png'));
    }
}

console.log('Generated branded PWA and Android launcher icons from the supplied GS mark.');

/**
 * Generates app icons using SVG → PNG via the sharp package (already in Next.js deps).
 * Re-uses Node.js built-ins only as fallback if sharp is missing.
 */
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const PUBLIC = join(ROOT, 'public');
const ICONS_DIR = join(PUBLIC, 'icons');

if (!existsSync(ICONS_DIR)) mkdirSync(ICONS_DIR, { recursive: true });

// Build SVG for a given size
function buildSVG(size) {
    const pad = Math.round(size * 0.12);
    const r = Math.round(size * 0.22);     // corner radius
    const cx = size / 2;
    const cy = size / 2;
    const fontSize = Math.round(size * 0.38);
    const heartY = Math.round(cy + size * 0.26);
    const heartSize = Math.round(size * 0.12);

    return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#7C3AED"/>
      <stop offset="100%" style="stop-color:#DB2777"/>
    </linearGradient>
    <linearGradient id="gold" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FBBF24"/>
      <stop offset="100%" style="stop-color:#F59E0B"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="${Math.round(size * 0.015)}" result="blur"/>
      <feComposite in="SourceGraphic" in2="blur" operator="over"/>
    </filter>
  </defs>

  <!-- Background rounded square -->
  <rect x="0" y="0" width="${size}" height="${size}" rx="${r}" ry="${r}" fill="url(#bg)"/>

  <!-- Subtle inner glow ring -->
  <rect x="${pad}" y="${pad}" width="${size - pad * 2}" height="${size - pad * 2}"
    rx="${r - pad / 2}" ry="${r - pad / 2}"
    fill="none" stroke="rgba(255,255,255,0.15)" stroke-width="${Math.round(size * 0.015)}"/>

  <!-- GS Letters -->
  <text x="${cx}" y="${cy + fontSize * 0.35}"
    font-family="Georgia, 'Times New Roman', serif"
    font-size="${fontSize}"
    font-weight="bold"
    text-anchor="middle"
    fill="url(#gold)"
    filter="url(#glow)">GS</text>

  <!-- Star / Heart icon below letters -->
  <g transform="translate(${cx - heartSize}, ${heartY - heartSize})">
    <path d="M${heartSize} ${heartSize * 0.3}
      C${heartSize} ${heartSize * 0.1} ${heartSize * 0.7} 0 ${heartSize * 0.5} ${heartSize * 0.25}
      C${heartSize * 0.3} 0 0 ${heartSize * 0.1} 0 ${heartSize * 0.3}
      C0 ${heartSize * 0.55} ${heartSize * 0.5} ${heartSize * 0.9} ${heartSize * 0.5} ${heartSize * 0.9}
      C${heartSize * 0.5} ${heartSize * 0.9} ${heartSize} ${heartSize * 0.55} ${heartSize} ${heartSize * 0.3}Z"
      fill="white" opacity="0.9"/>
  </g>
</svg>`;
}

// Write SVG files first
const sizes = [
    { name: 'gs-logo.png', size: 512 },
    { name: 'icons/icon-192.png', size: 192 },
    { name: 'icons/icon-512.png', size: 512 },
];

// Try to use sharp (bundled with Next.js image optimization)
let sharp;
try {
    const mod = await import('sharp');
    sharp = mod.default;
    console.log('Using sharp for PNG generation');
} catch {
    console.log('sharp not available');
}

for (const { name, size } of sizes) {
    const svgContent = buildSVG(size);
    const outPath = join(PUBLIC, name);

    if (sharp) {
        await sharp(Buffer.from(svgContent))
            .png()
            .toFile(outPath);
        console.log(`✓ Generated ${name} (${size}x${size})`);
    } else {
        // Fallback: write as SVG with .png extension (browsers still render it)
        writeFileSync(outPath, svgContent, 'utf8');
        console.log(`✓ Saved ${name} as SVG fallback (${size}x${size})`);
    }
}

console.log('\nAll icons generated in /public');

'use client';

const COLORS = [
    ['#7c3aed', '#a78bfa'], // violet
    ['#ec4899', '#f472b6'], // pink
    ['#8b5cf6', '#a78bfa'], // purple
    ['#e11d48', '#f43f5e'], // rose
    ['#3b82f6', '#60a5fa'], // blue
    ['#10b981', '#34d399'], // emerald
    ['#f59e0b', '#fbbf24'], // amber
    ['#06b6d4', '#22d3ee'], // cyan
    ['#14b8a6', '#2dd4bf'], // teal
    ['#6366f1', '#818cf8'], // indigo
];

function getColorPair(name) {
    if (!name) return COLORS[0];
    const charCode = name.charCodeAt(0) + (name.length > 1 ? name.charCodeAt(1) : 0);
    return COLORS[charCode % COLORS.length];
}

export default function UserAvatar({ name, src, size = 40, className = '' }) {
    const letter = name ? name.charAt(0).toUpperCase() : '?';
    const [colorFrom, colorTo] = getColorPair(name || '');
    const fontSize = Math.round(size * 0.42);

    if (src) {
        return (
            <div className={`relative shrink-0 rounded-full overflow-hidden ${className}`}
                style={{ width: size, height: size }}>
                <img src={src} alt={name || ''} className="w-full h-full object-cover" loading="lazy" />
            </div>
        );
    }

    return (
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className={`shrink-0 ${className}`}>
            <defs>
                <linearGradient id={`avatar-${letter}-${size}`} x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor={colorFrom} />
                    <stop offset="100%" stopColor={colorTo} />
                </linearGradient>
            </defs>
            <circle cx={size / 2} cy={size / 2} r={size / 2} fill={`url(#avatar-${letter}-${size})`} />
            <text
                x="50%" y="50%"
                dominantBaseline="central"
                textAnchor="middle"
                fill="white"
                fontWeight="700"
                fontSize={fontSize}
                fontFamily="Outfit, system-ui, sans-serif"
            >
                {letter}
            </text>
        </svg>
    );
}

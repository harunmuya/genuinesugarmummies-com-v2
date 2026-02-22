'use client';

/**
 * GS .com Logo — Purple/Magenta branded heart-diamond
 * Distinct from the .co.ke orange logo
 */
export default function Logo({ size = 32, className = '' }) {
    return (
        <svg
            width={size}
            height={size}
            viewBox="0 0 64 64"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
            className={`shrink-0 ${className}`}
            aria-label="GS Logo"
        >
            {/* Background circle with gradient */}
            <defs>
                <linearGradient id="gsLogoGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#7C3AED" />
                    <stop offset="50%" stopColor="#A855F7" />
                    <stop offset="100%" stopColor="#EC4899" />
                </linearGradient>
                <linearGradient id="gsLogoShine" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="rgba(255,255,255,0.4)" />
                    <stop offset="100%" stopColor="rgba(255,255,255,0)" />
                </linearGradient>
            </defs>

            {/* Main circle */}
            <circle cx="32" cy="32" r="30" fill="url(#gsLogoGrad)" />

            {/* Shine overlay */}
            <ellipse cx="24" cy="22" rx="18" ry="14" fill="url(#gsLogoShine)" opacity="0.5" />

            {/* Heart icon */}
            <path
                d="M32 48C32 48 16 38 16 28C16 22 20 18 25 18C28 18 30.5 20 32 22.5C33.5 20 36 18 39 18C44 18 48 22 48 28C48 38 32 48 32 48Z"
                fill="white"
                fillOpacity="0.95"
            />

            {/* GS Text */}
            <text
                x="32"
                y="37"
                textAnchor="middle"
                dominantBaseline="central"
                fill="#7C3AED"
                fontWeight="900"
                fontSize="14"
                fontFamily="Outfit, system-ui, sans-serif"
            >
                GS
            </text>
        </svg>
    );
}

'use client';

export default function Logo({ size = 32, className = '' }) {
    const width = Math.round(size * 6.5);

    return (
        <>
            <img
                src="/brand/genuine-sugarmummies-wordmark-white.png"
                alt="Genuine Sugarmummies"
                width={width}
                height={size}
                className={`brand-logo-light shrink-0 ${className}`}
                style={{ width, height: size }}
            />
            <img
                src="/brand/genuine-sugarmummies-wordmark.png"
                alt="Genuine Sugarmummies"
                width={width}
                height={size}
                className={`brand-logo-dark shrink-0 ${className}`}
                style={{ width, height: size }}
            />
        </>
    );
}

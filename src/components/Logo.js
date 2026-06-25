'use client';

export default function Logo({ size = 32, className = '' }) {
    const width = Math.round(size * 4.8);

    return (
        <img
            src="/gs-logo.png"
            alt="Genuine Sugar Mummies"
            width={width}
            height={size}
            className={`shrink-0 object-contain ${className}`}
            style={{ width, height: size, maxWidth: '82vw' }}
        />
    );
}
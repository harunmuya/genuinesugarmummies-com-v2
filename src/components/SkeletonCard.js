export default function SkeletonCard() {
    return (
        <div className="relative w-full max-w-sm mx-auto" style={{ aspectRatio: '3/4' }}>
            <div className="absolute inset-0 rounded-3xl overflow-hidden card-shadow bg-bg-card">
                {/* Image skeleton */}
                <div className="absolute inset-0 shimmer" />

                {/* Bottom info skeleton */}
                <div className="absolute bottom-0 left-0 right-0 p-6 space-y-3">
                    <div className="h-7 w-48 rounded-lg shimmer" />
                    <div className="h-4 w-32 rounded-lg shimmer" />
                    <div className="h-4 w-full rounded-lg shimmer" />
                    <div className="h-4 w-3/4 rounded-lg shimmer" />
                </div>
            </div>
        </div>
    );
}

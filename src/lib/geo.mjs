function coordinate(value, min, max) {
    if (value === null || value === undefined || value === '') return null;
    const number = Number(value);
    return Number.isFinite(number) && number >= min && number <= max ? number : null;
}

export function distanceKm(a, b) {
    if (!a || !b) return null;
    const lat1 = coordinate(a.latitude, -90, 90);
    const lon1 = coordinate(a.longitude, -180, 180);
    const lat2 = coordinate(b.latitude, -90, 90);
    const lon2 = coordinate(b.longitude, -180, 180);
    if ([lat1, lon1, lat2, lon2].some((value) => value === null)) return null;

    const toRad = (value) => value * Math.PI / 180;
    const dLat = toRad(lat2 - lat1);
    const dLon = toRad(lon2 - lon1);
    const arc = Math.sin(dLat / 2) ** 2
        + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
    return Math.round(6371 * 2 * Math.atan2(Math.sqrt(arc), Math.sqrt(1 - arc)));
}

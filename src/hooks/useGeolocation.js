'use client';

import { useState, useEffect, useCallback } from 'react';

const LOCATION_STORAGE_KEY = 'gscom_location';

function getStoredLocation() {
    if (typeof window === 'undefined') return null;
    try {
        const val = localStorage.getItem(LOCATION_STORAGE_KEY);
        return val ? JSON.parse(val) : null;
    } catch { return null; }
}

function saveLocation(coords) {
    if (typeof window === 'undefined') return;
    try {
        localStorage.setItem(LOCATION_STORAGE_KEY, JSON.stringify(coords));
    } catch { }
}

export function useGeolocation() {
    const [location, setLocation] = useState(null);
    const [error, setError] = useState(null);
    const [loading, setLoading] = useState(false);

    useEffect(() => {
        const saved = getStoredLocation();
        if (saved) {
            setLocation(saved);
        }
    }, []);

    const requestLocation = useCallback(async () => {
        if (!navigator.geolocation) {
            setError('Geolocation is not supported by your browser');
            return;
        }

        setLoading(true);
        setError(null);

        navigator.geolocation.getCurrentPosition(
            (position) => {
                const coords = {
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                };
                setLocation(coords);
                saveLocation(coords);
                setLoading(false);
            },
            (err) => {
                setError(err.message);
                setLoading(false);
            },
            {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 300000,
            }
        );
    }, []);

    return { location, error, loading, requestLocation };
}

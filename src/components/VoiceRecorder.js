'use client';

import { useEffect, useRef, useState } from 'react';
import { Mic, StopCircle, X } from 'lucide-react';

function supportedMimeType() {
    const types = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/mp4'];
    if (typeof MediaRecorder === 'undefined') return '';
    return types.find((type) => MediaRecorder.isTypeSupported(type)) || '';
}

function secondsText(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${String(secs).padStart(2, '0')}`;
}

const AUDIO_CONSTRAINTS = {
    echoCancellation: true,
    noiseSuppression: true,
    autoGainControl: true,
    channelCount: 1,
    sampleRate: 48000,
    sampleSize: 16,
};

export default function VoiceRecorder({ disabled = false, onRecorded, onError }) {
    const [recording, setRecording] = useState(false);
    const [seconds, setSeconds] = useState(0);
    const recorderRef = useRef(null);
    const streamRef = useRef(null);
    const chunksRef = useRef([]);
    const startedAtRef = useRef(0);
    const cancelledRef = useRef(false);

    useEffect(() => {
        if (!recording) return undefined;
        const timer = window.setInterval(() => {
            setSeconds(Math.floor((Date.now() - startedAtRef.current) / 1000));
        }, 250);
        return () => window.clearInterval(timer);
    }, [recording]);

    useEffect(() => () => stopTracks(), []);

    function stopTracks() {
        streamRef.current?.getTracks?.().forEach((track) => track.stop());
        streamRef.current = null;
    }

    async function startRecording(event) {
        event?.preventDefault?.();
        if (disabled || recording) return;
        if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
            onError?.('Voice notes are not supported on this browser.');
            return;
        }
        try {
            cancelledRef.current = false;
            chunksRef.current = [];
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: AUDIO_CONSTRAINTS,
            });
            streamRef.current = stream;
            const mimeType = supportedMimeType();
            const recorder = new MediaRecorder(stream, { ...(mimeType ? { mimeType } : {}), audioBitsPerSecond: 128000 });
            recorderRef.current = recorder;
            recorder.ondataavailable = (item) => {
                if (item.data?.size) chunksRef.current.push(item.data);
            };
            recorder.onstop = () => {
                const durationSeconds = Math.max(0, Math.round((Date.now() - startedAtRef.current) / 1000));
                const blob = new Blob(chunksRef.current, { type: recorder.mimeType || 'audio/webm' });
                stopTracks();
                setRecording(false);
                setSeconds(0);
                if (!cancelledRef.current && durationSeconds >= 1 && blob.size > 0) {
                    const reader = new FileReader();
                    reader.onload = (readerEvent) => onRecorded?.({
                        url: readerEvent.target?.result || '',
                        blob,
                        durationSeconds,
                    });
                    reader.readAsDataURL(blob);
                }
            };
            startedAtRef.current = Date.now();
            setSeconds(0);
            setRecording(true);
            recorder.start(100);
        } catch {
            stopTracks();
            setRecording(false);
            onError?.('Allow microphone permission to record a voice note.');
        }
    }

    function stopRecording(event) {
        event?.preventDefault?.();
        if (!recording) return;
        try {
            if (recorderRef.current?.state !== 'inactive') recorderRef.current.stop();
        } catch {
            stopTracks();
            setRecording(false);
        }
    }

    function cancelRecording(event) {
        event?.preventDefault?.();
        cancelledRef.current = true;
        stopRecording(event);
    }

    return (
        <div className="relative">
            <button
                type="button"
                disabled={disabled}
                onPointerDown={startRecording}
                onPointerUp={stopRecording}
                onPointerCancel={cancelRecording}
                onKeyDown={(event) => {
                    if (event.code === 'Space' || event.code === 'Enter') startRecording(event);
                }}
                onKeyUp={(event) => {
                    if (event.code === 'Space' || event.code === 'Enter') stopRecording(event);
                }}
                className={`w-10 h-10 rounded-2xl flex items-center justify-center transition ${recording ? 'bg-danger text-white animate-pulse' : 'bg-sky-100 text-sky-700'} disabled:opacity-50`}
                aria-label={recording ? 'Release to send voice note preview' : 'Hold to record voice note'}
                title={recording ? 'Release to attach voice note' : 'Hold to record'}
            >
                {recording ? <StopCircle size={17} /> : <Mic size={17} />}
            </button>
            {recording && (
                <div className="absolute bottom-12 right-0 z-40 w-56 rounded-2xl bg-bg-card p-3 shadow-xl ring-1 ring-danger/15">
                    <div className="mb-2 flex items-center justify-between gap-2">
                        <span className="inline-flex items-center gap-2 text-xs font-black text-danger">
                            <span className="h-2.5 w-2.5 rounded-full bg-danger animate-pulse" />
                            Recording {secondsText(seconds)}
                        </span>
                        <button type="button" onPointerDown={cancelRecording} className="h-7 w-7 rounded-full bg-danger/10 text-danger flex items-center justify-center" aria-label="Cancel recording">
                            <X size={13} />
                        </button>
                    </div>
                    <div className="flex h-8 items-end gap-1">
                        {Array.from({ length: 18 }).map((_, index) => (
                            <span key={index} className="w-1 rounded-full bg-sky-500/70 animate-pulse" style={{ height: `${8 + ((index * 7) % 22)}px`, animationDelay: `${index * 0.04}s` }} />
                        ))}
                    </div>
                    <p className="mt-2 text-[10px] font-bold text-text-muted">Release to attach. Tap X to cancel.</p>
                </div>
            )}
        </div>
    );
}

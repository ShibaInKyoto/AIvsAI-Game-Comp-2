"""Small numpy synthesis toolkit used to generate every sound in FATHOM.

Everything works on float32/float64 numpy arrays at SR samples per second.
Stereo signals are arrays of shape (n, 2).
"""
from __future__ import annotations

import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
RNG = np.random.default_rng(1234)


def seconds(n: float) -> int:
    return int(n * SR)


def t_axis(duration: float) -> np.ndarray:
    return np.arange(seconds(duration)) / SR


# --- Oscillators -----------------------------------------------------------------

def phase_from_freq(freq) -> np.ndarray:
    """Phase (radians) for a constant or per-sample frequency array."""
    return 2.0 * np.pi * np.cumsum(freq) / SR


def sine(freq, duration: float | None = None, phase: float = 0.0) -> np.ndarray:
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t_axis(duration) + phase)
    return np.sin(phase_from_freq(freq) + phase)


def additive(freq, harmonics: list[float], duration: float | None = None) -> np.ndarray:
    """Sum of harmonics with the given amplitudes (index 0 = fundamental)."""
    ph = 2 * np.pi * freq * t_axis(duration) if np.isscalar(freq) else phase_from_freq(freq)
    out = np.zeros_like(ph)
    for i, a in enumerate(harmonics):
        if a != 0.0:
            out += a * np.sin(ph * (i + 1))
    return out


def saw(freq, duration: float | None = None, n_harm: int = 24) -> np.ndarray:
    f0 = freq if np.isscalar(freq) else float(np.mean(freq))
    n = max(1, min(n_harm, int(SR / 2 / max(f0, 1.0))))
    return additive(freq, [((-1) ** k) / (k + 1) for k in range(n)], duration) * 0.6


def square(freq, duration: float | None = None, n_harm: int = 15) -> np.ndarray:
    harm = [1.0 / (k + 1) if k % 2 == 0 else 0.0 for k in range(n_harm)]
    return additive(freq, harm, duration) * 0.7


def noise(duration: float, color: str = "white") -> np.ndarray:
    n = seconds(duration)
    w = RNG.standard_normal(n)
    if color == "white":
        return w * 0.3
    spec = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1.0
    if color == "pink":
        spec /= np.sqrt(f)
    elif color == "brown":
        spec /= f
    out = np.fft.irfft(spec, n)
    return out / (np.max(np.abs(out)) + 1e-9) * 0.5


def fm(carrier: float, ratio: float, index, duration: float) -> np.ndarray:
    t = t_axis(duration)
    mod = np.sin(2 * np.pi * carrier * ratio * t)
    return np.sin(2 * np.pi * carrier * t + index * mod)


# --- Envelopes ---------------------------------------------------------------------

def env_exp(duration: float, decay: float, attack: float = 0.002) -> np.ndarray:
    t = t_axis(duration)
    e = np.exp(-t / max(decay, 1e-4))
    if attack > 0:
        e *= np.clip(t / attack, 0, 1)
    return e


def env_adsr(duration: float, a: float, d: float, s: float, r: float) -> np.ndarray:
    n = seconds(duration)
    t = np.arange(n) / SR
    e = np.ones(n) * s
    e = np.where(t < a, t / max(a, 1e-6), e)
    e = np.where((t >= a) & (t < a + d), 1 - (1 - s) * (t - a) / max(d, 1e-6), e)
    rel_start = max(duration - r, a + d)
    e = np.where(t >= rel_start, s * np.clip(1 - (t - rel_start) / max(r, 1e-6), 0, 1), e)
    return e


def lerp_env(points: list[tuple[float, float]], duration: float) -> np.ndarray:
    t = t_axis(duration)
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


# --- Filters (frequency domain, offline) ------------------------------------------

def fft_filter(x: np.ndarray, response) -> np.ndarray:
    """Applies a zero-phase magnitude response(f_hz) -> gain."""
    if x.ndim == 2:
        return np.stack([fft_filter(x[:, c], response) for c in range(x.shape[1])], axis=1)
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(spec * response(f), n)


def lowpass(x: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * order)))


def highpass(x: np.ndarray, cutoff: float, order: float = 2.0) -> np.ndarray:
    return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x: np.ndarray, center: float, q: float = 2.0) -> np.ndarray:
    bw = center / q
    return fft_filter(x, lambda f: np.exp(-0.5 * ((f - center) / bw) ** 2))


def one_pole_lowpass_sweep(x: np.ndarray, cutoffs: np.ndarray) -> np.ndarray:
    """Time-varying one-pole lowpass (python loop, use for short sounds)."""
    out = np.zeros_like(x)
    y = 0.0
    a = 1.0 - np.exp(-2 * np.pi * np.asarray(cutoffs) / SR)
    for i in range(len(x)):
        y += a[i] * (x[i] - y)
        out[i] = y
    return out


# --- Space -----------------------------------------------------------------------------

def reverb_ir(duration: float, decay: float, cutoff: float = 3000.0, seed: int = 7) -> np.ndarray:
    rng = np.random.default_rng(seed)
    n = seconds(duration)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-t / decay)[:, None]
    ir = lowpass(ir, cutoff, 1.0)
    ir[: seconds(0.01)] *= np.linspace(0, 1, seconds(0.01))[:, None]
    return ir / np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True) + 1e-9)


def convolve(x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    """FFT convolution; x mono or stereo, ir stereo. Output stereo, len(x)+len(ir)."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    n = len(x) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    out = np.zeros((n, 2))
    for c in range(2):
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], size) * np.fft.rfft(ir[:, c], size), size)[:n]
    return out


def wet_dry(x: np.ndarray, ir: np.ndarray, wet: float) -> np.ndarray:
    st = to_stereo(x)
    rev = convolve(st, ir)
    out = np.zeros_like(rev)
    out[: len(st)] += st * (1 - wet * 0.5)
    out += rev * wet
    return out


def to_stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    if x.ndim == 2:
        return x
    l = math.cos((pan + 1) * math.pi / 4)
    r = math.sin((pan + 1) * math.pi / 4)
    return np.stack([x * l * 1.414, x * r * 1.414], axis=1)


def pad_to(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    shape = (n - len(x),) + x.shape[1:]
    return np.concatenate([x, np.zeros(shape)], axis=0)


def mix(*signals: np.ndarray) -> np.ndarray:
    n = max(len(s) for s in signals)
    stereo = any(s.ndim == 2 for s in signals)
    out = np.zeros((n, 2)) if stereo else np.zeros(n)
    for s in signals:
        s2 = to_stereo(s) if stereo else s
        out[: len(s2)] += s2
    return out


def place(buf: np.ndarray, sig: np.ndarray, start: float, wrap: bool = False) -> None:
    """Adds sig into buf at time start (seconds). With wrap, overflow loops around."""
    i = seconds(start)
    n = len(buf)
    sig = to_stereo(sig) if buf.ndim == 2 else sig
    end = i + len(sig)
    if not wrap:
        if i >= n:
            return
        buf[i:min(end, n)] += sig[: min(end, n) - i]
        return
    pos = 0
    while pos < len(sig):
        j = (i + pos) % n
        take = min(n - j, len(sig) - pos)
        buf[j:j + take] += sig[pos:pos + take]
        pos += take


def soft_clip(x: np.ndarray, drive: float = 1.0) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def normalize(x: np.ndarray, peak: float = 0.89) -> np.ndarray:
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    x = x.copy()
    if fade_in > 0:
        k = min(seconds(fade_in), len(x))
        ramp = np.linspace(0, 1, k)
        x[:k] *= ramp[:, None] if x.ndim == 2 else ramp
    if fade_out > 0:
        k = min(seconds(fade_out), len(x))
        ramp = np.linspace(1, 0, k)
        x[-k:] *= ramp[:, None] if x.ndim == 2 else ramp
    return x


def trim_silence(x: np.ndarray, threshold: float = 1e-4) -> np.ndarray:
    a = np.abs(x) if x.ndim == 1 else np.max(np.abs(x), axis=1)
    idx = np.nonzero(a > threshold)[0]
    if len(idx) == 0:
        return x
    return x[: idx[-1] + seconds(0.02)]


# --- Music helpers -----------------------------------------------------------------------

def midi_to_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def formant_amps(f0: float, formants: list[tuple[float, float, float]], n: int) -> list[float]:
    """Harmonic amplitudes shaped by vowel formants [(freq, bandwidth, gain)]."""
    amps = []
    for k in range(1, n + 1):
        fk = f0 * k
        if fk > SR / 2:
            amps.append(0.0)
            continue
        a = sum(g * math.exp(-0.5 * ((fk - f) / bw) ** 2) for f, bw, g in formants)
        amps.append(a / math.sqrt(k))
    return amps


VOWELS = {
    "a": [(800, 90, 1.0), (1150, 110, 0.5), (2900, 160, 0.25)],
    "o": [(450, 80, 1.0), (800, 90, 0.4), (2830, 140, 0.15)],
    "u": [(325, 60, 1.0), (700, 80, 0.3), (2530, 140, 0.1)],
    "e": [(400, 70, 1.0), (1700, 120, 0.4), (2600, 150, 0.2)],
}


# --- Output -----------------------------------------------------------------------------

def write_ogg(path: Path, x: np.ndarray, quality: int = 5) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    st = to_stereo(x) if x.ndim == 1 else x
    data = (np.clip(st, -1, 1) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    with wave.open(str(tmp_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp_path), "-c:a", "libvorbis",
                    "-q:a", str(quality), str(path)], check=True)
    tmp_path.unlink()

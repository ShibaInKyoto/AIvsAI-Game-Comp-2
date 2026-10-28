"""Procedural score for FATHOM: one seamless loop per biome plus menu,
boss, defeat and ending cues. Every note is synthesized here."""
from __future__ import annotations

import math

import numpy as np

from synth import (SR, VOWELS, additive, convolve, env_adsr, env_exp, fade, fm, formant_amps, lowpass,
                   midi_to_hz, noise, normalize, phase_from_freq, place, reverb_ir, seconds, sine, soft_clip,
                   t_axis, to_stereo)

HALL = reverb_ir(7.0, 2.6, 2200, seed=11)
DEEP = reverb_ir(9.0, 3.6, 1400, seed=12)


# --- Instruments -------------------------------------------------------------------------

def pad(freq: float, dur: float, brightness: float = 0.35, attack: float = 2.5, release: float = 3.5,
        spread: float = 0.6) -> np.ndarray:
    """Warm detuned pad: three saw-like voices with a soft harmonic rolloff."""
    total = dur + release
    out = np.zeros((seconds(total), 2))
    env = env_adsr(total, attack, 1.0, 0.85, release)
    t = t_axis(total)
    for i, (cents, pan) in enumerate([(-7, -spread), (0, 0.0), (7, spread)]):
        f = freq * 2 ** (cents / 1200)
        harmonics = []
        for k in range(1, 28):
            a = (1.0 / k) * math.exp(-(k * f) / (900 + 4000 * brightness))
            harmonics.append(a if a > 0.004 else 0.0)
        voice = additive(f, harmonics, total)
        voice *= 1.0 + 0.08 * np.sin(2 * np.pi * (0.13 + i * 0.05) * t + i)
        out += to_stereo(voice * env, pan) * 0.33
    return out


def bell(freq: float, decay: float = 3.5, ratio: float = 3.5, index: float = 2.5) -> np.ndarray:
    dur = decay * 1.6
    e = env_exp(dur, decay * 0.45, 0.003)
    idx = index * env_exp(dur, decay * 0.15)
    tone = fm(freq, ratio, idx, dur) * e
    tone += sine(freq * 2.0, dur) * env_exp(dur, decay * 0.2) * 0.15
    return tone * 0.5


def pluck(freq: float, decay: float = 1.6) -> np.ndarray:
    dur = decay * 1.5
    out = np.zeros(seconds(dur))
    for k in range(1, 9):
        if freq * k > SR / 2:
            break
        out += sine(freq * k, dur) * env_exp(dur, decay / (1 + 0.6 * k), 0.002) / k
    return out * 0.6


def sub_drone(freq: float, dur: float) -> np.ndarray:
    total = dur + 4.0
    s = sine(freq, total) + sine(freq * 2, total) * 0.25 + sine(freq * 3, total) * 0.08
    return s * env_adsr(total, 4.0, 1.0, 0.9, 4.0) * 0.6


def choir(freq: float, dur: float, vowel: str = "a", attack: float = 1.8) -> np.ndarray:
    total = dur + 3.0
    out = np.zeros((seconds(total), 2))
    t = t_axis(total)
    env = env_adsr(total, attack, 1.0, 0.85, 3.0)
    for i, (cents, pan) in enumerate([(-9, -0.5), (0, 0.0), (8, 0.5)]):
        f0 = freq * 2 ** (cents / 1200)
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * (5.0 + i * 0.4) * t + i * 1.7)
        ph = phase_from_freq(f0 * vib)
        amps = formant_amps(f0, VOWELS[vowel], 40)
        voice = np.zeros(len(t))
        for k, a in enumerate(amps):
            if a > 0.003:
                voice += a * np.sin(ph * (k + 1))
        out += to_stereo(voice * env, pan) * 0.3
    return out


def whale(f0: float, dur: float) -> np.ndarray:
    t = np.linspace(0, 1, seconds(dur))
    f = f0 * (1 + 0.6 * np.sin(np.pi * t) ** 2 - 0.25 * t) * (1 + 0.01 * np.sin(2 * np.pi * 6 * t * dur))
    ph = phase_from_freq(f)
    tone = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return lowpass(tone * env_adsr(dur, dur * 0.3, 0.2, 0.8, dur * 0.4), 1500) * 0.5


def thump(freq: float = 55) -> np.ndarray:
    d = 0.6
    f = freq * (1 + 1.5 * np.exp(-t_axis(d) * 40))
    return sine(f) * env_exp(d, 0.12, 0.002)


def ping(freq: float = 1250) -> np.ndarray:
    d = 2.0
    return sine(freq, d) * env_exp(d, 0.35, 0.004) * 0.35


# --- Arrangement helpers ------------------------------------------------------------------

def chord_notes(root: int, intervals: list[int]) -> list[float]:
    return [midi_to_hz(root + i) for i in intervals]


def render_loop(length: float, events: list[tuple[float, np.ndarray]], ir: np.ndarray, wet: float) -> np.ndarray:
    """Places events into a seamless loop; tails (and reverb) wrap around."""
    dry = np.zeros((seconds(length), 2))
    for start, sig in events:
        place(dry, sig, start % length, wrap=True)
    wet_sig = convolve(dry, ir)
    out = dry * (1 - wet * 0.4)
    place(out, wet_sig * wet, 0.0, wrap=True)
    return out


def render_once(length: float, events: list[tuple[float, np.ndarray]], ir: np.ndarray, wet: float) -> np.ndarray:
    dry = np.zeros((seconds(length), 2))
    for start, sig in events:
        place(dry, sig, start)
    wet_sig = convolve(dry, ir)[: len(dry)]
    return dry * (1 - wet * 0.4) + wet_sig * wet


def melody(rng: np.random.Generator, scale: list[int], root: int, count: int, start_degree: int = 0) -> list[int]:
    """Random walk over a scale, favouring steps."""
    notes = []
    deg = start_degree
    for _ in range(count):
        deg += int(rng.choice([-2, -1, -1, 0, 1, 1, 2, 3, -3]))
        deg = max(-2, min(len(scale) + 4, deg))
        octave, idx = divmod(deg, len(scale))
        notes.append(root + scale[idx] + 12 * octave)
    return notes


MINOR_PENT = [0, 3, 5, 7, 10]
MAJOR_PENT = [0, 2, 4, 7, 9]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]


# --- Tracks ---------------------------------------------------------------------------------

def title() -> np.ndarray:
    rng = np.random.default_rng(1)
    length = 96.0
    chords = [(50, [0, 7, 14, 15]), (46, [0, 7, 11, 16]), (43, [0, 7, 10, 14, 17]), (45, [0, 5, 7, 10])]
    ev = []
    for i in range(8):
        root, iv = chords[i % 4]
        for f in chord_notes(root, iv):
            ev.append((i * 12.0, pad(f, 12.0, 0.3)))
        ev.append((i * 12.0, to_stereo(sub_drone(midi_to_hz(root - 12), 12.0))))
    tune = melody(rng, MINOR_PENT, 74, 40)
    t = 2.0
    for n in tune:
        ev.append((t, to_stereo(bell(midi_to_hz(n), 3.0), float(rng.uniform(-0.5, 0.5)))))
        t += float(rng.choice([1.5, 1.5, 3.0, 2.25, 4.5]))
        if t > length - 2:
            break
    for k in range(8):
        ev.append((k * 12.0 + 6.0, to_stereo(ping(1250), 0.3)))
    return normalize(render_loop(length, ev, HALL, 0.5), 0.8)


def shelf() -> np.ndarray:
    rng = np.random.default_rng(2)
    length = 96.0
    chords = [(57, [0, 4, 7, 11, 14]), (54, [0, 3, 7, 10, 17]), (50, [0, 4, 7, 11, 18]), (52, [0, 5, 7, 9])]
    ev = []
    beat = 60.0 / 76.0 / 2.0
    for i in range(8):
        root, iv = chords[i % 4]
        for f in chord_notes(root, iv[:4]):
            ev.append((i * 12.0, pad(f, 12.0, 0.45, 2.0, 3.0)))
        ev.append((i * 12.0, to_stereo(sub_drone(midi_to_hz(root - 24), 12.0) * 0.8)))
        arp = [root + 12 + x for x in iv] + [root + 24 + iv[1]]
        n_steps = int(12.0 / beat)
        for s in range(n_steps):
            if rng.random() < 0.72:
                note = arp[(s * 2 + (s // 4)) % len(arp)]
                ev.append((i * 12.0 + s * beat, to_stereo(pluck(midi_to_hz(note), 1.2) * 0.5, math.sin(s * 0.7) * 0.6)))
    tune = melody(rng, MAJOR_PENT, 81, 24)
    t = 6.0
    for n in tune:
        ev.append((t, to_stereo(bell(midi_to_hz(n), 2.5, 1.4, 1.5) * 0.6, float(rng.uniform(-0.4, 0.4)))))
        t += float(rng.choice([3.0, 4.5, 6.0]))
        if t > length - 2:
            break
    return normalize(render_loop(length, ev, HALL, 0.42), 0.75)


def reef() -> np.ndarray:
    rng = np.random.default_rng(3)
    length = 96.0
    chords = [(52, [0, 7, 10, 14, 15]), (48, [0, 7, 11, 14]), (45, [0, 7, 10, 15, 17]), (47, [0, 5, 7, 10])]
    ev = []
    for i in range(8):
        root, iv = chords[i % 4]
        for f in chord_notes(root, iv):
            ev.append((i * 12.0, pad(f, 12.0, 0.25, 3.0, 4.0)))
        ev.append((i * 12.0, to_stereo(sub_drone(midi_to_hz(root - 24), 12.0))))
        for s in range(6):
            note = root + 24 + iv[(s * 3) % len(iv)]
            ev.append((i * 12.0 + s * 2.0 + float(rng.uniform(0, 0.4)),
                       to_stereo(bell(midi_to_hz(note), 3.5, 3.5, 1.8) * 0.4, float(rng.uniform(-0.7, 0.7)))))
    return normalize(render_loop(length, ev, DEEP, 0.55), 0.75)


def midnight() -> np.ndarray:
    rng = np.random.default_rng(4)
    length = 120.0
    ev = []
    root = 37
    for i in range(4):
        ev.append((i * 30.0, to_stereo(sub_drone(midi_to_hz(root - 12), 30.0))))
        ev.append((i * 30.0, pad(midi_to_hz(root), 30.0, 0.08, 6.0, 6.0) * 0.8))
        ev.append((i * 30.0, pad(midi_to_hz(root + 7), 30.0, 0.06, 8.0, 6.0) * 0.6))
        if i % 2 == 1:
            ev.append((i * 30.0 + 10.0, pad(midi_to_hz(root + 3 + 12), 14.0, 0.1, 5.0, 5.0) * 0.5))
    t = 4.0
    while t < length - 3:
        note = root + 12 + int(rng.choice([0, 3, 7, 8, 10, 12, 15]))
        ev.append((t, to_stereo(pluck(midi_to_hz(note), 3.0) * 0.6, float(rng.uniform(-0.6, 0.6)))))
        t += float(rng.uniform(4.0, 9.0))
    for k in range(3):
        ev.append((15.0 + k * 38.0, to_stereo(whale(float(rng.uniform(180, 320)), 5.5) * 0.7, float(rng.uniform(-0.8, 0.8)))))
    return normalize(render_loop(length, ev, DEEP, 0.6), 0.7)


def vents() -> np.ndarray:
    rng = np.random.default_rng(5)
    length = 96.0
    ev = []
    root = 41
    for i in range(8):
        ev.append((i * 12.0, to_stereo(sub_drone(midi_to_hz(root - 12), 12.0) * 1.1)))
        ev.append((i * 12.0, pad(midi_to_hz(root + (1 if i % 4 == 3 else 0)), 12.0, 0.18, 2.0, 3.0) * 0.8))
        ev.append((i * 12.0, pad(midi_to_hz(root + 7), 12.0, 0.12, 2.0, 3.0) * 0.5))
    beat = 1.0
    for b in range(int(length / beat)):
        ev.append((b * beat, to_stereo(thump(46) * 0.9)))
        if b % 2 == 1:
            ev.append((b * beat + 0.25, to_stereo(thump(46) * 0.5)))
    t = 3.0
    while t < length - 3:
        f = midi_to_hz(root + 24 + int(rng.choice([0, 1, 5, 7, 8])))
        ev.append((t, to_stereo(bell(f, 2.0, 2.76, 3.0) * 0.35, float(rng.uniform(-0.7, 0.7)))))
        t += float(rng.choice([2.0, 3.0, 4.0]))
    return normalize(render_loop(length, ev, HALL, 0.45), 0.8)


CHOIR_MOTIF = [71, 66, 67, 62]


def hadal() -> np.ndarray:
    rng = np.random.default_rng(6)
    length = 112.0
    ev = []
    root = 35
    vowels = ["a", "o", "u", "o"]
    for i in range(8):
        dur = 14.0
        ev.append((i * dur, to_stereo(sub_drone(midi_to_hz(root - 12), dur))))
        for j, iv in enumerate([0, 7, 10 if i % 2 else 12]):
            ev.append((i * dur, choir(midi_to_hz(root + 12 + iv), dur, vowels[(i + j) % 4], 3.0) * 0.6))
    for k in range(4):
        t0 = k * 28.0 + 7.0
        for j, n in enumerate(CHOIR_MOTIF):
            ev.append((t0 + j * 1.6, choir(midi_to_hz(n), 1.8 if j < 3 else 4.0, "o", 0.25) * 0.5))
    for k in range(5):
        ev.append((float(rng.uniform(0, length)), to_stereo(ping(float(rng.choice([1250, 940]))) * 0.5, float(rng.uniform(-1, 1)))))
    return normalize(render_loop(length, ev, DEEP, 0.6), 0.8)


def boss() -> np.ndarray:
    length = 64.0
    ev = []
    root = 35
    beat = 60.0 / 92.0
    for b in range(int(length / beat)):
        ev.append((b * beat, to_stereo(thump(44))))
        if b % 4 == 2:
            ev.append((b * beat, to_stereo(thump(60) * 0.6)))
    for i in range(4):
        dur = 16.0
        ev.append((i * dur, to_stereo(sub_drone(midi_to_hz(root - 12), dur) * 1.2)))
        ev.append((i * dur, choir(midi_to_hz(root + 12), dur, "a", 1.0) * 0.6))
        ev.append((i * dur, choir(midi_to_hz(root + 18 + (1 if i % 2 else 0)), dur, "o", 1.0) * 0.5))
        for j, n in enumerate(CHOIR_MOTIF):
            ev.append((i * dur + 4.0 + j * beat * 2, choir(midi_to_hz(n + 12), beat * 2.2, "a", 0.08) * 0.45))
    # Thumps and drones are dense; leave headroom so the loudness matches the other cues.
    return normalize(soft_clip(normalize(render_loop(length, ev, HALL, 0.4), 0.9), 1.2), 0.42)


def lair() -> np.ndarray:
    """The Blind Mother's lair: a slow double heartbeat under grinding low
    drones, a minor-ninth swell that never resolves, and stray tolling bells."""
    rng = np.random.default_rng(21)
    length = 56.0
    beat = 60.0 / 76.0
    root = 33
    ev = []
    for b in range(int(length / beat)):
        ev.append((b * beat, to_stereo(thump(40))))
        ev.append((b * beat + 0.18, to_stereo(thump(48) * 0.55)))
    for i in range(4):
        dur = 14.0
        ev.append((i * dur, to_stereo(sub_drone(midi_to_hz(root - 12), dur))))
        ev.append((i * dur, pad(midi_to_hz(root), dur, 0.12, 3.0, 4.0) * 0.8))
        ev.append((i * dur + 3.0, pad(midi_to_hz(root + 13 + i % 2), dur - 4.0, 0.25, 5.0, 3.0) * 0.45))
    for _ in range(10):
        t0 = float(rng.uniform(0, length - 4))
        n = root + 24 + int(rng.choice([0, 1, 6, 7]))
        ev.append((t0, to_stereo(bell(midi_to_hz(n), 2.5, 2.7, 3.5) * 0.35, float(rng.uniform(-0.8, 0.8)))))
    return normalize(soft_clip(normalize(render_loop(length, ev, DEEP, 0.5), 0.9), 1.2), 0.75)


def angler() -> np.ndarray:
    """The Lamplighter's lair: a glassy lure motif spiralling round a tritone
    over a slow soft pulse, low pads and swells that open like a mouth."""
    length = 48.0
    beat = 60.0 / 84.0
    root = 40
    motif = [0, 6, 11, 14, 11, 6]
    ev = []
    for b in range(int(length / beat)):
        n = root + 24 + motif[b % len(motif)] + (1 if (b // 24) % 2 else 0)
        ev.append((b * beat, to_stereo(bell(midi_to_hz(n), 2.2, 3.5, 1.4) * 0.28, float(np.sin(b * 0.7) * 0.6))))
        if b % 2 == 0:
            ev.append((b * beat, to_stereo(thump(42) * 0.5)))
    for i in range(4):
        dur = 12.0
        ev.append((i * dur, to_stereo(sub_drone(midi_to_hz(root - 12), dur))))
        ev.append((i * dur, pad(midi_to_hz(root), dur, 0.2, 2.5, 3.5) * 0.7))
        ev.append((i * dur, pad(midi_to_hz(root + 6 + (1 if i % 2 else 0)), dur, 0.3, 3.0, 3.0) * 0.45))
        ev.append((i * dur + 6.0, pad(midi_to_hz(root - 5), 6.0, 0.1, 3.0, 2.5) * 0.6))
    return normalize(soft_clip(normalize(render_loop(length, ev, DEEP, 0.5), 0.9), 1.2), 0.6)


def loss() -> np.ndarray:
    ev = []
    for f in chord_notes(50, [0, 3, 7, 10]):
        ev.append((0.0, pad(f, 4.0, 0.2, 0.6, 4.0)))
    ev.append((0.0, to_stereo(sub_drone(midi_to_hz(38), 4.0))))
    for j, n in enumerate([74, 72, 69, 65, 62]):
        ev.append((0.5 + j * 0.9, to_stereo(bell(midi_to_hz(n), 3.0) * 0.6)))
    return normalize(fade(render_once(14.0, ev, DEEP, 0.55), 0.0, 3.0), 0.75)


def ending() -> np.ndarray:
    rng = np.random.default_rng(8)
    length = 72.0
    ev = []
    chords = [(50, [0, 7, 14, 16]), (55, [0, 4, 7, 14]), (47, [0, 7, 10, 15]), (54, [0, 3, 7, 10]),
              (55, [0, 4, 7, 11]), (52, [0, 3, 7, 14]), (45, [0, 5, 7, 14]), (50, [0, 4, 7, 14, 19])]
    for i, (root, iv) in enumerate(chords):
        for f in chord_notes(root, iv):
            ev.append((i * 8.0, pad(f, 8.0, 0.4, 2.0, 4.0) * 0.8))
        ev.append((i * 8.0, choir(midi_to_hz(root + 12), 8.0, "a" if i % 2 == 0 else "o", 2.0) * 0.4))
    t = 4.0
    for n in melody(rng, MAJOR_PENT, 74, 30):
        ev.append((t, to_stereo(bell(midi_to_hz(n), 3.0, 1.4, 1.2) * 0.6, float(rng.uniform(-0.5, 0.5)))))
        t += float(rng.choice([1.0, 2.0, 2.0, 3.0]))
        if t > length - 8:
            break
    return normalize(fade(render_once(length + 6.0, ev, HALL, 0.5), 2.0, 6.0), 0.8)


def ambience() -> np.ndarray:
    """Seamless underwater bed: deep rumble, slow swells, distant bubbles."""
    rng = np.random.default_rng(9)
    length = 60.0
    n = seconds(length)
    base = lowpass(noise(length, "brown"), 220) * 0.8
    t = t_axis(length)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / length * 3) * np.sin(2 * np.pi * t / length * 2 + 1)
    bed = to_stereo(base * swell)
    ev = []
    for _ in range(14):
        start = float(rng.uniform(0, length))
        f = float(rng.uniform(250, 900))
        d = float(rng.uniform(0.04, 0.08))
        blip = sine(f * (1 + 0.8 * np.linspace(0, 1, seconds(d)))) * env_exp(d, d * 0.4)
        ev.append((start, to_stereo(blip * 0.12, float(rng.uniform(-1, 1)))))
    loop = render_loop(length, ev, DEEP, 0.7)
    # Crossfade the bed against itself so it loops cleanly.
    k = seconds(3.0)
    bed[:k] = bed[:k] * np.linspace(0, 1, k)[:, None] + bed[-k:] * np.linspace(1, 0, k)[:, None]
    bed = bed[:n - k]
    loop = loop[:n - k]
    return normalize(bed + loop, 0.6)


TRACKS = {
    "title": title, "shelf": shelf, "reef": reef, "midnight": midnight, "vents": vents,
    "hadal": hadal, "boss": boss, "lair": lair, "angler": angler, "loss": loss, "ending": ending, "ambience": ambience,
}

"""UI feedback sounds (D-069): search, match found, message sent and propose.
Synthesised here like the exam cues (no third-party audio, no licence), a few
KB each, bundled in apps/mobile/assets/sounds/.

Two voices: a soft marimba (wooden, short) and a glassy chime (longer tail),
both with a tiny room so they feel round instead of beepy.

    python scripts/content/ui_sounds.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "assets" / "sounds"


def _voice(freq: float, ms: int, gain: float, partials: list[tuple[float, float, float]], glide: float = 0.0) -> list[float]:
    """partials: (ratio, amplitude, decay seconds). glide: pitch rise in octaves over the first 60 ms."""
    n = RATE * ms // 1000
    attack = RATE * 3 // 1000
    out = []
    phases = [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        bend = 2 ** (glide * min(1.0, t / 0.06))
        env_a = min(1.0, i / attack)
        tail = min(1.0, (n - 1 - i) / (RATE * 0.01))  # 10 ms fade-out: no click at the end
        s = 0.0
        for k, (ratio, amp, decay) in enumerate(partials):
            phases[k] += 2 * math.pi * freq * ratio * bend / RATE
            s += amp * math.exp(-t / decay) * math.sin(phases[k])
        out.append(gain * env_a * tail * s)
    return out


def marimba(freq: float, ms: int = 320, gain: float = 0.5, glide: float = 0.0) -> list[float]:
    return _voice(freq, ms, gain, [(1.0, 1.0, 0.16), (3.93, 0.32, 0.045), (9.2, 0.08, 0.015)], glide)


def chime(freq: float, ms: int = 700, gain: float = 0.4) -> list[float]:
    return _voice(freq, ms, gain, [(1.0, 1.0, 0.32), (2.0, 0.28, 0.18), (2.76, 0.16, 0.1), (5.4, 0.06, 0.04)])


def mix(*layers: tuple[int, list[float]]) -> list[float]:
    """(offset ms, samples) layered on one track."""
    n = max(RATE * off // 1000 + len(s) for off, s in layers)
    out = [0.0] * n
    for off, s in layers:
        start = RATE * off // 1000
        for i, v in enumerate(s):
            out[start + i] += v
    return out


def room(s: list[float], wet: float = 0.16) -> list[float]:
    """Two short echoes: a touch of space, not a hall."""
    out = s + [0.0] * (RATE * 120 // 1000)
    for ms, g in ((31, wet), (53, wet * 0.6), (79, wet * 0.35)):
        d = RATE * ms // 1000
        for i in range(len(s)):
            out[i + d] += s[i] * g
    return out


def normalise(s: list[float], peak: float) -> list[float]:
    m = max(abs(v) for v in s) or 1.0
    return [v * peak / m for v in s]


def write(name: str, samples: list[float], peak: float = 0.7) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    samples = normalise(room(samples), peak)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in samples))
    print(OUT / name)


G5, A5, B5, C6, D6, E6, G6, A6, C7 = 784.0, 880.0, 987.8, 1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0

# Search: two wooden taps that rise, "let's go".
write("ui_search.wav", mix((0, marimba(G5, 260)), (75, marimba(D6, 380, 0.55, glide=0.04))), 0.65)

# Match found: a bright rising chime arpeggio that rings out, "someone is here!".
write("ui_match.wav", mix(
    (0, chime(C6, 900, 0.35)),
    (70, chime(E6, 860, 0.35)),
    (140, chime(G6, 820, 0.38)),
    (210, chime(C7, 1000, 0.42)),
), 0.72)

# Message sent: a quick upward bloop with a soft wooden tail.
write("ui_sent.wav", mix((0, marimba(A5, 170, 0.6, glide=0.55)), (45, marimba(E6, 140, 0.18))), 0.6)

# Propose: a short strummed major chord, warm and decided.
write("ui_propose.wav", mix((0, marimba(G5, 360)), (28, marimba(B5, 360, 0.45)), (56, marimba(D6, 420, 0.5)), (110, chime(G6, 380, 0.12))), 0.65)

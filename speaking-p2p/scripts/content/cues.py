"""Exam cue sounds (D-058): the beep that opens a speaking window and the soft
one that closes it. Synthesised here (no third-party audio, no licence), a few
KB each, so they ship in the bundle: apps/mobile/assets/sounds/.

    python scripts/content/cues.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[2] / "apps" / "mobile" / "assets" / "sounds"


def tone(freq: float, ms: int, gain: float) -> list[float]:
    n = RATE * ms // 1000
    fade = RATE * 12 // 1000  # 12 ms ramps: no clicks
    out = []
    for i in range(n):
        env = min(1.0, i / fade, (n - 1 - i) / fade)
        # a touch of the octave makes it read as a bell, not a test tone
        s = math.sin(2 * math.pi * freq * i / RATE) + 0.25 * math.sin(4 * math.pi * freq * i / RATE)
        out.append(gain * env * s / 1.25)
    return out


def silence(ms: int) -> list[float]:
    return [0.0] * (RATE * ms // 1000)


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(OUT / name)


# Start: one clear rising pair, "go".
write("cue_start.wav", tone(784, 110, 0.55) + silence(30) + tone(1047, 170, 0.55))
# End: softer, falling and quieter, "time".
write("cue_end.wav", tone(880, 140, 0.28) + silence(30) + tone(659, 220, 0.24))

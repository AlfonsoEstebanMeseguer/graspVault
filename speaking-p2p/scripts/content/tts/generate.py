"""Examiner voice (D-033): renders every exam step with every voice in
content/index.json ("voices") using Kokoro-82M (Apache-2.0) through kokoro-onnx,
locally and for free.

  * Output: content/.audio-build/audio/{voice}/{level}/{examId}/{stepId}.mp3
    (gitignored; upload-r2.ts sends it to the speaking-content bucket).
  * Writes the REAL length into each step's audioMs: the longest voice + a short
    tail, rounded up to 100 ms. The server timeline is built from audioMs, so
    after running this: validate -> sync-catalog -> sync-app, and re-seed
    exam_catalog.

Setup (once, outside the repo):
  python -m venv tts-venv && tts-venv/Scripts/pip install kokoro-onnx soundfile lameenc
  model files: kokoro-v1.0.int8.onnx + voices-v1.0.bin from
  https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0

Usage:
  tts-venv/Scripts/python scripts/content/tts/generate.py <model-dir> [--only-missing] [--shard i/n] [--exam id]

  --shard i/n renders every n-th exam starting at i (run n processes in
  parallel; each exam JSON is written by exactly one of them).
"""
import json
import math
import sys
from pathlib import Path

import lameenc
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = Path(__file__).resolve().parents[3]
CONTENT = ROOT / "content"
OUT = CONTENT / ".audio-build"
TAIL_MS = 250       # breathing room after the last word
SPEED = 0.95        # a touch slower than default: exam pace, learners listening
BITRATE = 64        # kbps mono: clear speech, ~8 KB per second


def mp3(samples: np.ndarray, rate: int) -> bytes:
    enc = lameenc.Encoder()
    enc.set_bit_rate(BITRATE)
    enc.set_in_sample_rate(rate)
    enc.set_channels(1)
    enc.set_quality(2)
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16).tobytes()
    return enc.encode(pcm) + enc.flush()


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    model_dir = Path(sys.argv[1])
    only_missing = "--only-missing" in sys.argv
    args = sys.argv[2:]
    shard, shards = map(int, args[args.index("--shard") + 1].split("/")) if "--shard" in args else (0, 1)
    only_exam = args[args.index("--exam") + 1] if "--exam" in args else None
    kokoro = Kokoro(str(model_dir / "kokoro-v1.0.int8.onnx"), str(model_dir / "voices-v1.0.bin"))
    index = json.loads((CONTENT / "index.json").read_text(encoding="utf-8"))
    voices = index["voices"]
    for n, entry in enumerate(index["exams"]):
        if n % shards != shard or (only_exam and entry["id"] != only_exam):
            continue
        path = CONTENT / "exams" / entry["level"] / f"{entry['id']}.json"
        exam = json.loads(path.read_text(encoding="utf-8"))
        for part in exam["parts"]:
            for step in part["steps"]:
                longest = 0
                for voice in voices:
                    rel = step["audio"].replace("audio/", f"audio/{voice}/", 1)
                    target = OUT / rel
                    if only_missing and target.exists():
                        # Already rendered (maybe by an interrupted run): measure it.
                        longest = max(longest, round(sf.info(str(target)).duration * 1000))
                        continue
                    samples, rate = kokoro.create(step["text"], voice=voice, speed=SPEED, lang="en-gb")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(mp3(samples, rate))
                    longest = max(longest, round(len(samples) / rate * 1000))
                if longest:
                    step["audioMs"] = int(math.ceil((longest + TAIL_MS) / 100.0) * 100)
                print(f"{exam['id']}/{step['id']}: {step['audioMs']} ms")
        path.write_text(json.dumps(exam, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

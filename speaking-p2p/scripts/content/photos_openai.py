"""Part 2 photos that Pixabay could not cover, generated with the OpenAI Images
API from content/photos/PROMPTS_IA.md (D-047).

Budget first: every response reports its token usage; the script turns it into
dollars, adds it to content/.openai/spend.json and refuses to start a call that
could take the total past --cap (default 7 USD). Existing photos are never
regenerated, failed calls are not retried (except a short wait on 429).

  python scripts/content/photos_openai.py ids.txt [--model gpt-image-1-mini]
         [--quality medium] [--cap 7] [--max 10]
  python scripts/content/photos_openai.py --spend      # what has been spent

ids.txt: one photo id per line, in priority order. The key comes from
OPENAI_API_KEY (environment or the repo's gitignored .env).
Then: build-photos.py and upload-r2.sh img, as for every photo.
"""
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHOTOS = ROOT / "content" / "photos"
PROMPTS = PHOTOS / "PROMPTS_IA.md"
WORK = ROOT / "content" / ".openai"          # gitignored
SPEND = WORK / "spend.json"
SIZE = "1536x1024"                           # landscape; build-photos.py crops to 4:3

# USD per token (developers.openai.com/api/docs/pricing, checked 2026-10-28).
RATES = {
    "gpt-image-1-mini": {"text_in": 2.00e-6, "image_in": 2.50e-6, "image_out": 8.00e-6},
    "gpt-image-1.5": {"text_in": 5.00e-6, "image_in": 8.00e-6, "image_out": 32.0e-6},
    "gpt-image-2": {"text_in": 5.00e-6, "image_in": 8.00e-6, "image_out": 30.0e-6},
}
# Worst case for one call before its real usage is known (high-ish token count).
GUARD_TOKENS = 6500


def api_key() -> str:
    key = os.environ.get("OPENAI_API_KEY", "").strip()
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("OPENAI_API_KEY"):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not key:
        sys.exit("OPENAI_API_KEY not set (environment or .env in the repo root)")
    return key


def prompts() -> dict:
    out = {}
    for line in PROMPTS.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^- `([a-z0-9-]+)` — (.*)$", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def load_spend() -> dict:
    return json.loads(SPEND.read_text(encoding="utf-8")) if SPEND.exists() else {"usd": 0.0, "images": []}


def cost(model: str, usage: dict) -> float:
    r = RATES[model]
    details = usage.get("input_tokens_details") or {}
    text_in = details.get("text_tokens", usage.get("input_tokens", 0))
    image_in = details.get("image_tokens", 0)
    return text_in * r["text_in"] + image_in * r["image_in"] + usage.get("output_tokens", 0) * r["image_out"]


def generate(key: str, model: str, quality: str, prompt: str) -> dict:
    body = json.dumps({"model": model, "prompt": prompt, "size": SIZE, "quality": quality, "n": 1,
                       "output_format": "jpeg", "output_compression": 90}).encode()
    req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=body, headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt == 0:
                time.sleep(30)
                continue
            raise RuntimeError(f"HTTP {e.code}: {e.read().decode()[:300]}") from None
    raise RuntimeError("rate limited")


def main(args: list) -> None:
    spend = load_spend()
    if "--spend" in args:
        print(f"spent {spend['usd']:.4f} USD on {len(spend['images'])} images")
        return
    opt = lambda name, default: args[args.index(name) + 1] if name in args else default
    model = opt("--model", "gpt-image-1-mini")
    quality = opt("--quality", "medium")
    cap = float(opt("--cap", "7"))
    limit = int(opt("--max", "10000"))
    if model not in RATES:
        sys.exit(f"unknown model {model}; add its rates to RATES first")
    ids = [l.strip() for l in Path(args[0]).read_text(encoding="utf-8").splitlines() if l.strip()]
    text = prompts()
    key = api_key()
    WORK.mkdir(parents=True, exist_ok=True)
    guard = GUARD_TOKENS * RATES[model]["image_out"]
    done = 0
    for asset in ids:
        if done >= limit:
            break
        if (PHOTOS / f"{asset}.jpg").exists() or asset not in text:
            continue
        if spend["usd"] + guard > cap:
            print(f"STOP: {spend['usd']:.4f} USD spent, cap {cap} USD")
            break
        try:
            res = generate(key, model, quality, text[asset])
        except Exception as e:  # moderation, network...: note it and go on, never loop
            print(f"FAILED {asset}: {e}")
            continue
        usd = cost(model, res.get("usage", {}))
        (PHOTOS / f"{asset}.jpg").write_bytes(base64.b64decode(res["data"][0]["b64_json"]))
        spend["usd"] += usd
        spend["images"].append({"id": asset, "model": model, "quality": quality, "usd": round(usd, 5),
                                "usage": res.get("usage", {})})
        SPEND.write_text(json.dumps(spend, indent=1), encoding="utf-8")
        done += 1
        print(f"{asset}: {usd:.4f} USD (total {spend['usd']:.4f})")
    print(f"{done} generated; spent {spend['usd']:.4f} USD of {cap}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])

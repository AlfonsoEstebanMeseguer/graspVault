"""Part 2 photos from Pixabay (D-047). Three steps, so a person (or Claude) looks
at every candidate before anything ends up in the app:

  search  For each photo still missing in content/photos/, asks the Pixabay API
          for horizontal photos matching its description (content/photos.json)
          and draws one contact sheet per exam (one row per photo, so the
          photos a candidate compares sit together): content/.pixabay/sheets/
          {level}-e{nn}.jpg, with the candidates numbered.
  pick    `pick b1-e01-a1=3 b1-e01-b1=0`: downloads the chosen candidate at
          1280 px to content/photos/{id}.jpg and records author and page in the
          Pixabay table of content/LICENSES.md (Pixabay Content License:
          commercial use allowed, no attribution required; we credit anyway).
  sheets  `sheets b2`: redraws the sheets from the saved candidates (no API
          calls), e.g. after previews failed to download.
  ai      `ai b1-e01-a1 ...`: no good match. Writes the id to
          content/photos/PROMPTS_IA.md with a ready prompt to generate it.

The API key comes from PIXABAY_API_KEY (environment or the repo's .env, which is
gitignored). Pixabay asks to cache results for 24 h and to download images
instead of hotlinking: both are done here. Limit: 100 requests per minute.

Then, as always: build-photos.py (WebP 4:3, size budget) and upload-r2.sh img.

Usage (Pillow in the same venv as build-photos.py):
  venv/Scripts/python scripts/content/photos_pixabay.py search [--only b2-e05] [--max 40]
  venv/Scripts/python scripts/content/photos_pixabay.py pick b2-e05-a1=2 ...
  venv/Scripts/python scripts/content/photos_pixabay.py ai b2-e05-b2 ...
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "content"
PHOTOS = CONTENT / "photos"
WORK = CONTENT / ".pixabay"          # gitignored: API cache, candidates, sheets
CACHE = WORK / "cache"
SHEETS = WORK / "sheets"
CANDIDATES = WORK / "candidates.json"
PICKED = WORK / "picked.json"
LICENSES = CONTENT / "LICENSES.md"
PROMPTS = PHOTOS / "PROMPTS_IA.md"
QUERIES = PHOTOS / "queries.json"   # hand-written keywords per photo (better than the description)
EXT = {".jpg", ".jpeg", ".png", ".webp"}
PER_ID = 8
STOP = set("""a an the of in on at with and or to for from by into their his her its some two three people person
          someone something other another while each very""".split())
UA = {"User-Agent": "speaking-p2p-content-script"}


def api_key() -> str:
    key = os.environ.get("PIXABAY_API_KEY", "").strip()
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("PIXABAY_API_KEY"):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not key:
        sys.exit("PIXABAY_API_KEY not set (environment or .env in the repo root)")
    return key


def pending() -> dict:
    """asset id -> description, for photos not yet in content/photos/."""
    have = {p.stem.lower() for p in PHOTOS.iterdir() if p.suffix.lower() in EXT}
    descriptions = json.loads((CONTENT / "photos.json").read_text(encoding="utf-8"))
    return {k: v for k, v in descriptions.items() if k not in have}


def group_of(asset: str) -> str:
    """b2-e05-a2 -> b2-e05: every photo of one exam on one sheet (pairs side by side)."""
    return asset.rsplit("-", 1)[0]


_last_call = [0.0]


def get_json(url: str) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / (hashlib.sha1(url.encode()).hexdigest() + ".json")
    if cached.exists() and time.time() - cached.stat().st_mtime < 24 * 3600:
        return json.loads(cached.read_text(encoding="utf-8"))
    wait = 0.65 - (time.time() - _last_call[0])  # stays under 100 requests/minute
    if wait > 0:
        time.sleep(wait)
    _last_call[0] = time.time()
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r:
        data = json.loads(r.read().decode("utf-8"))
    cached.write_text(json.dumps(data), encoding="utf-8")
    return data


def queries(description: str) -> list:
    """From the most specific to the broadest: Pixabay ANDs every word."""
    words = [w for w in re.findall(r"[a-z]+", description.lower()) if w not in STOP]
    out = []
    for n in (5, 4, 3, 2):
        q = " ".join(words[:n])
        if q and q not in out:
            out.append(q)
    return out


def search_one(key: str, asset: str, description: str) -> list:
    """Up to PER_ID real photos: each query adds at most 5, so several ideas show up."""
    manual = json.loads(QUERIES.read_text(encoding="utf-8")) if QUERIES.exists() else {}
    seen, hits = set(), []
    for q in manual.get(asset) or queries(description):
        added = 0
        params = {"key": key, "q": q, "image_type": "photo", "orientation": "horizontal",
                  "safesearch": "true", "min_width": 1024, "per_page": 20, "order": "popular"}
        data = get_json("https://pixabay.com/api/?" + urllib.parse.urlencode(params))
        for h in data.get("hits", []):
            # Pixabay also hosts AI images: Part 2 wants real photographs.
            if "ai generated" in h.get("tags", "").lower() or added >= 5:
                continue
            if h["id"] not in seen:
                added += 1
                seen.add(h["id"])
                hits.append({"id": h["id"], "query": q, "tags": h.get("tags", ""), "page": h["pageURL"],
                             # 340 px variant of the preview: enough to judge, light to fetch.
                             "preview": h["webformatURL"].replace("_640.", "_340."), "large": h["largeImageURL"], "user": h.get("user", ""),
                             "w": h.get("imageWidth"), "h": h.get("imageHeight")})
        if len(hits) >= PER_ID:
            break
    return hits[:PER_ID]


def fetch_image(url: str, tries: int = 4) -> Image.Image:
    """The CDN drops some requests under load: retry with a growing pause."""
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r:
                return Image.open(BytesIO(r.read())).convert("RGB")
        except Exception:
            if attempt == tries - 1:
                raise
            time.sleep(2 * (attempt + 1))


def sheet(group: str, rows: dict, descriptions: dict) -> Path:
    """One row per asset of the group, candidates numbered 0..7, 4:3 thumbnails."""
    tw, th, pad, label = 240, 180, 8, 26
    width = pad + PER_ID * (tw + pad)
    height = sum(label + th + pad for _ in rows) + pad
    img = Image.new("RGB", (width, height), (24, 26, 32))
    draw = ImageDraw.Draw(img)
    y = pad
    for asset, hits in rows.items():
        draw.text((pad, y + 6), f"{asset}: {descriptions[asset]}", fill=(240, 240, 240))
        y += label
        for i, h in enumerate(hits):
            x = pad + i * (tw + pad)
            try:
                t = fetch_image(h["preview"])
                t.thumbnail((tw, th))
                img.paste(t, (x + (tw - t.width) // 2, y + (th - t.height) // 2))
            except Exception:
                draw.rectangle((x, y, x + tw, y + th), outline=(120, 120, 120))
            draw.rectangle((x, y, x + 26, y + 22), fill=(76, 111, 255))
            draw.text((x + 8, y + 5), str(i), fill=(255, 255, 255))
        y += th + pad
    SHEETS.mkdir(parents=True, exist_ok=True)
    out = SHEETS / f"{group}.jpg"
    img.save(out, quality=85)
    return out


def cmd_search(args: list) -> None:
    key = api_key()
    only = args[args.index("--only") + 1] if "--only" in args else ""
    limit = int(args[args.index("--max") + 1]) if "--max" in args else 10_000
    todo = {k: v for k, v in pending().items() if k.startswith(only)}
    cands = json.loads(CANDIDATES.read_text(encoding="utf-8")) if CANDIDATES.exists() else {}
    groups = {}
    for asset in sorted(todo):
        groups.setdefault(group_of(asset), []).append(asset)
    done = 0
    for group, assets in groups.items():
        if done >= limit:
            break
        rows = {}
        for asset in assets:
            cands[asset] = search_one(key, asset, todo[asset])
            rows[asset] = cands[asset]
        CANDIDATES.write_text(json.dumps(cands, indent=1), encoding="utf-8")
        print(f"{group}: {[len(r) for r in rows.values()]} candidates -> {sheet(group, rows, todo)}")
        done += 1
    print(f"{done} sheets; {len(todo)} photos pending in total")


def cmd_sheets(args: list) -> None:
    """Redraws the sheets from candidates.json (no new API calls)."""
    only = args[0] if args else ""
    cands = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    todo = {k: v for k, v in pending().items() if k.startswith(only) and k in cands}
    groups = {}
    for asset in sorted(todo):
        groups.setdefault(group_of(asset), []).append(asset)
    for group, assets in groups.items():
        print(sheet(group, {a: cands[a] for a in assets}, todo))


def credit_table(picked: dict) -> str:
    lines = ["<!-- pixabay:start -->", "### Fotos de la Parte 2 descargadas de Pixabay", "",
             "Licencia: [Pixabay Content License](https://pixabay.com/service/license-summary/) (uso comercial permitido, sin atribución obligatoria).", "",
             "| Foto | Autor | Página |", "|---|---|---|"]
    for asset in sorted(picked):
        p = picked[asset]
        lines.append(f"| `{asset}` | {p['user']} | {p['page']} |")
    lines.append("<!-- pixabay:end -->")
    return "\n".join(lines)


def cmd_pick(args: list) -> None:
    cands = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    picked = json.loads(PICKED.read_text(encoding="utf-8")) if PICKED.exists() else {}
    for arg in args:
        asset, idx = arg.split("=")
        hit = cands[asset][int(idx)]
        try:
            img = fetch_image(hit["large"], tries=1)
        except Exception:
            # Pixabay image URLs expire after 24 h: ask the API for a fresh one by id.
            fresh = get_json("https://pixabay.com/api/?" + urllib.parse.urlencode({"key": api_key(), "id": hit["id"]}))
            img = fetch_image(fresh["hits"][0]["largeImageURL"])
        img.save(PHOTOS / f"{asset}.jpg", quality=92)
        picked[asset] = {"pixabay_id": hit["id"], "user": hit["user"], "page": hit["page"]}
        print(f"{asset} <- {hit['page']}")
    PICKED.write_text(json.dumps(picked, indent=1), encoding="utf-8")
    text = LICENSES.read_text(encoding="utf-8")
    table = credit_table(picked)
    if "<!-- pixabay:start -->" in text:
        text = re.sub(r"<!-- pixabay:start -->.*?<!-- pixabay:end -->", lambda _: table, text, flags=re.S)
    else:
        text = text.rstrip() + "\n\n" + table + "\n"
    LICENSES.write_text(text, encoding="utf-8")


def prompt_for(description: str) -> str:
    return (f"Realistic documentary-style photograph: {description}. Natural light, candid, everyday setting, "
            "only the people the scene needs, landscape 4:3, no text, no logos, no watermarks, "
            "no recognisable brands or celebrities.")


def cmd_ai(args: list) -> None:
    descriptions = json.loads((CONTENT / "photos.json").read_text(encoding="utf-8"))
    rows = {}
    if PROMPTS.exists():
        for line in PROMPTS.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^- `([a-z0-9-]+)` — (.*)$", line)
            if m:
                rows[m.group(1)] = m.group(2)
    for asset in args:
        rows[asset] = prompt_for(descriptions[asset])
    head = ("# Fotos para generar con IA\n\nNo se encontró en Pixabay una foto que encajara. Genera cada una, guárdala como "
            "`content/photos/{id}.jpg` y ejecuta `build-photos.py`. Apunta la herramienta usada en `content/LICENSES.md`.\n\n")
    PROMPTS.write_text(head + "\n".join(f"- `{k}` — {v}" for k, v in sorted(rows.items())) + "\n", encoding="utf-8")
    print(f"{len(rows)} prompts in {PROMPTS}")


if __name__ == "__main__":
    commands = {"search": cmd_search, "sheets": cmd_sheets, "pick": cmd_pick, "ai": cmd_ai}
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        sys.exit(__doc__)
    commands[sys.argv[1]](sys.argv[2:])

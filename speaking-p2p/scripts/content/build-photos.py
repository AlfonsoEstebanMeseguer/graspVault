"""Part 2 photos (D-036): compresses whatever is dropped in content/photos/ into
the WebP that the app downloads from R2 in the lobby.

  * Input: content/photos/{assetId}.{jpg,jpeg,png,webp} (name = id in photos.json,
    see LISTA_DE_FOTOS.md). Any size: phone photos of several MB are fine.
  * Output: content/.img-build/img/{level}/{examId}/{assetId}.webp (gitignored),
    centre-cropped to landscape 4:3 (every Part 2 photo has the same shape, so a
    pair compares well), 1024x768 at most, no EXIF/GPS metadata, rotated upright.
    WebP quality starts at 72 and steps down until the file fits MAX_BYTES (D-047):
    612 photos stay around 50 MB in R2 and each lobby downloads very little.
  * Only re-encodes photos that are new or changed since the last run, and drops
    them from .img-build/.uploaded so the next upload sends the new version.

Then: scripts/content/upload-r2.sh img

Setup (once, outside the repo): python -m venv venv && venv/Scripts/pip install pillow
Usage: venv/Scripts/python scripts/content/build-photos.py [--force]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "content"
SRC = CONTENT / "photos"
OUT = CONTENT / ".img-build"
EXT = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIDE = 1024   # B1 shows one photo at full phone width (~1080 px); B2/C1 show 2-3 smaller
QUALITY = 72      # visually clean for photos, ~1/3 of a medium-quality JPEG
MIN_QUALITY = 50  # below this, artefacts show; a photo still too heavy is reported
MAX_BYTES = 110 * 1024
ASPECT = 4 / 3


def owners() -> dict:
    """asset id -> (level, examId), read from the exams themselves."""
    out = {}
    for f in (CONTENT / "exams").glob("*/*.json"):
        exam = json.loads(f.read_text(encoding="utf-8"))
        for part in exam["parts"]:
            for step in part["steps"]:
                for asset in step.get("assets", []):
                    out[asset] = (exam["level"], exam["id"])
    return out


def encode(src: Path, dst: Path) -> None:
    with Image.open(src) as im:
        im = ImageOps.exif_transpose(im)  # phone photos store rotation in EXIF
        if im.mode in ("RGBA", "LA", "P"):
            im = im.convert("RGBA")
            bg = Image.new("RGB", im.size, (255, 255, 255))
            bg.paste(im, mask=im.getchannel("A"))
            im = bg
        else:
            im = im.convert("RGB")
        im = crop_to_aspect(im)
        im.thumbnail((MAX_SIDE, MAX_SIDE), Image.LANCZOS)  # never upscales
        dst.parent.mkdir(parents=True, exist_ok=True)
        tmp = dst.with_suffix(".part")
        # No exif= argument: Pillow writes no metadata (drops GPS, camera, etc.).
        quality = QUALITY
        while True:
            im.save(tmp, "WEBP", quality=quality, method=6)
            if tmp.stat().st_size <= MAX_BYTES or quality <= MIN_QUALITY:
                break
            quality = max(quality - 6, MIN_QUALITY)
        if tmp.stat().st_size > MAX_BYTES:
            print(f"  note: {dst.name} is {tmp.stat().st_size // 1024} KB even at quality {quality}")
        tmp.replace(dst)


def crop_to_aspect(im: Image.Image) -> Image.Image:
    """Centre crop to landscape 4:3 (portrait sources keep their middle band)."""
    w, h = im.size
    if w / h > ASPECT:
        nw = round(h * ASPECT)
        left = (w - nw) // 2
        return im.crop((left, 0, left + nw, h))
    nh = round(w / ASPECT)
    top = (h - nh) // 2
    return im.crop((0, top, w, top + nh))


def main() -> None:
    force = "--force" in sys.argv
    who = owners()
    uploaded_file = OUT / ".uploaded"
    uploaded = set(uploaded_file.read_text().split()) if uploaded_file.exists() else set()
    done = skipped = 0
    size_in = size_out = 0
    for src in sorted(SRC.iterdir()):
        if src.suffix.lower() not in EXT:
            continue
        asset = src.stem.lower()
        if asset not in who:
            print(f"ignored {src.name}: no exam uses the id '{asset}'")
            continue
        level, exam = who[asset]
        key = f"img/{level}/{exam}/{asset}.webp"
        dst = OUT / key
        if not force and dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
            skipped += 1
            continue
        try:
            encode(src, dst)
        except Exception as e:  # a broken file must not stop the batch
            print(f"FAILED {src.name}: {e}")
            continue
        uploaded.discard(key)
        done += 1
        size_in += src.stat().st_size
        size_out += dst.stat().st_size
        print(f"{src.name}: {src.stat().st_size // 1024} KB -> {dst.stat().st_size // 1024} KB")
    if uploaded_file.exists():
        # LF on Windows too: upload-r2.sh compares these lines byte by byte.
        uploaded_file.write_text("".join(f"{k}\n" for k in sorted(uploaded)), newline="\n")
    total = len(who)
    have = sum(1 for _ in OUT.glob("img/*/*/*.webp")) if OUT.exists() else 0
    print(f"encoded {done}, unchanged {skipped}; {have} of {total} photos ready")
    if done:
        print(f"{size_in // 1024} KB -> {size_out // 1024} KB ({100 - 100 * size_out // max(size_in, 1)}% smaller)")


if __name__ == "__main__":
    main()

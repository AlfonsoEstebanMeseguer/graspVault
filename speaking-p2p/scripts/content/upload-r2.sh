#!/usr/bin/env bash
# Uploads a build folder to the R2 bucket speaking-content, key = path inside it
# (D-033 audio, D-035 photos). Needs `npx wrangler login` once.
#   scripts/content/upload-r2.sh audio   # content/.audio-build/audio/**.mp3
#   scripts/content/upload-r2.sh img     # content/.img-build/img/**.webp
# Resumable: keys already in <build>/.uploaded are skipped. Uses `wrangler r2
# bulk put` in batches of 200, one batch per minute: the Cloudflare API allows
# ~1200 requests per 5 min and answers 429 above that. A failed batch waits for
# the window to reset and is retried (4 tries).
# Paths are immutable per content version, so re-running only costs time.
set -euo pipefail
case "${1:-}" in
  audio) BUILD=.audio-build; EXT=mp3;  TYPE=audio/mpeg ;;
  img)   BUILD=.img-build;   EXT=webp; TYPE=image/webp ;;
  *) echo "usage: $0 audio|img" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/../../content/$BUILD"
touch .uploaded
TODO=$(mktemp)
find "$1" -name "*.$EXT" | sort | comm -23 - <(sort -u .uploaded) > "$TODO"
echo "$(wc -l < "$TODO") files to upload"
if [ ! -s "$TODO" ]; then rm -f "$TODO"; exit 0; fi
split -l 200 "$TODO" "$TODO.part."
for part in "$TODO".part.*; do
  awk 'BEGIN{printf "["} {printf "%s{\"key\":\"%s\",\"file\":\"%s\"}", (NR>1?",":""), $0, $0} END{print "]"}' "$part" > "$part.json"
  start=$SECONDS
  for try in 1 2 3 4; do
    if npx --yes wrangler@4 r2 bulk put speaking-content --filename "$part.json" --content-type "$TYPE" --remote --force >"$part.err" 2>&1; then
      cat "$part" >> .uploaded; echo "ok +$(wc -l < "$part") (total $(wc -l < .uploaded))"; break
    elif [ $try = 4 ]; then echo "FAIL batch: $(grep -m1 -E 'ERROR|APIError' "$part.err")"
    else echo "retry in 5 min: $(grep -m1 -E 'APIError' "$part.err" | grep -oE '[0-9]{3}: [A-Za-z ]+' | head -1)"; sleep 300; start=$SECONDS; fi
  done
  wait_for=$((60 - (SECONDS - start))); if [ $wait_for -gt 0 ]; then sleep $wait_for; fi
done
rm -f "$TODO" "$TODO".part.*

#!/bin/bash
#
# make_cue.sh — turn any audio clip into a Magic Eight sound cue.
# Trims a segment, converts to mono 44.1 kHz WAV, adds tiny anti-click fades,
# loudness-normalizes, and drops it into /Sounds as cue-<themeid>.wav.
#
# Usage:   ./make_cue.sh <input-audio> <start> <duration-seconds> <themeid>
# Example: ./make_cue.sh clip.wav 00:00:12.4 1.1 aimy2k
#          ./make_cue.sh dialup.mp3 3.0 1.4 facebook2008
#
# themeid is one of the theme ids (aimy2k, facebook2008, matrix, nbajam, ...)
# or "shiny" for the rare-fortune fanfare.
#
# Requires: ffmpeg (already installed).

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <input-audio> <start> <duration-seconds> <themeid>"
  exit 1
fi

IN="$1"; START="$2"; DUR="$3"; ID="$4"
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/Sounds/cue-$ID.wav"
[ "$ID" = "shiny" ] && OUT="$DIR/Sounds/shiny.wav"

# out-fade starts 0.06s before the end
OUTFADE=$(awk "BEGIN{v=$DUR-0.06; print (v>0)?v:0}")

ffmpeg -y -ss "$START" -t "$DUR" -i "$IN" \
  -ac 1 -ar 44100 \
  -af "afade=t=in:st=0:d=0.01,afade=t=out:st=${OUTFADE}:d=0.06,loudnorm=I=-15:TP=-1.0" \
  "$OUT" >/dev/null 2>&1

echo "✓ wrote $OUT  (${DUR}s, mono 44.1kHz)"
echo "  Rebuild the app to hear it, or run this again to tweak the trim."

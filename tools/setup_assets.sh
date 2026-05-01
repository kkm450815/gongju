#!/usr/bin/env bash
# setup_assets.sh — extract Kenney/Quaternius zips into the layout
# the game expects (game/assets/kenney/{buildings,characters,nature,sfx}).
#
# Usage:
#   1) Download zips listed in tools/asset_manifest.txt into game/assets/_downloads/
#   2) bash tools/setup_assets.sh
#
# Idempotent: re-running just refreshes targets. Safe to call after each
# new pack you add. Requires `unzip` and `find` (default on macOS/Linux).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DL="$ROOT/game/assets/_downloads"
KENNEY="$ROOT/game/assets/kenney"
QUAT="$ROOT/game/assets/quaternius"
MANIFEST="$ROOT/tools/asset_manifest.txt"

mkdir -p "$KENNEY/buildings" "$KENNEY/characters" "$KENNEY/nature" "$KENNEY/sfx" \
         "$KENNEY/roads" "$QUAT" "$DL"

if [[ ! -d "$DL" ]] || [[ -z "$(ls -A "$DL" 2>/dev/null)" ]]; then
  echo "[setup_assets] No zips found in $DL"
  echo "[setup_assets] Open these URLs in a browser, download the zips, drop them in _downloads/, then re-run."
  echo
  grep -v '^\s*#' "$MANIFEST" | grep -v '^\s*$' | awk -F'|' '{ printf "  %-12s  %s\n", $1, $3 }'
  exit 0
fi

extract_one() {
  local zip="$1" category="$2" target_subdir="$3"
  local stage
  stage="$(mktemp -d)"
  echo "[setup_assets] extracting $(basename "$zip") -> $target_subdir"
  unzip -q -o "$zip" -d "$stage"
  # copy any .glb/.gltf/.ogg/.wav into the target
  case "$category" in
    sfx)
      find "$stage" -type f \( -iname '*.ogg' -o -iname '*.wav' -o -iname '*.mp3' \) \
        -exec cp -n {} "$KENNEY/$target_subdir/" \; || true
      ;;
    *)
      find "$stage" -type f \( -iname '*.glb' -o -iname '*.gltf' \) \
        -exec cp -n {} "$KENNEY/$target_subdir/" \; || true
      # also copy companion .bin and textures next to gltf
      find "$stage" -type f \( -iname '*.bin' -o -iname '*.png' -o -iname '*.jpg' \) \
        -exec cp -n {} "$KENNEY/$target_subdir/" \; || true
      ;;
  esac
  rm -rf "$stage"
}

# Walk the manifest, match each row's filename substring against zips in _downloads
while IFS='|' read -r category needle url; do
  # skip comments and blanks
  [[ -z "${category// }" || "${category:0:1}" == "#" ]] && continue
  needle_trimmed="${needle## }"; needle_trimmed="${needle_trimmed%% }"
  found=""
  while IFS= read -r -d '' zip; do
    found="$zip"; break
  done < <(find "$DL" -maxdepth 1 -type f -iname "*${needle_trimmed}*.zip" -print0)
  if [[ -z "$found" ]]; then
    continue
  fi
  case "$category" in
    buildings) target="buildings" ;;
    characters) target="characters" ;;
    nature) target="nature" ;;
    roads) target="roads" ;;
    sfx) target="sfx" ;;
    *) target="$category" ;;
  esac
  extract_one "$found" "$category" "$target"
done < "$MANIFEST"

echo
echo "[setup_assets] done. Inventory:"
for sub in buildings characters nature roads sfx; do
  count="$(find "$KENNEY/$sub" -maxdepth 1 -type f \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.ogg' -o -iname '*.wav' \) 2>/dev/null | wc -l | tr -d ' ')"
  printf "  %-12s %s files\n" "$sub" "$count"
done

echo
echo "Next: edit data/buildings.json and data/npcs.json model paths"
echo "to match the actual filenames Kenney shipped (open the buildings/ folder"
echo "to see what's in there). Defaults expect:"
echo "  res://assets/kenney/buildings/building-house-block-small.glb"
echo "  res://assets/kenney/characters/character-male-a.glb"
echo "If your filenames differ, just rename or update the JSON."

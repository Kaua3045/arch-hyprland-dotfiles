#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"

mapfile -t files < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" -o \
        -iname "*.webp" -o \
        -iname "*.gif" \
    \) | sort
)

[ ${#files[@]} -eq 0 ] && exit 1

SELECTED_WALL=$(
    for f in "${files[@]}"; do
        # basename "$f"
        echo -en "$(basename "$f")\x00icon\x1f$f\n"
    done | rofi -dmenu -i -p "Wallpaper" -show-icons
)

[ -z "$SELECTED_WALL" ] && exit 0

SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

pgrep -x swww-daemon >/dev/null || swww-daemon &

swww img "$SELECTED_PATH" \
    --transition-type grow \
    --transition-duration 1 \
    --transition-fps 60

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"
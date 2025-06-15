#!/bin/bash

# Script to set file metadata (EXIF + filesystem) based on filename timestamp
# Works recursively and supports JPEG/MP4 formats on macOS

# Requirements: exiftool
if ! command -v exiftool &> /dev/null; then
  echo "❌ exiftool not found. Install it with: brew install exiftool"
  exit 1
fi

# Input directory (default to current)
INPUT_DIR="${1:-.}"

# Validate directory
if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ Directory not found: $INPUT_DIR"
  exit 1
fi

echo "📂 Scanning directory: $INPUT_DIR"

# Process files recursively
find "$INPUT_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.mp4" \) | while read -r file; do
  filename="$(basename "$file")"
  extension="${filename##*.}"
  date=""
  time=""

  # Match known filename formats
  if [[ "$filename" =~ ^IMG_([0-9]{8})_([0-9]{6})[0-9]{3}.*\.(jpe?g|JPG)$ ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
  elif [[ "$filename" =~ ^IMG([0-9]{8})([0-9]{6}).*\.(jpe?g|JPG)$ ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
  elif [[ "$filename" =~ ^VID_([0-9]{8})_([0-9]{6})[0-9]{3}.*\.(mp4|MP4)$ ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
  elif [[ "$filename" =~ ^VID([0-9]{8})([0-9]{6}).*\.(mp4|MP4)$ ]]; then
    date="${BASH_REMATCH[1]}"
    time="${BASH_REMATCH[2]}"
  else
    echo "⚠️ Skipping unrecognized file: $filename"
    continue
  fi

  # Format for exiftool and touch
  exif_ts="${date:0:4}:${date:4:2}:${date:6:2} ${time:0:2}:${time:2:2}:${time:4:2}"
  touch_ts="${date:0:4}${date:4:2}${date:6:2}${time:0:2}${time:2:2}.${time:4:2}"

  echo "🛠 Updating $filename → $exif_ts"

  # Apply EXIF changes
  if [[ "$extension" =~ ^(jpe?g|JPG|JPEG)$ ]]; then
    exiftool -quiet -overwrite_original \
      -DateTimeOriginal="$exif_ts" \
      -CreateDate="$exif_ts" \
      -ModifyDate="$exif_ts" \
      "$file"
  elif [[ "$extension" =~ ^(mp4|MP4)$ ]]; then
    exiftool -quiet -overwrite_original \
      -MediaCreateDate="$exif_ts" \
      -CreateDate="$exif_ts" \
      -ModifyDate="$exif_ts" \
      "$file"
  fi

  # Update filesystem timestamp
  touch -t "$touch_ts" "$file"

done

echo "✅ Done."

#!/bin/bash

# Usage: ./copy_video_metadata.sh /path/to/source_dir /path/to/target_dir

set -e

SOURCE_DIR="$1"
TARGET_DIR="$2"

if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" ]]; then
  echo "Usage: $0 <source_dir> <target_dir>"
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" || ! -d "$TARGET_DIR" ]]; then
  echo "❌ One or both directories are invalid."
  exit 1
fi

# Ensure exiftool is available
if ! command -v exiftool &> /dev/null; then
  echo "❌ exiftool is not installed. Install it first."
  exit 1
fi

echo "🔄 Copying metadata from: $SOURCE_DIR to $TARGET_DIR"

# Find all video files in source dir
find "$SOURCE_DIR" -type f \( \
  -iname "*.mp4" -o \
  -iname "*.mov" -o \
  -iname "*.mkv" -o \
  -iname "*.avi" -o \
  -iname "*.m4v" \
\) | while read -r src_file; do
  rel_path="${src_file#$SOURCE_DIR/}"
  tgt_file="$TARGET_DIR/$rel_path"

  if [[ -f "$tgt_file" ]]; then
    echo "➡️  $rel_path"
    exiftool -overwrite_original -TagsFromFile "$src_file" \
      -DateTimeOriginal -CreateDate -ModifyDate "$tgt_file"
  else
    echo "⚠️  Skipping missing target: $tgt_file"
  fi
done

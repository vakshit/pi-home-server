#!/bin/bash

# Set root directory to scan
ROOT_DIR="${1:-.}"

# Temporary file for processing
TMP_FILE=$(mktemp)

# Define patterns for photo and video mime types
PHOTO_TYPES="image/jpeg|image/png|image/gif|image/webp|image/heic|image/heif|image/tiff|image/bmp|image/x-canon-cr2|image/x-sony-arw"
VIDEO_TYPES="video/mp4|video/x-msvideo|video/x-matroska|video/quicktime|video/x-ms-wmv|video/webm|video/mpeg|video/3gpp|video/x-flv|video/ogg"

# Find all files and get their MIME types and sizes
find "$ROOT_DIR" -type f | while read -r file; do
  mime=$(file -b --mime-type "$file")
  size=$(stat -c%s "$file")
  echo "$mime $size" >> "$TMP_FILE"
done

# Aggregate sizes
photo_size=$(awk -v pattern="$PHOTO_TYPES" '$1 ~ pattern {sum += $2} END {print sum}' "$TMP_FILE")
video_size=$(awk -v pattern="$VIDEO_TYPES" '$1 ~ pattern {sum += $2} END {print sum}' "$TMP_FILE")
other_size=$(awk -v p1="$PHOTO_TYPES" -v p2="$VIDEO_TYPES" '$1 !~ p1 && $1 !~ p2 {sum += $2} END {print sum}' "$TMP_FILE")

# Convert bytes to human-readable format
to_human() {
  num=$1
  awk -v size=$num 'function human(x) {
    split("B KB MB GB TB", units);
    for (i=1; x>=1024 && i<5; i++) x/=1024;
    return sprintf("%.2f %s", x, units[i])
  } BEGIN { print human(size) }'
}

echo "Media size breakdown:"
echo "Photos: $(to_human "$photo_size")"
echo "Videos: $(to_human "$video_size")"
echo "Others: $(to_human "$other_size")"

# Cleanup
rm "$TMP_FILE"


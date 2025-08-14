#!/bin/bash

set -e

# Check for input directory argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <input-directory>"
  exit 1
fi

INPUT_DIR="$1"

if [[ ! -d "$INPUT_DIR" ]]; then
  echo "❌ Error: '$INPUT_DIR' is not a valid directory"
  exit 1
fi

# Convert D,M.decimalH format (e.g., 26,30.67018449N) → decimal degrees
convert_to_decimal() {
  local input="$1"
  local deg=$(echo "$input" | cut -d',' -f1)
  local min=$(echo "$input" | cut -d',' -f2 | sed 's/[NSEW]//g')
  local hemi=$(echo "$input" | grep -o '[NSEW]')

  local decimal=$(echo "scale=8; $deg + ($min / 60)" | bc)
  if [[ "$hemi" == "S" || "$hemi" == "W" ]]; then
    decimal=$(echo "-1 * $decimal" | bc)
  fi

  echo "$decimal"
}

# Loop over all XMP files in the directory
for xmp_file in "$INPUT_DIR"/*.xmp; do
  [[ -e "$xmp_file" ]] || { echo "No .xmp files found in $INPUT_DIR"; exit 1; }

  base_name="$(basename "$xmp_file" .xmp)"
  image_file="$INPUT_DIR/$base_name.jpg"

  if [[ ! -f "$image_file" ]]; then
    echo "❌ Skipping: $image_file not found for $xmp_file"
    continue
  fi

  echo "📦 Processing $xmp_file → $image_file"

  # Extract GPS from XMP
  lat_raw=$(grep "<exif:GPSLatitude>" "$xmp_file" | sed -E 's/.*<exif:GPSLatitude>(.*)<\/exif:GPSLatitude>.*/\1/')
  lon_raw=$(grep "<exif:GPSLongitude>" "$xmp_file" | sed -E 's/.*<exif:GPSLongitude>(.*)<\/exif:GPSLongitude>.*/\1/')

  if [[ -z "$lat_raw" || -z "$lon_raw" ]]; then
    echo "⚠️  GPS tags not found in $xmp_file"
    continue
  fi

  # Convert to decimal
  lat_decimal=$(convert_to_decimal "$lat_raw")
  lon_decimal=$(convert_to_decimal "$lon_raw")

  # Get hemisphere references
  lat_ref=$(echo "$lat_raw" | grep -o '[NS]')
  lon_ref=$(echo "$lon_raw" | grep -o '[EW]')

  # Write to image
  exiftool -overwrite_original \
    -GPSLatitude="$lat_decimal" -GPSLatitudeRef="$lat_ref" \
    -GPSLongitude="$lon_decimal" -GPSLongitudeRef="$lon_ref" \
    "$image_file"
done

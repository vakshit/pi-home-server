#!/bin/bash

DRY_RUN=false
INCLUDE_IMG=false
UPDATED_COUNT=0
SKIPPED_COUNT=0

# Extract timestamp from filename
extract_timestamp() {
  local filename="$1"

  # Pattern 1: "YYYY-MM-DD at HH.MM.SS"
  if [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})\ at\ ([0-9]{2})\.([0-9]{2})\.([0-9]{2}) ]]; then
    echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}${BASH_REMATCH[6]}"
    return
  fi

  # Pattern 2: WhatsApp style "IMG-YYYYMMDD-WA####"
  if [[ "$filename" =~ ([0-9]{4})([0-9]{2})([0-9]{2}) && "$filename" == *WA* ]]; then
    echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}000000"
    return
  fi

  if $INCLUDE_IMG; then
    # Format: IMG_YYYYMMDD_HHMMSS
    if [[ "$filename" =~ IMG_([0-9]{8})_([0-9]{6}) ]]; then
      echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
      return
    fi

    # Format: IMGYYYYMMDDHHMMSS (no underscore)
    if [[ "$filename" =~ IMG([0-9]{8})([0-9]{6}) ]]; then
      echo "${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
      return
    fi
  fi

  echo ""
}

# Update EXIF metadata and file timestamps
update_metadata_and_timestamps() {
  local filepath="$1"
  local original_filename
  original_filename=$(basename "$filepath")

  # Skip non-WA files unless --include-img is active and format matches
  if [[ "$original_filename" != *WA* && "$original_filename" != IMG* ]]; then
    echo "Skipping: $original_filename (Not a WhatsApp or IMG file)"
    ((SKIPPED_COUNT++))
    return
  fi

  local timestamp
  timestamp=$(extract_timestamp "$original_filename")

  if [[ -z "$timestamp" ]]; then
    echo "Skipping: $original_filename (No valid timestamp found)"
    ((SKIPPED_COUNT++))
    return
  fi

  local formatted_time="${timestamp:0:4}:${timestamp:4:2}:${timestamp:6:2} ${timestamp:8:2}:${timestamp:10:2}:${timestamp:12:2}"

  if $DRY_RUN; then
    echo "[DRY-RUN] Would update: $original_filename → EXIF time: $formatted_time"
  else
    exiftool -overwrite_original \
      -DateTimeOriginal="$formatted_time" \
      -FileModifyDate="$formatted_time" \
      -CreateDate="$formatted_time" \
      -ModifyDate="$formatted_time" "$filepath" > /dev/null
    echo "Updated: $original_filename → EXIF time: $formatted_time"
  fi

  ((UPDATED_COUNT++))
}

# Usage instructions
print_usage() {
  echo "Usage: $0 [--dry-run] [--include-img] /path/to/directory"
  exit 1
}

# Parse CLI arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --include-img)
      INCLUDE_IMG=true
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      print_usage
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Restore positional args
set -- "${POSITIONAL[@]}"
directory="$1"

if [[ -z "$directory" || ! -d "$directory" ]]; then
  echo "Error: Valid directory is required."
  print_usage
fi

# Recursively process files
while IFS= read -r -d '' filepath; do
  [[ -f "$filepath" ]] && update_metadata_and_timestamps "$filepath"
done < <(find "$directory" -type f -print0)

# Summary
echo "--------------------------------------"
echo "Total files updated: $UPDATED_COUNT"
echo "Total files skipped: $SKIPPED_COUNT"
echo "Done!"

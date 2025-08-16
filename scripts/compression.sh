#!/bin/bash

# # Exit on any error
# set -e

# Usage check
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_directory> <destination_directory> [options]"
    echo "Options:"
    echo "  --skip-images          Skip image conversion"
    echo "  --skip-videos          Skip video conversion"
    echo "  --skip-legacy-videos   Skip legacy video conversion"
    echo "  --skip-unsupported     Skip unsupported file types"
    exit 1
fi

# Input arguments
SRC_DIR="$1"
DEST_DIR="$2"
shift 2

# Log files
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

UNSUPPORTED_LOG="$LOG_DIR/unsupported_files.log"
FFMPEG_ERROR_LOG="$LOG_DIR/ffmpeg_errors.log"
AVIFENC_ERROR_LOG="$LOG_DIR/avifenc_errors.log"
AVIFENC_EXISTING_LOG="$LOG_DIR/avifenc_existing.log"
FFMPEG_EXISTING_LOG="$LOG_DIR/ffmpeg_existing.log"
HEVC_EXISTING_LOG="$LOG_DIR/hevc_existing.log"

# Clear previous logs
> "$UNSUPPORTED_LOG"
> "$FFMPEG_ERROR_LOG"
> "$AVIFENC_ERROR_LOG"
> "$AVIFENC_EXISTING_LOG"
> "$FFMPEG_EXISTING_LOG"
> "$HEVC_EXISTING_LOG"

# Options
SKIP_IMAGES=false
SKIP_VIDEOS=false
SKIP_LEGACY_VIDEOS=false
SKIP_UNSUPPORTED=false

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-images) SKIP_IMAGES=true ;;
        --skip-videos) SKIP_VIDEOS=true ;;
        --skip-legacy-videos) SKIP_LEGACY_VIDEOS=true ;;
        --skip-unsupported) SKIP_UNSUPPORTED=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Ensure destination directory exists
mkdir -p "$DEST_DIR"

# Function to preserve metadata (uses exiftool + touch)
preserve_metadata() {
    local src="$1"
    local dest="$2"
    if command -v exiftool >/dev/null 2>&1; then
      exiftool -overwrite_original -TagsFromFile "$src" \
        -All:All \
        -Keys:All \
        -Time:All \
        -FileCreateDate \
        -FileModifyDate \
        "$dest"
    fi
    touch -r "$src" "$dest"
}

# Recursive processing
process_files() {
    local src="$1"
    local dest="$2"
    mkdir -p "$dest"

    for item in "$src"/*; do
        if [[ -d "$item" ]]; then
            process_files "$item" "$dest/$(basename "$item")"
        elif [[ -f "$item" ]]; then
            local filename=$(basename "$item")
            local extension="${filename##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
            local name="${filename%.*}"

            if [[ "$extension" =~ ^(jpg|jpeg|png)$ ]]; then
                $SKIP_IMAGES && continue
                local avif_file="$dest/$name.avif"
                # Explicitly skip if file already exists
                if [[ -f "$avif_file" ]]; then
                    echo "Skipping $item, $avif_file already exists."
                    echo "$item" >> "$AVIFENC_EXISTING_LOG"
                    continue
                fi

                output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --min 10 --max 30 "$item" "$avif_file" 2>&1)
                if [[ $? != 0 ]]; then
                    if echo "$output" | grep -q "no-overwrite"; then
                        echo "$item" >> "$AVIFENC_EXISTING_LOG"
                    elif echo "$output" | grep -q "XMP extraction failed"; then
                        output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --ignore-xmp --min 10 --max 30 "$item" "$avif_file" 2>&1)
                        [[ $? != 0 ]] && echo "$item" >> "$AVIFENC_ERROR_LOG"
                    else
                        echo "$item" >> "$AVIFENC_ERROR_LOG"
                    fi
                fi
                echo "$output"

            elif [[ "$extension" =~ ^(mov|mp4|mkv|wmv|dat|3gp)$ ]]; then
                $SKIP_VIDEOS && continue
                case "$extension" in
                  wmv|dat|3gp) out_ext="mp4" ;;  # remap unsupported containers
                  *)       out_ext="$extension" ;;
                esac
                local hevc_file="$dest/$name.$out_ext"
                if [[ -f "$hevc_file" ]]; then
                    echo "$item" >> "$FFMPEG_EXISTING_LOG"
                else
                    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
                                   -of default=noprint_wrappers=1:nokey=1 "$item")
                    local audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
                                  -of default=noprint_wrappers=1:nokey=1 "$item")
                    if [[ "$codec" == "hevc" ]]; then
                        echo "$item" >> "$HEVC_EXISTING_LOG"
                        cp "$item" "$hevc_file"
                        preserve_metadata "$item" "$hevc_file"
                    elif [[ "$audio_codec" == "amr_nb" ]]; then
                        echo "Unsupported audio for $item, encoding to AAC"
                        if ffmpeg -i "$item" -c:v libx265 -preset slow -crf 28 -c:a aac -b:a 128k "$hevc_file"; then
                            preserve_metadata "$item" "$hevc_file"
                        else
                            echo "$item" >> "$FFMPEG_ERROR_LOG"
                        fi
                    else
                        if ffmpeg -i "$item" -c:v libx265 -preset slow -crf 28 -c:a copy "$hevc_file"; then
                            preserve_metadata "$item" "$hevc_file"
                        else
                            echo "$item" >> "$FFMPEG_ERROR_LOG"
                        fi
                    fi
                fi

            elif [[ "$extension" =~ ^(avi)$ ]]; then
                $SKIP_LEGACY_VIDEOS && continue
                local hevc_file="$dest/$name.mp4"
                if [[ -f "$hevc_file" ]]; then
                    echo "$item" >> "$FFMPEG_EXISTING_LOG"
                else
                    if ffmpeg -i "$item" -c:v libx265 -preset slow -crf 28 -c:a aac -b:a 128k "$hevc_file"; then
                        preserve_metadata "$item" "$hevc_file"
                    else
                        echo "$item" >> "$FFMPEG_ERROR_LOG"
                    fi
                fi

            else
                $SKIP_UNSUPPORTED && continue
                echo "$item" >> "$UNSUPPORTED_LOG"
                cp "$item" "$dest/$filename"
                preserve_metadata "$item" "$dest/$filename"
            fi
        fi
    done
}

# Start
process_files "$SRC_DIR" "$DEST_DIR"

echo -e "\n✅ Conversion complete. Files saved in: $DEST_DIR"
echo "Unsupported files → $UNSUPPORTED_LOG"
echo "FFmpeg errors     → $FFMPEG_ERROR_LOG"
echo "AVIFENC errors    → $AVIFENC_ERROR_LOG"
echo "Existing AVIF     → $AVIFENC_EXISTING_LOG"
echo "Existing HEVC     → $HEVC_EXISTING_LOG"
echo "Existing Videos   → $FFMPEG_EXISTING_LOG"

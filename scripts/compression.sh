#!/bin/bash

# Default options
SRC_DIR=""
DEST_DIR=""
SKIP_IMAGES=false
SKIP_VIDEOS=false
SKIP_LEGACY_VIDEOS=false
SKIP_UNSUPPORTED=false

# Log file paths
UNSUPPORTED_LOG="logs/unsupported_files.log"
FFMPEG_ERROR_LOG="logs/ffmpeg_errors.log"
AVIFENC_ERROR_LOG="logs/avifenc_errors.log"
AVIFENC_EXISTING_LOG="logs/avifenc_existing.log"
FFMPEG_EXISTING_LOG="logs/ffmpeg_existing.log"
HEVC_EXISTING_LOG="logs/hevc_existing.log"

# Create logs directory if it doesn't exist
mkdir -p logs

# Clear previous logs
> "$UNSUPPORTED_LOG"
> "$FFMPEG_ERROR_LOG"
> "$AVIFENC_ERROR_LOG"
> "$AVIFENC_EXISTING_LOG"
> "$FFMPEG_EXISTING_LOG"
> "$HEVC_EXISTING_LOG"

# Function to display usage
usage() {
    echo "Usage: $0 --src <source_directory> --dest <destination_directory> [options]"
    echo "Options:"
    echo "  --skip-images           Skip processing image files"
    echo "  --skip-videos           Skip processing video files"
    echo "  --skip-legacy-videos    Skip processing legacy video files"
    echo "  --skip-unsupported      Skip logging unsupported files"
    exit 1
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --src)
            SRC_DIR="$2"
            shift 2
            ;;
        --dest)
            DEST_DIR="$2"
            shift 2
            ;;
        --skip-images)
            SKIP_IMAGES=true
            shift
            ;;
        --skip-videos)
            SKIP_VIDEOS=true
            shift
            ;;
        --skip-legacy-videos)
            SKIP_LEGACY_VIDEOS=true
            shift
            ;;
        --skip-unsupported)
            SKIP_UNSUPPORTED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SRC_DIR" || -z "$DEST_DIR" ]]; then
    echo "Error: Source and destination directories are required."
    usage
fi

# Debugging output
echo "Source Directory: $SRC_DIR"
echo "Destination Directory: $DEST_DIR"
echo "Skip Images: $SKIP_IMAGES"
echo "Skip Videos: $SKIP_VIDEOS"
echo "Skip Legacy Videos: $SKIP_LEGACY_VIDEOS"
echo "Skip Unsupported: $SKIP_UNSUPPORTED"

# Check if the destination directory exists, if not create it
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR"
fi

# Function to process files recursively
process_files() {
    local src="$1"
    local dest="$2"

    # Create destination directory
    mkdir -p "$dest"

    # Loop through all items in the source directory
    for item in "$src"/*; do
        if [ -d "$item" ]; then
            # If it's a directory, process it recursively
            local subdir_name=$(basename "$item")
            process_files "$item" "$dest/$subdir_name"
        elif [ -f "$item" ]; then
            # Process individual files
            local filename=$(basename "$item")
            local extension="${filename##*.}"
            extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]') # Convert extension to lowercase
            local name="${filename%.*}" # Get the filename without extension
            if [[ "$extension" == "jpg" || "$extension" == "jpeg" || $extension == "png" ]]; then
                if $SKIP_IMAGES; then
                    continue
                fi
                # Convert JPG/JPEG files to AVIF if it doesn't already exist
                local avif_file="$dest/$name.avif"
                output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --min 10 --max 30 "$item" "$avif_file" 2>&1)
                if [[ $? != 0 || $? != "0" ]]; then
                    if echo "$output" | grep -q "no-overwrite"; then
                        echo "$item" >> "$AVIFENC_EXISTING_LOG"
                    elif echo "$output" | grep -q "XMP extraction failed"; then
                        echo "XMP extraction failed: removing XMP data from $item"
                        output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --ignore-xmp --min 10 --max 30 "$item" "$avif_file" 2>&1)
                        if [[ $? != 0 || $? != "0" ]]; then
                            echo "$item" >> "$AVIFENC_ERROR_LOG"
                        fi
                    else
                        echo "$item" >> "$AVIFENC_ERROR_LOG"
                    fi
                fi
                echo "$output"

            elif [[ "$extension" == "mov" || "$extension" == "mp4" || "$extension" == "mkv" || "$extension" == "wmv" || "$extension" == "dat" ]]; then
                if $SKIP_VIDEOS; then
                    continue
                fi
                # Check if the video is already HEVC
                local hevc_file="$dest/$name.mp4"
                if [[ -f "$hevc_file" ]] ; then
                    echo "$item" >> "$FFMPEG_EXISTING_LOG"
                else
                    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$item")
                    if [[ $codec == "hevc" ]] ; then
                        echo "$item" >> "$HEVC_EXISTING_LOG"
                        cp "$item" "$hevc_file"
                    else
                        if ! ffmpeg -i "$item" -c:v libx265 -preset slow -crf 28 -c:a copy -map_metadata 0 -movflags use_metadata_tags "$hevc_file"; then
                            echo "$item" >> "$FFMPEG_ERROR_LOG"
                        fi
                    fi
                fi
            elif [[ "$extension" == "avi" || "$extension" == "3gp" ]]; then
                if $SKIP_LEGACY_VIDEOS; then
                    continue
                fi
                local hevc_file="$dest/$name.mp4"
                rm "$hevc_file"
                if [[ -f "$hevc_file" ]] ; then
                    echo "$item" >> "$FFMPEG_EXISTING_LOG"
                else
                    if ! ffmpeg -i "$item" -c:v libx265 -preset medium -crf 28 -c:a aac -b:a 128k -map_metadata 0 -movflags use_metadata_tags "$hevc_file"; then
                        echo "$item" >> "$FFMPEG_ERROR_LOG"
                    fi
                fi
            else
                if $SKIP_UNSUPPORTED; then
                    continue
                fi
                # Log unsupported file types
                echo "$item" >> "$UNSUPPORTED_LOG"
                cp "$item" "$dest/$filename"
            fi
        fi
    done
}

# Start processing from the source directory
process_files "$SRC_DIR" "$DEST_DIR"

echo "Conversion complete. Processed files are in $DEST_DIR."
echo "Unsupported files logged in $UNSUPPORTED_LOG."
echo "FFmpeg errors logged in $FFMPEG_ERROR_LOG."
echo "AVIFENC errors logged in $AVIFENC_ERROR_LOG."
echo "AVIFENC existing files logged in $AVIFENC_EXISTING_LOG."
echo "FFmpeg existing files logged in $FFMPEG_EXISTING_LOG."
echo "HEVC existing files logged in $HEVC_EXISTING_LOG."

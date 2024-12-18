#!/bin/bash

# Define source and destination directories
SRC_DIR="$(echo $HOME)/Desktop/Immich"
DEST_DIR="$(echo $HOME)/Desktop/Immich-AVIF"
UNSUPPORTED_LOG="logs/unsupported_files.log"
FFMPEG_ERROR_LOG="logs/ffmpeg_errors.log"
AVIFENC_ERROR_LOG="logs/avifenc_errors.log"
AVIFENC_EXISTING_LOG="logs/avifenc_existing.log"
FFMPEG_EXISTING_LOG="logs/ffmpeg_existing.log"
HEVC_EXISTING_LOG="logs/hevc_existing.log"

# create logs directory if it doesn't exist
mkdir -p logs

# Clear previous logs
> "$UNSUPPORTED_LOG"
> "$FFMPEG_ERROR_LOG"
> "$AVIFENC_ERROR_LOG"
> "$AVIFENC_EXISTING_LOG"
> "$FFMPEG_EXISTING_LOG"
> "$HEVC_EXISTING_LOG"

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
            if [[ "$extension" == "jpg" || "$extension" == "jpeg" ]]; then
                # Convert JPG/JPEG files to AVIF if it doesn't already exist
                local avif_file="$dest/$name.avif"
                output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --min 10 --max 30 "$item" "$avif_file" 2>&1)
                echo "$output"
                if [ $? -ne 0 ]; then
                    if echo "$output" | grep -q "no-overwrite"; then
                        echo "$item" >> "$AVIFENC_EXISTING_LOG"
                    elif echo "$output" | grep -q "XMP extraction failed"; then
                        echo "XMP extraction failed: removing XMP data from $item"
                        output=$(avifenc -j 12 -c aom -q 50 --no-overwrite --ignore-xmp --min 10 --max 30 "$item" "$avif_file")
                        if [ $? -ne 0 ]; then
                            echo "$item" >> "$AVIFENC_ERROR_LOG"
                        fi
                    else
                        echo "$item" >> "$AVIFENC_ERROR_LOG"
                    fi
                fi

            elif [[ "$extension" == "mov" || "$extension" == "avi" || "$extension" == "mp4" || "$extension" == "mkv" || "$extension" == "wmv" || "$extension" == "dat" ]]; then
                # Check if the video is already HEVC
                local hevc_file="$dest/$name.mp4"
                if [ -f "$hevc_file" ]; then
                    echo "$item" >> "$FFMPEG_EXISTING_LOG"
                else
                    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$item")
                    if [[ $codec == "hevc" ]] ; then
                        echo "$item" >> "$HEVC_EXISTING_LOG"
                        cp "$item" "$hevc_file"
                    else
                        if ! ffmpeg -i "$item" -c:v libx265 -preset medium -crf 28 -c:a copy "$hevc_file"; then
                            echo "$item" >> "$FFMPEG_ERROR_LOG"
                        fi
                    fi
                fi
            else
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

#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <encoded_root> <original_root>"
    exit 1
}

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    usage
fi

# Directories
ENCODED_ROOT="$1"
ORIGINAL_ROOT="$2"
LOG_FILE="logs/failed_files.log"
mkdir -p logs
# Clear or create the log file
> "$LOG_FILE"

# Iterate over all encoded .mp4 files in the encoded directory recursively
find "$ENCODED_ROOT" -type f -name "*.mp4" | while read -r encoded_file; do
    # Get the relative path from the root of the encoded directory
    relative_path="${encoded_file#$ENCODED_ROOT/}"

    # Extract the base filename without extension
    base_name=$(basename "$encoded_file" .mp4)

    # Determine the corresponding path in the original directory
    original_dir="$ORIGINAL_ROOT/$(dirname "$relative_path")"

    # Search for a matching file in the corresponding directory in the original root
    original_file=$(find "$original_dir" -type f -name "$base_name.*" | head -n 1)

    if [[ -n "$original_file" ]]; then
        echo "Found original for $relative_path: $original_file"
        # Copy metadata from the original to the encoded file
        exiftool -tagsFromFile "$original_file" -overwrite_original "$encoded_file"
    else
        echo "Original file not found for $relative_path" | tee -a "$LOG_FILE"
    fi
done

echo "Processing complete. Failed files logged to $LOG_FILE."

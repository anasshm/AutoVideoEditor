#!/bin/bash

# Audio Replacer Script
# Takes one video and creates multiple versions with different audio tracks

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    print_error "ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

# Detect hardware acceleration
detect_hardware_acceleration() {
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_videotoolbox"; then
        echo "h264_videotoolbox"
    else
        echo "libx264"
    fi
}

ENCODER=$(detect_hardware_acceleration)
if [[ "$ENCODER" == "h264_videotoolbox" ]]; then
    QUALITY_PARAM="-b:v 10M -realtime 1 -prio_speed 1"
    print_success "Apple Silicon M2 hardware acceleration detected"
else
    QUALITY_PARAM="-crf 23 -preset fast"
    print_info "Using software encoding (libx264)"
fi

print_info "=== Audio Replacer Script ==="
echo ""
print_success "ffmpeg is available"
echo ""

# Get inputs
echo "Step 1: Source Video"
echo "Enter the full path to your video file:"
echo ""
echo -n "Video path: "
read MAIN_VIDEO

if [[ ! -f "$MAIN_VIDEO" ]]; then
    print_error "File not found: $MAIN_VIDEO"
    exit 1
fi

VIDEO_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MAIN_VIDEO" 2>/dev/null)
print_success "Video found: $(basename "$MAIN_VIDEO")"
print_info "Video duration: ${VIDEO_DURATION}s"
echo ""

echo "Step 2: Audio Folder"
echo "Enter the full path to the folder containing audio files:"
echo ""
echo -n "Audio folder path: "
read AUDIO_FOLDER

if [[ ! -d "$AUDIO_FOLDER" ]]; then
    print_error "Directory not found: $AUDIO_FOLDER"
    exit 1
fi
print_success "Folder found: $AUDIO_FOLDER"
echo ""

# Create output directory
MAIN_VIDEO_DIR=$(dirname "$MAIN_VIDEO")
VIDEO_NAME=$(basename "$MAIN_VIDEO" | sed 's/\.[^.]*$//')
WORK_DIR="${MAIN_VIDEO_DIR}/${VIDEO_NAME}_AudioReplacer"
mkdir -p "$WORK_DIR"
print_info "Output folder: $WORK_DIR"
echo ""

# Find audio files
print_info "Scanning for audio files..."
AUDIO_FILES=()
for ext in mp3 m4a aac wav flac ogg wma; do
    for file in "$AUDIO_FOLDER"/*.$ext; do
        if [[ -f "$file" ]]; then
            AUDIO_FILES+=("$file")
        fi
    done
done

if [[ ${#AUDIO_FILES[@]} -eq 0 ]]; then
    print_error "No audio files found in: $AUDIO_FOLDER"
    exit 1
fi

print_success "Found ${#AUDIO_FILES[@]} audio files"
echo ""

# Extract muted video once (with 9:16 fix)
MUTED_VIDEO="$WORK_DIR/temp_muted_video.mp4"
print_info "Extracting video without audio (applying 9:16 fix)..."
ffmpeg -hwaccel videotoolbox -i "$MAIN_VIDEO" \
    -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black" \
    -an -c:v "$ENCODER" $QUALITY_PARAM "$MUTED_VIDEO" -y -loglevel error
print_success "Muted video created"
echo ""

# Process each audio file
for i in "${!AUDIO_FILES[@]}"; do
    AUDIO_FILE="${AUDIO_FILES[$i]}"
    OUTPUT_NUMBER=$((i + 1))
    
    print_info "Processing $OUTPUT_NUMBER/${#AUDIO_FILES[@]}: $(basename "$AUDIO_FILE")"
    
    OUTPUT_FILE="$WORK_DIR/${VIDEO_NAME}_${OUTPUT_NUMBER}.mp4"
    
    # Combine muted video with audio
    print_info "  → Adding audio to video..."
    ffmpeg -i "$MUTED_VIDEO" -i "$AUDIO_FILE" \
        -c:v copy -c:a aac -shortest \
        "$OUTPUT_FILE" -y -loglevel error
    
    OUTPUT_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null)
    print_success "  → Created: ${VIDEO_NAME}_${OUTPUT_NUMBER}.mp4 (${OUTPUT_DURATION}s)"
    echo ""
done

# Clean up
rm -f "$MUTED_VIDEO"

print_success "=== COMPLETE ==="
print_info "Output location: $WORK_DIR"
print_info "Created ${#AUDIO_FILES[@]} videos with different audio tracks"
echo ""

# Show sample
SAMPLE_OUTPUT="$WORK_DIR/${VIDEO_NAME}_1.mp4"
if [[ -f "$SAMPLE_OUTPUT" ]]; then
    SAMPLE_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SAMPLE_OUTPUT" 2>/dev/null)
    print_info "Sample output file info:"
    print_info "  File: $(basename "$SAMPLE_OUTPUT")"
    print_info "  Duration: ${SAMPLE_DURATION}s"
    print_info "  Naming pattern: ${VIDEO_NAME}_1.mp4, ${VIDEO_NAME}_2.mp4, etc."
fi

print_success "Done! Check your output folder for the results."

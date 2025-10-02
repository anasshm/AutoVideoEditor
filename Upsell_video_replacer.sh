#!/bin/bash

# Upsell Video Replacer Script
# Replaces the end of each video with an upsell video (with looping if needed)
# Uses original video audio throughout

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

# Check ffmpeg and hardware acceleration
if ! command -v ffmpeg &> /dev/null; then
    print_error "ffmpeg not found. Install with: brew install ffmpeg"
    exit 1
fi

# Detect hardware acceleration support
detect_hardware_acceleration() {
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_videotoolbox"; then
        echo "h264_videotoolbox"
    else
        echo "libx264"
    fi
}

ENCODER=$(detect_hardware_acceleration)
if [[ "$ENCODER" == "h264_videotoolbox" ]]; then
    # Optimized settings for M2 Mac - balanced speed and quality
    QUALITY_PARAM="-b:v 10M -realtime 1 -prio_speed 1"  # Optimized for speed with excellent quality
    print_success "Apple Silicon M2 hardware acceleration detected (speed-optimized, excellent quality)"
else
    QUALITY_PARAM="-crf 23 -preset fast"  # Balanced quality for software encoding
    print_info "Using software encoding (libx264, balanced quality)"
fi

print_info "=== Upsell Video Replacer Script ==="
echo ""
print_success "ffmpeg is available"
echo ""

# Get inputs
echo "Step 1: Upsell Video (Main Video)"
echo "Please enter the full path to your upsell video (this will replace the end of each video):"
echo ""
echo -n "Upsell video path: "
read MAIN_VIDEO

if [[ ! -f "$MAIN_VIDEO" ]]; then
    print_error "File not found: $MAIN_VIDEO"
    exit 1
fi

# Get upsell video duration
UPSELL_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MAIN_VIDEO" 2>/dev/null)
UPSELL_DURATION_INT=$(echo "$UPSELL_DURATION" | cut -d. -f1)

print_success "Upsell video found: $(basename "$MAIN_VIDEO")"
print_info "Upsell video duration: ${UPSELL_DURATION}s"
echo ""

echo "Step 2: Videos Folder"
echo "Please enter the full path to the folder containing videos to process:"
echo ""
echo -n "Folder path: "
read VIDEO_FOLDER

if [[ ! -d "$VIDEO_FOLDER" ]]; then
    print_error "Directory not found: $VIDEO_FOLDER"
    exit 1
fi
print_success "Folder found: $VIDEO_FOLDER"
echo ""

echo "Step 3: When Should Upsell Video Start?"
echo "Please enter the time (in seconds) when the upsell video should start:"
echo "Example: If video is 30s and you say 17s, we'll keep first 17s and replace 17s-30s with upsell."
echo ""
echo -n "Start time for upsell (seconds): "
read START_TIME

if ! [[ "$START_TIME" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    print_error "Please enter a valid number"
    exit 1
fi

print_success "Upsell starts at: ${START_TIME} seconds"
echo ""

# Create working directory using the folder name
FOLDER_NAME=$(basename "$VIDEO_FOLDER")
WORK_DIR="${VIDEO_FOLDER}/${FOLDER_NAME}_Upsell"
mkdir -p "$WORK_DIR"
print_info "Output folder: $WORK_DIR"
echo ""

# Find video files
print_info "Scanning for video files..."
VIDEO_FILES=()
for ext in mp4 mov avi mkv m4v flv wmv; do
    for file in "$VIDEO_FOLDER"/*.$ext; do
        if [[ -f "$file" ]]; then
            VIDEO_FILES+=("$file")
        fi
    done
done

if [[ ${#VIDEO_FILES[@]} -eq 0 ]]; then
    print_error "No video files found in: $VIDEO_FOLDER"
    exit 1
fi

print_success "Found ${#VIDEO_FILES[@]} video files"
echo ""

# Process each video
for i in "${!VIDEO_FILES[@]}"; do
    VIDEO_FILE="${VIDEO_FILES[$i]}"
    OUTPUT_NUMBER=$((i + 1))
    
    print_info "Processing $OUTPUT_NUMBER/${#VIDEO_FILES[@]}: $(basename "$VIDEO_FILE")"
    
    # Get original video duration
    ORIGINAL_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE" 2>/dev/null)
    ORIGINAL_DURATION_INT=$(echo "$ORIGINAL_DURATION" | cut -d. -f1)
    
    # Calculate how much upsell time is needed
    UPSELL_NEEDED=$(echo "$ORIGINAL_DURATION - $START_TIME" | bc)
    UPSELL_NEEDED_INT=$(echo "$UPSELL_NEEDED" | cut -d. -f1)
    
    print_info "  → Original video: ${ORIGINAL_DURATION}s, keeping first ${START_TIME}s, replacing ${UPSELL_NEEDED}s"
    
    # Step 1: Extract audio from ORIGINAL video (this will be used for entire output)
    ORIGINAL_AUDIO="$WORK_DIR/original_audio_${i}.aac"
    print_info "  → Extracting audio from original video..."
    ffmpeg -i "$VIDEO_FILE" -vn -c:a aac "$ORIGINAL_AUDIO" -y -loglevel error
    
    # Step 2: Extract first part of original video (0 to START_TIME) - MUTED
    ORIGINAL_BEGINNING="$WORK_DIR/temp_original_beginning_${OUTPUT_NUMBER}.mp4"
    print_info "  → Extracting original video beginning (0 to ${START_TIME}s, muted, ${ENCODER})..."
    ffmpeg -i "$VIDEO_FILE" -t "$START_TIME" -an -c:v "$ENCODER" $QUALITY_PARAM "$ORIGINAL_BEGINNING" -y -loglevel error
    
    # Step 3: Prepare upsell section (loop if needed) - MUTED
    UPSELL_SECTION="$WORK_DIR/temp_upsell_${OUTPUT_NUMBER}.mp4"
    
    # Compare durations to determine if looping is needed
    NEEDS_LOOPING=$(echo "$UPSELL_NEEDED > $UPSELL_DURATION" | bc)
    
    if [[ "$NEEDS_LOOPING" -eq 1 ]]; then
        # Calculate how many full loops + partial loop needed
        FULL_LOOPS=$(echo "$UPSELL_NEEDED / $UPSELL_DURATION" | bc)
        REMAINING=$(echo "$UPSELL_NEEDED - ($FULL_LOOPS * $UPSELL_DURATION)" | bc)
        
        print_info "  → Upsell needs ${UPSELL_NEEDED}s, video is ${UPSELL_DURATION}s. Looping ${FULL_LOOPS} times + ${REMAINING}s"
        
        # Create loop file list
        LOOP_LIST="$WORK_DIR/temp_loop_list_${OUTPUT_NUMBER}.txt"
        rm -f "$LOOP_LIST"
        
        # Add full loops
        for ((j=0; j<=$FULL_LOOPS; j++)); do
            echo "file '$MAIN_VIDEO'" >> "$LOOP_LIST"
        done
        
        # Concatenate loops first - MUTED
        LOOPED_FULL="$WORK_DIR/temp_looped_full_${OUTPUT_NUMBER}.mp4"
        ffmpeg -f concat -safe 0 -i "$LOOP_LIST" -an -c:v "$ENCODER" $QUALITY_PARAM "$LOOPED_FULL" -y -loglevel error
        
        # Cut to exact duration needed
        ffmpeg -i "$LOOPED_FULL" -t "$UPSELL_NEEDED" -an -c:v "$ENCODER" $QUALITY_PARAM "$UPSELL_SECTION" -y -loglevel error
        
        rm -f "$LOOP_LIST" "$LOOPED_FULL"
        print_success "  → Created looped upsell section (muted): ${UPSELL_NEEDED}s"
    else
        # Upsell video is longer than needed, just cut it - MUTED
        print_info "  → Cutting upsell video to ${UPSELL_NEEDED}s (muted, ${ENCODER})..."
        ffmpeg -i "$MAIN_VIDEO" -t "$UPSELL_NEEDED" -an -c:v "$ENCODER" $QUALITY_PARAM "$UPSELL_SECTION" -y -loglevel error
    fi
    
    # Step 4: Concatenate original beginning + upsell section (both muted)
    print_info "  → Combining video segments (no audio)..."
    
    # Create concat list
    CONCAT_LIST="$WORK_DIR/temp_concat_${OUTPUT_NUMBER}.txt"
    echo "file '$ORIGINAL_BEGINNING'" > "$CONCAT_LIST"
    echo "file '$UPSELL_SECTION'" >> "$CONCAT_LIST"
    
    # Concatenate video parts (no audio)
    COMBINED_VIDEO="$WORK_DIR/temp_combined_${OUTPUT_NUMBER}.mp4"
    ffmpeg -f concat -safe 0 -i "$CONCAT_LIST" -c:v "$ENCODER" $QUALITY_PARAM "$COMBINED_VIDEO" -y -loglevel error
    
    # Step 5: Add original audio to the combined video
    OUTPUT_FILE="$WORK_DIR/${FOLDER_NAME}_${OUTPUT_NUMBER}.mp4"
    print_info "  → Adding original audio to entire video..."
    ffmpeg -i "$COMBINED_VIDEO" -i "$ORIGINAL_AUDIO" -c:v copy -c:a aac -shortest "$OUTPUT_FILE" -y -loglevel error
    
    # Verify output
    OUTPUT_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null)
    
    if [[ -f "$OUTPUT_FILE" ]]; then
        print_success "  → Created: ${FOLDER_NAME}_${OUTPUT_NUMBER}.mp4 (${OUTPUT_DURATION}s)"
    else
        print_error "  → Failed to create output"
    fi
    
    # Clean up intermediate files
    rm -f "$ORIGINAL_BEGINNING" "$UPSELL_SECTION" "$CONCAT_LIST" "$ORIGINAL_AUDIO" "$COMBINED_VIDEO"
    echo ""
done

print_success "=== COMPLETE ==="
print_info "Output location: $WORK_DIR"
print_info "Created ${#VIDEO_FILES[@]} output videos"
echo ""

# Show a sample of what was created
print_info "Sample output file info:"
SAMPLE_OUTPUT=$(find "$WORK_DIR" -name "${FOLDER_NAME}_*.mp4" | head -1)
if [[ -f "$SAMPLE_OUTPUT" ]]; then
    SAMPLE_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SAMPLE_OUTPUT" 2>/dev/null)
    print_info "  File: $(basename "$SAMPLE_OUTPUT")"
    print_info "  Duration: ${SAMPLE_DURATION}s"
    print_info "  Naming pattern: ${FOLDER_NAME}_1.mp4, ${FOLDER_NAME}_2.mp4, etc."
fi

print_success "Done! Check your output folder for the results."

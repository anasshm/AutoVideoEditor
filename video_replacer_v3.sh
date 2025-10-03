#!/bin/bash

# Simple Video Replacer Script - Version 3
# Uses the most straightforward approach for reliability

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

print_info "=== Video Replacer Script v3 ==="
echo ""
print_success "ffmpeg is available"
echo ""

# Get inputs
echo "Step 1: Main Video File"
echo "Please enter the full path to your main video file (the one with voiceover):"
echo ""
echo -n "Main video path: "
read MAIN_VIDEO

if [[ ! -f "$MAIN_VIDEO" ]]; then
    print_error "File not found: $MAIN_VIDEO"
    exit 1
fi
print_success "Main video found: $(basename "$MAIN_VIDEO")"
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

echo "Step 3: Target Length"
echo "Please enter the target length in seconds for replacement segments:"
echo ""
echo -n "Target length (seconds): "
read TARGET_LENGTH

if ! [[ "$TARGET_LENGTH" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    print_error "Please enter a valid number"
    exit 1
fi
print_success "Target length: ${TARGET_LENGTH} seconds"
echo ""

# Quality is now set to maximum by default - no user interaction needed

# Create working directory using the folder name of the main video
MAIN_VIDEO_DIR=$(dirname "$MAIN_VIDEO")
FOLDER_NAME=$(basename "$MAIN_VIDEO_DIR")
WORK_DIR="${MAIN_VIDEO_DIR}/${FOLDER_NAME}"
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
    # Create numbered output filename using folder name
    OUTPUT_NUMBER=$((i + 1))
    
    print_info "Processing $OUTPUT_NUMBER/${#VIDEO_FILES[@]}: $(basename "$VIDEO_FILE")"
    
    # Step 1: Extract audio from main video (this will be used throughout)
    MAIN_AUDIO="$WORK_DIR/main_audio_${i}.aac"
    print_info "  → Extracting audio from main video..."
    ffmpeg -hwaccel videotoolbox -i "$MAIN_VIDEO" -vn -c:a aac "$MAIN_AUDIO" -y -loglevel error
    
    # Step 2: Mute and cut the replacement video (0 to TARGET_LENGTH)
    PROCESSED_FILE="$WORK_DIR/temp_processed_${OUTPUT_NUMBER}.mp4"
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_FILE" 2>/dev/null | cut -d. -f1)
    
    if [[ -n "$DURATION" ]] && (( DURATION >= TARGET_LENGTH )); then
        print_info "  → Muting and cutting replacement video to ${TARGET_LENGTH}s (${ENCODER})..."
        ffmpeg -hwaccel videotoolbox -i "$VIDEO_FILE" -t "$TARGET_LENGTH" -an -c:v "$ENCODER" $QUALITY_PARAM "$PROCESSED_FILE" -y -loglevel error
    else
        print_info "  → Video is ${DURATION}s, need ${TARGET_LENGTH}s. Building composite video with fillers..."
        
        # Create list of video segments needed to reach target duration
        SEGMENT_LIST="$WORK_DIR/temp_segments_${OUTPUT_NUMBER}.txt"
        rm -f "$SEGMENT_LIST"
        
        CURRENT_DURATION=0
        REMAINING_NEEDED=$TARGET_LENGTH
        FILLER_INDEX=0
        
        # First, add the original video (full duration)
        ORIGINAL_SEGMENT="$WORK_DIR/temp_original_${OUTPUT_NUMBER}.mp4"
        ffmpeg -hwaccel videotoolbox -i "$VIDEO_FILE" -an -c:v "$ENCODER" $QUALITY_PARAM "$ORIGINAL_SEGMENT" -y -loglevel error
        echo "file '$ORIGINAL_SEGMENT'" >> "$SEGMENT_LIST"
        CURRENT_DURATION=$DURATION
        REMAINING_NEEDED=$((TARGET_LENGTH - DURATION))
        
        print_info "    → Added original video (${DURATION}s), still need ${REMAINING_NEEDED}s"
        
        # Add filler videos until we reach target duration
        while (( REMAINING_NEEDED > 0 )); do
            # Find next filler video (cycle through available videos, skip current one)
            FILLER_VIDEO_INDEX=$(( (i + 1 + FILLER_INDEX) % ${#VIDEO_FILES[@]} ))
            if [[ $FILLER_VIDEO_INDEX -eq $i ]]; then
                FILLER_VIDEO_INDEX=$(( (FILLER_VIDEO_INDEX + 1) % ${#VIDEO_FILES[@]} ))
            fi
            
            FILLER_VIDEO="${VIDEO_FILES[$FILLER_VIDEO_INDEX]}"
            FILLER_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILLER_VIDEO" 2>/dev/null | cut -d. -f1)
            
            # Determine how much of this filler video to use
            if (( FILLER_DURATION >= REMAINING_NEEDED )); then
                USE_DURATION=$REMAINING_NEEDED
            else
                USE_DURATION=$FILLER_DURATION
            fi
            
            # Create filler segment (muted, from beginning)
            FILLER_SEGMENT="$WORK_DIR/temp_filler_${OUTPUT_NUMBER}_${FILLER_INDEX}.mp4"
            if (( USE_DURATION == FILLER_DURATION )); then
                # Use full video
                ffmpeg -hwaccel videotoolbox -i "$FILLER_VIDEO" -an -c:v "$ENCODER" $QUALITY_PARAM "$FILLER_SEGMENT" -y -loglevel error
            else
                # Cut to needed duration
                ffmpeg -hwaccel videotoolbox -i "$FILLER_VIDEO" -t "$USE_DURATION" -an -c:v "$ENCODER" $QUALITY_PARAM "$FILLER_SEGMENT" -y -loglevel error
            fi
            
            echo "file '$FILLER_SEGMENT'" >> "$SEGMENT_LIST"
            CURRENT_DURATION=$((CURRENT_DURATION + USE_DURATION))
            REMAINING_NEEDED=$((REMAINING_NEEDED - USE_DURATION))
            
            print_info "    → Added filler from $(basename "$FILLER_VIDEO") (${USE_DURATION}s), total: ${CURRENT_DURATION}s, still need: ${REMAINING_NEEDED}s"
            
            FILLER_INDEX=$((FILLER_INDEX + 1))
            
            # Safety check to prevent infinite loop
            if [[ $FILLER_INDEX -gt ${#VIDEO_FILES[@]} ]]; then
                print_warning "    → Used all available videos, final duration: ${CURRENT_DURATION}s"
                break
            fi
        done
        
        # Concatenate all segments
        ffmpeg -f concat -safe 0 -i "$SEGMENT_LIST" -c:v "$ENCODER" $QUALITY_PARAM "$PROCESSED_FILE" -y -loglevel error
        
        # Clean up segment files
        rm -f "$ORIGINAL_SEGMENT"
        for ((j=0; j<FILLER_INDEX; j++)); do
            rm -f "$WORK_DIR/temp_filler_${OUTPUT_NUMBER}_${j}.mp4"
        done
        rm -f "$SEGMENT_LIST"
        
        print_success "    → Composite video created: ${CURRENT_DURATION}s total"
    fi
    
    # Step 3: Cut main video from TARGET_LENGTH to end (video only, no audio)
    MAIN_SEGMENT="$WORK_DIR/temp_main_segment_${OUTPUT_NUMBER}.mp4"
    print_info "  → Extracting main video segment (${TARGET_LENGTH}s to end, ${ENCODER})..."
    ffmpeg -hwaccel videotoolbox -i "$MAIN_VIDEO" -ss "$TARGET_LENGTH" -an -c:v "$ENCODER" $QUALITY_PARAM "$MAIN_SEGMENT" -y -loglevel error
    
    # Step 4: Combine videos (replacement + main segment) and add original audio
    OUTPUT_FILE="$WORK_DIR/${FOLDER_NAME}_${OUTPUT_NUMBER}.mp4"
    print_info "  → Combining videos and adding original audio..."
    
    # Create video list for concatenation
    LIST_FILE="$WORK_DIR/temp_list_${OUTPUT_NUMBER}.txt"
    echo "file '$PROCESSED_FILE'" > "$LIST_FILE"
    echo "file '$MAIN_SEGMENT'" >> "$LIST_FILE"
    
    # First, concatenate the video parts (no audio) - Hardware optimized
    COMBINED_VIDEO="$WORK_DIR/temp_combined_${OUTPUT_NUMBER}.mp4"
    ffmpeg -f concat -safe 0 -i "$LIST_FILE" -vf "scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black" -c:v "$ENCODER" $QUALITY_PARAM "$COMBINED_VIDEO" -y -loglevel error
    
    # Then, add the original audio to the combined video
    ffmpeg -i "$COMBINED_VIDEO" -i "$MAIN_AUDIO" -c:v copy -c:a aac -shortest "$OUTPUT_FILE" -y -loglevel error
    
    # Verify the output
    OUTPUT_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE" 2>/dev/null | cut -d. -f1)
    MAIN_DURATION=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MAIN_VIDEO" 2>/dev/null | cut -d. -f1)
    
    if [[ -f "$OUTPUT_FILE" ]] && [[ "$OUTPUT_DURATION" -gt 5 ]]; then
        print_success "  → Created: ${FOLDER_NAME}_${OUTPUT_NUMBER}.mp4 (${OUTPUT_DURATION}s)"
    else
        print_error "  → Failed to create proper output"
    fi
    
    # Clean up intermediate files (keep only the final numbered output)
    rm -f "$PROCESSED_FILE" "$MAIN_SEGMENT" "$LIST_FILE" "$MAIN_AUDIO" "$COMBINED_VIDEO"
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

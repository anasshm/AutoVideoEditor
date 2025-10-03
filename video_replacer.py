#!/usr/bin/env python3
"""
Video Replacer - Python Version
Replaces beginning of video with new videos, keeps the rest with original audio
"""

import os
import sys
import subprocess
from pathlib import Path

# Color codes for terminal output
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    NC = '\033[0m'

def print_info(msg):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {msg}")

def print_success(msg):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {msg}")

def print_error(msg):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {msg}")

def print_warning(msg):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {msg}")

def clean_path(path_str):
    """Remove backslash escapes from path and clean it"""
    # Remove backslash escapes (e.g., "\ " becomes " ")
    cleaned = path_str.replace('\\ ', ' ').strip()
    # Remove quotes if present
    if cleaned.startswith('"') and cleaned.endswith('"'):
        cleaned = cleaned[1:-1]
    if cleaned.startswith("'") and cleaned.endswith("'"):
        cleaned = cleaned[1:-1]
    return cleaned

def get_video_duration(video_path):
    """Get video duration in seconds using ffprobe"""
    cmd = [
        'ffprobe', '-v', 'quiet', '-show_entries', 
        'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1',
        video_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return float(result.stdout.strip())

def check_ffmpeg():
    """Check if ffmpeg is installed"""
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
        return True
    except:
        return False

def detect_encoder():
    """Detect hardware acceleration support"""
    try:
        result = subprocess.run(
            ['ffmpeg', '-hide_banner', '-encoders'],
            capture_output=True, text=True
        )
        if 'h264_videotoolbox' in result.stdout:
            return 'h264_videotoolbox', '-b:v 10M -realtime 1 -prio_speed 1'
        else:
            return 'libx264', '-crf 23 -preset fast'
    except:
        return 'libx264', '-crf 23 -preset fast'

def find_video_files(folder_path):
    """Find all video files in folder"""
    extensions = ['.mp4', '.mov', '.avi', '.mkv', '.m4v', '.flv', '.wmv']
    video_files = []
    
    for ext in extensions:
        video_files.extend(list(Path(folder_path).glob(f'*{ext}')))
        video_files.extend(list(Path(folder_path).glob(f'*{ext.upper()}')))
    
    return sorted(video_files)

def process_replacement_video(video_file, target_length, encoder, quality_params, work_dir, output_number, video_files, current_index):
    """Process replacement video with filler logic if needed"""
    duration = get_video_duration(str(video_file))
    processed_file = os.path.join(work_dir, f"temp_processed_{output_number}.mp4")
    
    if duration >= target_length:
        # Video is long enough, just cut and mute
        print_info(f"  → Muting and cutting replacement video to {target_length}s ({encoder})...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(video_file), '-t', str(target_length),
            '-an', '-c:v', encoder
        ] + quality_params.split() + [
            processed_file, '-y', '-loglevel', 'error'
        ], check=True)
    else:
        # Video is too short, need to add fillers
        print_info(f"  → Video is {duration}s, need {target_length}s. Building composite video with fillers...")
        
        # Create segment list
        segment_list = os.path.join(work_dir, f"temp_segments_{output_number}.txt")
        
        # Start with original video
        original_segment = os.path.join(work_dir, f"temp_original_{output_number}.mp4")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(video_file), '-an', '-c:v', encoder
        ] + quality_params.split() + [
            original_segment, '-y', '-loglevel', 'error'
        ], check=True)
        
        with open(segment_list, 'w') as f:
            f.write(f"file '{original_segment}'\n")
        
        current_duration = duration
        remaining_needed = target_length - duration
        filler_index = 0
        
        print_info(f"    → Added original video ({duration}s), still need {remaining_needed}s")
        
        # Add filler videos until we reach target
        while remaining_needed > 0 and filler_index <= len(video_files):
            # Find next filler video (cycle through, skip current)
            filler_video_index = (current_index + 1 + filler_index) % len(video_files)
            if filler_video_index == current_index:
                filler_video_index = (filler_video_index + 1) % len(video_files)
            
            filler_video = video_files[filler_video_index]
            filler_duration = get_video_duration(str(filler_video))
            
            # Determine how much to use
            use_duration = min(filler_duration, remaining_needed)
            
            # Create filler segment
            filler_segment = os.path.join(work_dir, f"temp_filler_{output_number}_{filler_index}.mp4")
            
            if use_duration == filler_duration:
                # Use full video
                subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(filler_video), '-an', '-c:v', encoder
                ] + quality_params.split() + [
                    filler_segment, '-y', '-loglevel', 'error'
                ], check=True)
            else:
                # Cut to needed duration
                subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(filler_video), '-t', str(use_duration),
                    '-an', '-c:v', encoder
                ] + quality_params.split() + [
                    filler_segment, '-y', '-loglevel', 'error'
                ], check=True)
            
            with open(segment_list, 'a') as f:
                f.write(f"file '{filler_segment}'\n")
            
            current_duration += use_duration
            remaining_needed -= use_duration
            
            print_info(f"    → Added filler from {filler_video.name} ({use_duration}s), total: {current_duration}s, still need: {remaining_needed}s")
            
            filler_index += 1
            
            if filler_index > len(video_files):
                print_warning(f"    → Used all available videos, final duration: {current_duration}s")
                break
        
        # Concatenate all segments
        subprocess.run([
            'ffmpeg', '-f', 'concat', '-safe', '0', '-i', segment_list,
            '-c:v', encoder
        ] + quality_params.split() + [
            processed_file, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Clean up segment files
        os.remove(original_segment)
        for j in range(filler_index):
            filler_file = os.path.join(work_dir, f"temp_filler_{output_number}_{j}.mp4")
            if os.path.exists(filler_file):
                os.remove(filler_file)
        os.remove(segment_list)
        
        print_success(f"    → Composite video created: {current_duration}s total")
    
    return processed_file

def main():
    print_info("=== Video Replacer (Python) ===")
    print()
    
    # Check ffmpeg
    if not check_ffmpeg():
        print_error("ffmpeg not found. Install with: brew install ffmpeg")
        sys.exit(1)
    
    print_success("ffmpeg is available")
    
    # Detect encoder
    encoder, quality_params = detect_encoder()
    if encoder == 'h264_videotoolbox':
        print_success("Apple Silicon M2 hardware acceleration detected (speed-optimized)")
    else:
        print_info("Using software encoding (libx264, balanced quality)")
    print()
    
    # Get inputs
    print("Step 1: Main Video File")
    print("Enter the full path to your main video file (the one with voiceover):")
    main_video = clean_path(input("Main video path: "))
    
    if not os.path.isfile(main_video):
        print_error(f"File not found: {main_video}")
        sys.exit(1)
    
    print_success(f"Main video found: {os.path.basename(main_video)}")
    print()
    
    print("Step 2: Videos Folder")
    print("Enter the full path to the folder containing videos to process:")
    video_folder = clean_path(input("Folder path: "))
    
    if not os.path.isdir(video_folder):
        print_error(f"Directory not found: {video_folder}")
        sys.exit(1)
    
    print_success(f"Folder found: {video_folder}")
    print()
    
    print("Step 3: Target Length")
    print("Enter the target length in seconds for replacement segments:")
    target_length = float(input("Target length (seconds): ").strip())
    
    print_success(f"Target length: {target_length}s")
    print()
    
    # Create working directory
    main_video_dir = os.path.dirname(main_video)
    folder_name = os.path.basename(main_video_dir)
    work_dir = os.path.join(main_video_dir, folder_name)
    os.makedirs(work_dir, exist_ok=True)
    print_info(f"Output folder: {work_dir}")
    print()
    
    # Find video files
    print_info("Scanning for video files...")
    video_files = find_video_files(video_folder)
    
    if not video_files:
        print_error(f"No video files found in: {video_folder}")
        sys.exit(1)
    
    print_success(f"Found {len(video_files)} video files")
    print()
    
    # Process each video
    for i, video_file in enumerate(video_files):
        output_number = i + 1
        print_info(f"Processing {output_number}/{len(video_files)}: {video_file.name}")
        
        # Step 1: Extract audio from main video
        main_audio = os.path.join(work_dir, f"main_audio_{i}.aac")
        print_info("  → Extracting audio from main video...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', main_video, '-vn', '-c:a', 'aac',
            main_audio, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Step 2: Process replacement video (with filler logic)
        processed_file = process_replacement_video(
            video_file, target_length, encoder, quality_params,
            work_dir, output_number, video_files, i
        )
        
        # Step 3: Cut main video from target_length to end (muted)
        main_segment = os.path.join(work_dir, f"temp_main_segment_{output_number}.mp4")
        print_info(f"  → Extracting main video segment ({target_length}s to end, {encoder})...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', main_video, '-ss', str(target_length),
            '-an', '-c:v', encoder
        ] + quality_params.split() + [
            main_segment, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Step 4: Combine videos and add original audio
        output_file = os.path.join(work_dir, f"{folder_name}_{output_number}.mp4")
        print_info("  → Combining videos and adding original audio...")
        
        # Create concat list
        concat_list = os.path.join(work_dir, f"temp_list_{output_number}.txt")
        with open(concat_list, 'w') as f:
            f.write(f"file '{processed_file}'\n")
            f.write(f"file '{main_segment}'\n")
        
        # Concatenate video parts (no audio)
        combined_video = os.path.join(work_dir, f"temp_combined_{output_number}.mp4")
        subprocess.run([
            'ffmpeg', '-f', 'concat', '-safe', '0', '-i', concat_list,
            '-vf', 'scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black',
            '-c:v', encoder
        ] + quality_params.split() + [
            combined_video, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Add original audio
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', combined_video, '-i', main_audio,
            '-c:v', 'copy', '-c:a', 'aac', '-shortest',
            output_file, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Clean up
        for temp_file in [processed_file, main_segment, concat_list, main_audio, combined_video]:
            if os.path.exists(temp_file):
                os.remove(temp_file)
        
        output_duration = get_video_duration(output_file)
        print_success(f"  → Created: {folder_name}_{output_number}.mp4 ({output_duration:.2f}s)")
        print()
    
    print_success("=== COMPLETE ===")
    print_info(f"Output location: {work_dir}")
    print_info(f"Created {len(video_files)} output videos")
    print()
    
    # Show sample
    sample_output = os.path.join(work_dir, f"{folder_name}_1.mp4")
    if os.path.exists(sample_output):
        sample_duration = get_video_duration(sample_output)
        print_info("Sample output file info:")
        print_info(f"  File: {os.path.basename(sample_output)}")
        print_info(f"  Duration: {sample_duration:.2f}s")
        print_info(f"  Naming pattern: {folder_name}_1.mp4, {folder_name}_2.mp4, etc.")
    
    print_success("Done! Check your output folder for the results.")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
        print_warning("Process interrupted by user")
        sys.exit(1)
    except Exception as e:
        print_error(f"An error occurred: {e}")
        sys.exit(1)

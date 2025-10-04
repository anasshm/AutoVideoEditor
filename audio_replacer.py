#!/usr/bin/env python3
"""
Audio Replacer - Python Version
Takes one video and creates multiple versions with different audio tracks
"""

import os
import sys
import subprocess
from pathlib import Path

# Color codes
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
    """Remove backslash escapes from path"""
    cleaned = path_str.replace('\\ ', ' ').strip()
    if cleaned.startswith('"') and cleaned.endswith('"'):
        cleaned = cleaned[1:-1]
    if cleaned.startswith("'") and cleaned.endswith("'"):
        cleaned = cleaned[1:-1]
    return cleaned

def get_video_duration(video_path):
    """Get video duration in seconds"""
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
    """Detect hardware acceleration"""
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

def find_audio_files(folder_path):
    """Find all audio files in folder"""
    extensions = ['.mp3', '.m4a', '.aac', '.wav', '.flac', '.ogg', '.wma']
    audio_files = []
    
    for ext in extensions:
        audio_files.extend(list(Path(folder_path).glob(f'*{ext}')))
        audio_files.extend(list(Path(folder_path).glob(f'*{ext.upper()}')))
    
    return sorted(audio_files)

def main():
    print_info("=== Audio Replacer (Python) ===")
    print()
    
    # Check ffmpeg
    if not check_ffmpeg():
        print_error("ffmpeg not found. Install with: brew install ffmpeg")
        sys.exit(1)
    
    print_success("ffmpeg is available")
    
    # Detect encoder
    encoder, quality_params = detect_encoder()
    if encoder == 'h264_videotoolbox':
        print_success("Apple Silicon M2 hardware acceleration detected")
    else:
        print_info("Using software encoding (libx264)")
    print()
    
    # Get inputs
    print("Step 1: Source Video")
    print("Enter the full path to your video file:")
    main_video = clean_path(input("Video path: "))
    
    if not os.path.isfile(main_video):
        print_error(f"File not found: {main_video}")
        sys.exit(1)
    
    video_duration = get_video_duration(main_video)
    print_success(f"Video found: {os.path.basename(main_video)}")
    print_info(f"Video duration: {video_duration:.2f}s")
    print()
    
    print("Step 2: Audio Folder")
    print("Enter the full path to the folder containing audio files:")
    audio_folder = clean_path(input("Audio folder path: "))
    
    if not os.path.isdir(audio_folder):
        print_error(f"Directory not found: {audio_folder}")
        sys.exit(1)
    
    print_success(f"Folder found: {audio_folder}")
    print()
    
    # Create output directory
    main_video_dir = os.path.dirname(main_video)
    video_name = Path(main_video).stem
    work_dir = os.path.join(main_video_dir, f"{video_name}_AudioReplacer")
    os.makedirs(work_dir, exist_ok=True)
    print_info(f"Output folder: {work_dir}")
    print()
    
    # Find audio files
    print_info("Scanning for audio files...")
    audio_files = find_audio_files(audio_folder)
    
    if not audio_files:
        print_error(f"No audio files found in: {audio_folder}")
        sys.exit(1)
    
    print_success(f"Found {len(audio_files)} audio files")
    print()
    
    # Step 1: Extract muted video once (with 9:16 fix)
    muted_video = os.path.join(work_dir, "temp_muted_video.mp4")
    print_info("Extracting video without audio (applying 9:16 fix)...")
    subprocess.run([
        'ffmpeg', '-hwaccel', 'videotoolbox', '-i', main_video,
        '-vf', 'scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black',
        '-an', '-c:v', encoder
    ] + quality_params.split() + [
        muted_video, '-y', '-loglevel', 'error'
    ], check=True)
    print_success("Muted video created")
    print()
    
    # Process each audio file
    for i, audio_file in enumerate(audio_files):
        output_number = i + 1
        print_info(f"Processing {output_number}/{len(audio_files)}: {audio_file.name}")
        
        output_file = os.path.join(work_dir, f"{video_name}_{output_number}.mp4")
        
        # Combine muted video with audio
        print_info("  → Adding audio to video...")
        subprocess.run([
            'ffmpeg', '-i', muted_video, '-i', str(audio_file),
            '-c:v', 'copy', '-c:a', 'aac', '-shortest',
            output_file, '-y', '-loglevel', 'error'
        ], check=True)
        
        output_duration = get_video_duration(output_file)
        print_success(f"  → Created: {video_name}_{output_number}.mp4 ({output_duration:.2f}s)")
        print()
    
    # Clean up
    os.remove(muted_video)
    
    print_success("=== COMPLETE ===")
    print_info(f"Output location: {work_dir}")
    print_info(f"Created {len(audio_files)} videos with different audio tracks")
    print()
    
    # Show sample
    sample_output = os.path.join(work_dir, f"{video_name}_1.mp4")
    if os.path.exists(sample_output):
        sample_duration = get_video_duration(sample_output)
        print_info("Sample output file info:")
        print_info(f"  File: {os.path.basename(sample_output)}")
        print_info(f"  Duration: {sample_duration:.2f}s")
        print_info(f"  Naming pattern: {video_name}_1.mp4, {video_name}_2.mp4, etc.")
    
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

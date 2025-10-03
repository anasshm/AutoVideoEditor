#!/usr/bin/env python3
"""
Upsell Video Replacer - Python Version
Replaces the end of each video with an upsell video
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

def main():
    print_info("=== Upsell Video Replacer (Python) ===")
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
    print("Step 1: Upsell Video")
    print("Enter the full path to your upsell video:")
    upsell_video = clean_path(input("Upsell video path: "))
    
    if not os.path.isfile(upsell_video):
        print_error(f"File not found: {upsell_video}")
        sys.exit(1)
    
    upsell_duration = get_video_duration(upsell_video)
    print_success(f"Upsell video found: {os.path.basename(upsell_video)}")
    print_info(f"Upsell video duration: {upsell_duration:.2f}s")
    print()
    
    print("Step 2: Videos Folder")
    print("Enter the full path to the folder containing videos:")
    video_folder = clean_path(input("Folder path: "))
    
    if not os.path.isdir(video_folder):
        print_error(f"Directory not found: {video_folder}")
        sys.exit(1)
    
    print_success(f"Folder found: {video_folder}")
    print()
    
    print("Step 3: When Should Upsell Start?")
    print("Enter the time (in seconds) when the upsell should start:")
    print("Example: If video is 30s and you say 17, we'll keep first 17s and replace rest with upsell.")
    start_time = float(input("Start time (seconds): ").strip())
    
    print_success(f"Upsell starts at: {start_time}s")
    print()
    
    # Create output directory
    folder_name = os.path.basename(video_folder.rstrip('/'))
    work_dir = os.path.join(video_folder, f"{folder_name}_Upsell")
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
        
        # Get original video duration
        original_duration = get_video_duration(str(video_file))
        upsell_needed = original_duration - start_time
        
        print_info(f"  → Original: {original_duration:.2f}s, keeping first {start_time}s, replacing {upsell_needed:.2f}s")
        
        # File paths
        original_audio = os.path.join(work_dir, f"original_audio_{i}.aac")
        original_beginning = os.path.join(work_dir, f"temp_original_beginning_{output_number}.mp4")
        upsell_section = os.path.join(work_dir, f"temp_upsell_{output_number}.mp4")
        concat_list = os.path.join(work_dir, f"temp_concat_{output_number}.txt")
        combined_video = os.path.join(work_dir, f"temp_combined_{output_number}.mp4")
        output_file = os.path.join(work_dir, f"{folder_name}_{output_number}.mp4")
        
        # Step 1: Extract audio from original video
        print_info("  → Extracting audio from original video...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(video_file), '-vn', '-c:a', 'aac',
            original_audio, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Step 2: Extract beginning of original video (muted)
        print_info(f"  → Extracting original video beginning (0 to {start_time}s, muted)...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', str(video_file), '-t', str(start_time),
            '-an', '-c:v', encoder
        ] + quality_params.split() + [
            original_beginning, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Step 3: Prepare upsell section (muted, loop if needed)
        if upsell_needed > upsell_duration:
            # Need to loop
            loops_needed = int(upsell_needed / upsell_duration) + 1
            print_info(f"  → Looping upsell video {loops_needed} times to fill {upsell_needed:.2f}s")
            
            # Create loop list
            loop_list = os.path.join(work_dir, f"temp_loop_{output_number}.txt")
            with open(loop_list, 'w') as f:
                for _ in range(loops_needed + 1):
                    f.write(f"file '{upsell_video}'\n")
            
            # Concatenate loops
            looped_full = os.path.join(work_dir, f"temp_looped_{output_number}.mp4")
            subprocess.run([
                'ffmpeg', '-f', 'concat', '-safe', '0', '-i', loop_list,
                '-an', '-c:v', encoder
            ] + quality_params.split() + [
                looped_full, '-y', '-loglevel', 'error'
            ], check=True)
            
            # Cut to exact duration
            subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', looped_full, '-t', str(upsell_needed),
                '-an', '-c:v', encoder
            ] + quality_params.split() + [
                upsell_section, '-y', '-loglevel', 'error'
            ], check=True)
            
            os.remove(loop_list)
            os.remove(looped_full)
        else:
            # Just cut upsell to needed duration
            print_info(f"  → Cutting upsell video to {upsell_needed:.2f}s (muted)...")
            subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', upsell_video, '-t', str(upsell_needed),
                '-an', '-c:v', encoder
            ] + quality_params.split() + [
                upsell_section, '-y', '-loglevel', 'error'
            ], check=True)
        
        # Step 4: Concatenate video segments
        print_info("  → Combining video segments...")
        with open(concat_list, 'w') as f:
            f.write(f"file '{original_beginning}'\n")
            f.write(f"file '{upsell_section}'\n")
        
        subprocess.run([
            'ffmpeg', '-f', 'concat', '-safe', '0', '-i', concat_list,
            '-vf', 'scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2:black',
            '-c:v', encoder
        ] + quality_params.split() + [
            combined_video, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Step 5: Add original audio
        print_info("  → Adding original audio to entire video...")
        subprocess.run([
            'ffmpeg', '-hwaccel', 'videotoolbox', '-i', combined_video, '-i', original_audio,
            '-c:v', 'copy', '-c:a', 'aac', '-shortest',
            output_file, '-y', '-loglevel', 'error'
        ], check=True)
        
        # Clean up
        for temp_file in [original_audio, original_beginning, upsell_section, concat_list, combined_video]:
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

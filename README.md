# AutoVideoEditor

A powerful FFmpeg-based video processing tool for batch video editing operations. This tool allows you to replace segments of a main video with multiple other videos while preserving the original audio track.

## 🚀 Quick Start (Fresh Mac Users)

**👉 [See QUICK_START.md for complete beginner guide](QUICK_START.md)**

### Super Quick Setup:
```bash
# 1. Install FFmpeg
brew install ffmpeg

# 2. Download and run
git clone https://github.com/anasshm/AutoVideoEditor.git
cd AutoVideoEditor
chmod +x video_replacer_v3.sh
./video_replacer_v3.sh
```

### What it does:
- **Input**: 1 main video + folder of replacement videos + target length (e.g., 3 seconds)
- **Output**: Multiple videos where first 3 seconds = replacement video, rest = original video with original audio

## Features

- **Batch Video Processing**: Process multiple videos from a folder automatically
- **Audio Preservation**: Maintains original audio from the main video throughout
- **Smart Video Replacement**: Replace the first N seconds of your main video with processed videos
- **Automatic Muting**: Mutes replacement videos to prevent audio conflicts
- **Flexible Duration**: Handles videos shorter than target length gracefully
- **Cross-Platform**: Works on macOS, Linux, and Windows (with FFmpeg installed)

## Use Case

Perfect for content creators who want to:
- Create multiple variations of a video with different intro segments
- Replace opening sequences while keeping original narration/music
- Batch process promotional videos with different visual content but same audio

## Prerequisites

- **FFmpeg**: Must be installed on your system
  ```bash
  # macOS
  brew install ffmpeg
  
  # Ubuntu/Debian
  sudo apt update && sudo apt install ffmpeg
  
  # Windows
  # Download from https://ffmpeg.org/download.html
  ```

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/anasshm/AutoVideoEditor.git
   cd AutoVideoEditor
   ```

2. Make the script executable:
   ```bash
   chmod +x video_replacer_v3.sh
   ```

## Usage

Run the interactive script:

```bash
./video_replacer_v3.sh
```

The script will prompt you for:

1. **Main Video Path**: Path to your primary video (with original audio/narration)
2. **Videos Folder**: Folder containing videos to use as replacements
3. **Target Length**: Duration in seconds for the replacement segment

### Example Workflow

```
Main Video: /path/to/main_video.mp4 (10 seconds long)
Videos Folder: /path/to/replacement_videos/ (contains 4 videos)
Target Length: 3 seconds

Result: 4 output videos, each 10 seconds long:
- Seconds 0-3: Different replacement video (muted)
- Seconds 3-10: Original main video with original audio
```

## How It Works

1. **Audio Extraction**: Extracts audio track from main video
2. **Video Processing**: Mutes and cuts replacement videos to target length
3. **Main Video Segmentation**: Cuts main video from target length to end
4. **Video Combination**: Concatenates replacement video + main video segment
5. **Audio Integration**: Adds original audio track to final video

## Output

- Creates a timestamped working directory
- Generates one output video for each video in the replacement folder
- Maintains original video quality and duration
- Preserves original audio throughout entire output

## Supported Formats

- **Input**: mp4, mov, avi, mkv, m4v, flv, wmv
- **Output**: mp4 (H.264 video, AAC audio)

## File Structure

```
AutoVideoEditor/
├── video_replacer_v3.sh    # Main processing script
├── README.md               # This file
└── examples/               # Example videos (if any)
```

## Technical Details

- Uses FFmpeg for all video processing operations
- Employs concat demuxer for reliable video joining
- Re-encodes videos to ensure compatibility (H.264/AAC)
- Handles different video formats and frame rates automatically

## Troubleshooting

### Common Issues

1. **FFmpeg not found**: Install FFmpeg using your system's package manager
2. **Permission denied**: Run `chmod +x video_replacer_v3.sh`
3. **File not found**: Ensure file paths are correct and files exist
4. **Audio sync issues**: Videos with different frame rates may need manual adjustment

### Error Messages

- **"No video files found"**: Check that the folder contains supported video formats
- **"Failed to create proper output"**: Verify input videos are not corrupted
- **"File not found"**: Double-check all file paths are correct

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- Built with [FFmpeg](https://ffmpeg.org/) - the leading multimedia framework
- Inspired by the need for efficient batch video processing workflows

---

**Note**: This tool is designed for content creators and video editors who need to process multiple video variations efficiently while maintaining audio consistency.

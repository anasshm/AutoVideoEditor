# Quick Start Guide - AutoVideoEditor

**Simple video processing for Mac users - replace video segments while keeping original audio**

## What You Need (Requirements)

### 1. A Mac Computer
- ✅ Works on any Mac (Intel or M1/M2)
- ✅ M1/M2 Macs get faster processing automatically

### 2. Install Homebrew (if you don't have it)
Open **Terminal** and paste this command:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Install FFmpeg
In **Terminal**, run:
```bash
brew install ffmpeg
```

## How to Get the Script

### Option 1: Download from GitHub
1. Go to: https://github.com/anasshm/AutoVideoEditor
2. Click the green "**Code**" button
3. Click "**Download ZIP**"
4. Unzip the file

### Option 2: Use Terminal (Advanced)
```bash
git clone https://github.com/anasshm/AutoVideoEditor.git
cd AutoVideoEditor
```

## How to Use

### Step 1: Open Terminal
- Press `Cmd + Space`
- Type "Terminal" 
- Press Enter

### Step 2: Navigate to the Script
```bash
cd /path/to/AutoVideoEditor
```
*(Replace `/path/to/AutoVideoEditor` with where you downloaded it)*

### Step 3: Make Script Executable
```bash
chmod +x video_replacer_v3.sh
```

### Step 4: Run the Script
```bash
./video_replacer_v3.sh
```

### Step 5: Follow the Prompts
The script will ask you for:

1. **Main video path**: Your main video file (with the audio you want to keep)
   ```
   Example: /Users/yourname/Desktop/main_video.mp4
   ```

2. **Folder path**: Folder containing videos you want to use as replacements
   ```
   Example: /Users/yourname/Desktop/replacement_videos
   ```

3. **Target length**: How many seconds to replace (usually 3-5 seconds)
   ```
   Example: 3
   ```

## What You Get

- **Multiple output videos** (one for each replacement video)
- **Same length as your main video**
- **Original audio throughout** 
- **First X seconds**: Replacement video (muted)
- **Rest of video**: Your original video

## Example Workflow

```
Main Video: my_narration.mp4 (10 seconds)
Replacement Folder: contains video1.mp4, video2.mp4, video3.mp4
Target Length: 3 seconds

Results:
├── output_video1.mp4 (10 seconds: 3s video1 + 7s original)
├── output_video2.mp4 (10 seconds: 3s video2 + 7s original) 
└── output_video3.mp4 (10 seconds: 3s video3 + 7s original)
```

## File Path Tips

### Finding File Paths on Mac:
1. Open **Finder**
2. Find your file/folder
3. **Right-click** → "**Get Info**"
4. Copy the path from "**Where:**"

### Or drag and drop:
1. Type the command but don't press Enter
2. **Drag your file** from Finder into Terminal
3. The path appears automatically
4. Press Enter

## Troubleshooting

### "Command not found: ffmpeg"
- Run: `brew install ffmpeg`
- Wait for installation to complete

### "Permission denied"
- Run: `chmod +x video_replacer_v3.sh`

### "File not found"
- Check your file paths are correct
- Use the drag-and-drop method for paths

### "No video files found"
- Make sure your folder contains: .mp4, .mov, .avi, .mkv files
- Check the folder path is correct

## Supported Video Formats

**Input**: mp4, mov, avi, mkv, m4v, flv, wmv  
**Output**: mp4 (highest quality)

---

**That's it!** The script does everything automatically with maximum quality settings. Perfect for content creators who need multiple video variations quickly! 🚀

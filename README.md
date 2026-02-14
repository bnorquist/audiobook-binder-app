# Audiobook Binder

A native macOS app that combines a folder of MP3 files into a single M4B audiobook with chapters, metadata, and cover art.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.10-orange)

## Features

- **Drag-and-drop import** — drop a folder of MP3s or use the file picker
- **Automatic metadata detection** — reads ID3 tags (title, author, narrator, year, genre) from your files
- **Chapter editing** — rename, reorder chapters; titles are derived from ID3 tags or cleaned filenames
- **Cover art** — auto-detects images in the folder, or choose your own
- **M4B conversion** — uses ffmpeg to concatenate and re-encode with AAC (prefers Apple's `aac_at` encoder when available)
- **Real-time progress** — percentage, elapsed/remaining time, and duration tracking during conversion

## Installation

1. Download `AudiobookBinder.dmg` from the [latest release](../../releases/latest)
2. Open the DMG and drag **Audiobook Binder** to your Applications folder
3. On first launch, right-click the app and select **Open** (macOS requires this for apps from unidentified developers)

After the first open, the app launches normally.

## Usage

### 1. Import

Drop a folder of MP3 files onto the window, or click **Choose Folder** to select one. The app probes each file with `ffprobe` to read duration, bitrate, sample rate, and ID3 tags.

### 2. Edit

The edit view has two panels:

- **Left — Chapter list**: Files become chapters, sorted in Finder order (natural sort). Drag to reorder, click to rename. Chapter titles come from ID3 `title` tags when present, otherwise from cleaned filenames (e.g., `01_intro.mp3` becomes "Intro").
- **Right — Metadata & cover art**: Title, author, narrator, series, year, genre, and description fields. The app pre-fills these from consistent ID3 tags across all files. Add or change cover art with the image picker.

Click **Convert** in the toolbar (or press Cmd+Return) when ready. A save dialog lets you choose the output location.

### 3. Convert

The app concatenates all MP3s and re-encodes to AAC in an M4B container using ffmpeg. Progress shows percentage, duration processed vs. total, and estimated time remaining. Click **Cancel** in the toolbar to abort.

The output bitrate matches the highest input bitrate (clamped to 64-256 kbps). The app prefers Apple's hardware-accelerated `aac_at` encoder when available, falling back to the software `aac` encoder.

### 4. Done

Shows the completed file with size, duration, and chapter count. Use **Show in Finder** to locate the file or **Convert Another File** to start over.

## Development

### Prerequisites

The app bundles its own `ffmpeg` and `ffprobe` binaries — they are not included in the repo due to their size.

1. **Download static ffmpeg and ffprobe binaries for macOS:**

   ```bash
   # Option A: Download from evermeet.cx (macOS universal builds)
   curl -L https://evermeet.cx/ffmpeg/ffmpeg-7.1.1.zip -o ffmpeg.zip
   curl -L https://evermeet.cx/ffmpeg/ffprobe-7.1.1.zip -o ffprobe.zip
   unzip ffmpeg.zip && unzip ffprobe.zip

   # Option B: Install via Homebrew and copy
   brew install ffmpeg
   cp $(which ffmpeg) ffmpeg
   cp $(which ffprobe) ffprobe
   ```

2. **Place the binaries in the app's Resources directory:**

   ```bash
   mkdir -p AudiobookBinder/Resources
   cp ffmpeg ffprobe AudiobookBinder/Resources/
   chmod +x AudiobookBinder/Resources/ffmpeg AudiobookBinder/Resources/ffprobe
   ```

   These paths are gitignored. The app expects them at `AudiobookBinder/Resources/ffmpeg` and `AudiobookBinder/Resources/ffprobe`.

3. **Open in Xcode and ensure the binaries are in the build target:**

   In Xcode, verify that `ffmpeg` and `ffprobe` appear under **Build Phases > Copy Bundle Resources**. If not, drag them from the Resources folder in the project navigator into that build phase.

### Build and Run

```bash
open AudiobookBinder.xcodeproj
# Press Cmd+R in Xcode to build and run
```

Requires macOS 14+ and Xcode 15+.

### Building the DMG

```bash
# Build Release configuration
xcodebuild -scheme AudiobookBinder -configuration Release build

# Create DMG (adjust DerivedData path as needed)
APP_PATH="$(xcodebuild -scheme AudiobookBinder -configuration Release -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')/AudiobookBinder.app"
STAGING=$(mktemp -d)
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Audiobook Binder" -srcfolder "$STAGING" -ov -format UDZO AudiobookBinder.dmg
rm -rf "$STAGING"
```

## Architecture

```
AudiobookBinder/
├── App/
│   ├── AudiobookBinderApp.swift    # App entry point, window configuration
│   └── ContentView.swift           # Root view with NavigationStack, toolbar, state routing
├── Models/
│   ├── AudioFile.swift             # Probed audio file (path, duration, bitrate, tags)
│   ├── Chapter.swift               # Chapter with title, start/end timestamps, source file
│   └── BookMetadata.swift          # Book metadata fields (title, author, etc.)
├── ViewModels/
│   └── AppViewModel.swift          # Central state management (@Observable)
├── Views/
│   ├── ImportView.swift            # Drag-and-drop / folder picker
│   ├── EditView.swift              # HSplitView with chapter list + metadata panel
│   ├── ConvertingView.swift        # Progress display during ffmpeg conversion
│   ├── DoneView.swift              # Completion summary with file details
│   └── Components/
│       ├── ChapterRowView.swift    # Individual chapter row with inline rename
│       ├── CoverArtView.swift      # Cover art display/picker
│       └── MetadataFormView.swift  # Grouped form for book metadata
├── Services/
│   ├── FileDiscoveryService.swift  # MP3 discovery + cover image detection + error types
│   ├── FFProbeService.swift        # Parallel ffprobe execution + JSON parsing
│   ├── FFmpegService.swift         # ffmpeg conversion with AsyncThrowingStream progress
│   └── MetadataService.swift       # Chapter name resolution + metadata detection + bitrate logic
├── Utilities/
│   ├── BundledBinary.swift         # Resolves ffmpeg/ffprobe from app bundle
│   ├── DurationFormatter.swift     # Milliseconds → "H:MM:SS" / "M:SS"
│   ├── FFMetadataWriter.swift      # Generates FFMETADATA1 format for chapters + tags
│   └── FilenameClean.swift         # Cleans filenames into chapter titles
└── Assets.xcassets/                # App icon + asset catalog
```

### How Conversion Works

1. **File discovery** (`FileDiscoveryService`) finds all `.mp3` files in the selected folder, natural-sorted by filename.

2. **Probing** (`FFProbeService`) runs `ffprobe` on each file in parallel (up to 8 concurrent) to extract duration, bitrate, sample rate, and ID3 tags. Results are returned in the original file order.

3. **Metadata detection** (`MetadataService`) scans for consistent tags across all files — if every file has the same `album` tag, that becomes the book title; same `artist` becomes the author, etc. Chapter names prefer the ID3 `title` tag, falling back to cleaned filenames.

4. **Conversion** (`FFmpegService`) builds and runs a single ffmpeg command that:
   - Concatenates all MP3s using ffmpeg's concat demuxer (via a temporary file list)
   - Re-encodes audio to AAC using `aac_at` (Apple AudioToolbox) or `aac` (software fallback)
   - Embeds chapter markers and metadata via a generated FFMETADATA1 file
   - Attaches cover art as an attached picture stream (if provided)
   - Streams progress via `--progress pipe:1`, parsed line-by-line for `out_time_us`

5. **State management** (`AppViewModel`) is a single `@Observable` class that drives all four app states (importing → editing → converting → done) with the view layer reacting to property changes.

## License

MIT

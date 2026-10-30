# VidCropper

A fast, native macOS video cropper built with Swift, SwiftUI and AVFoundation.

Crop freeform or to a preset aspect ratio, trim the clip, pad the frame with black bars
(letterbox) to make a landscape video taller, and upscale soft footage — all locally on
your Mac, with a live WYSIWYG preview of exactly what gets exported.

---

## Features

- **Open anything AVFoundation reads** — MP4, MOV, M4V and other common video containers, via `⌘O` or drag & drop.
- **Freeform + 9 aspect presets** — 9:16, 16:9, 4:5, 1:1, 4:3, 3:4, 3:2, 2:3, 21:9.
- **Direct-manipulation crop frame** — drag inside the frame to reposition, drag a corner to resize.
- **Letterbox padding (black bars)** — pull the top or bottom edge of the crop frame past the video edge to grow the canvas taller than the source. The video stays visible in the middle by default and can be dragged up or down to control how much free space sits above and below it. There's a **Center** button to snap it back.
- **Rotated footage handled correctly** — 90°, 180° and 270° rotation metadata is respected for both the preview and the export.
- **Trim with in/out handles** — dual-handle range bar with a 0.2 s minimum clip length.
- **Preview crop toggle** — flip between the editing overlay and a clean look at the final framing.
- **Upscaling (2× / 3× / 4×)** — Lanczos resampling plus an unsharp-mask pass, rendered on the GPU with Core Image.
- **Safe export** — H.264 (`.mp4` / `.mov`), never overwrites the source file, with a progress bar and cancel button.
- **Reveal in Finder** straight from the completion toast.
- **Dark, distraction-free UI** — system rounded typography with neon accent highlights.

---

## Requirements

| | |
|---|---|
| OS | macOS 14.0 (Sonoma) or later |
| Toolchain | Swift 5.9+ (Xcode 15+ or the Command Line Tools) |
| Architecture | Apple Silicon or Intel |

---

## Build & Run

VidCropper ships as a source-only project — you build the `.app` bundle yourself. This is
deliberate: the app needs a real `.app` bundle for correct windowing behaviour, so
`swift run` is **not** supported.

```bash
git clone https://github.com/baghuz/VidCropper-macOS.git
cd VidCropper-macOS

# Build the release bundle into ./dist
./build.sh

# Or build and launch in one go
./run.sh
```

The result is `dist/VidCropper.app`:

```bash
open dist/VidCropper.app
```

### First launch on macOS

Because the build is ad-hoc signed rather than notarized, macOS Gatekeeper may block it
with an *"unidentified developer"* warning. Clear the quarantine flag once:

```bash
xattr -dr com.apple.quarantine dist/VidCropper.app
```

Then right-click the app and choose **Open**, or open it again normally.

---

## Usage

1. **Open a video** — `⌘O`, the **Open video** button in the top bar, or drag a file onto the window.
2. **Pick a crop** — choose an aspect preset in the sidebar, or stay on **Free** for a freeform box.
3. **Adjust the frame** — drag inside the frame to move it, drag a corner to resize.
4. **Add black bars (optional)** — pull the top or bottom edge of the frame past the video
   edge. The canvas grows, the extra area fills with black, and the video sits centered.
   Drag the frame to move the video up or down, or hit **Center** to reset it.
5. **Trim (optional)** — drag the in/out handles on the trim bar under the canvas.
6. **Upscale (optional)** — pick **2×**, **3×** or **4×** in the sidebar to scale and sharpen the crop.
7. **Check the framing** — hit **Preview crop** to see the result without the overlay.
8. **Export** — `⌘E` or the **Export crop** button, then choose where to save. Use **Show in Finder**
   from the toast when it finishes.

### Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘O` | Open a video |
| `⌘E` | Export the crop |
| `Space` | Play / pause |

---

## Supported formats

| | |
|---|---|
| Input | MP4, MOV, M4V and other AVFoundation-readable video files |
| Output | MP4 or MOV, H.264 video, source audio preserved |

---

## How it works

- **Cropping & padding** — the crop is stored as a normalized rect with a top-left origin
  that is allowed to go negative or exceed `1.0`. A negative origin (or an oversized height)
  is what becomes black padding: the export pipeline translates the video layer by the crop
  origin, and AVFoundation's default black background fills whatever the crop extends past
  the footage.
- **Export** — an `AVMutableVideoComposition` with a `AVMutableVideoCompositionLayerInstruction`
  renders the crop. Trimming is applied via a clamped `CMTimeRange` so a range past the asset
  duration never silently exports the whole clip.
- **Upscaling** — a custom Core Image compositor draws the visible region over a solid black
  extent, applies a Lanczos scale, then an unsharp mask, and renders straight to the encoder
  through a pixel-buffer adaptor.
- **Encoder safety rails** — H.264 level 5.1 ceilings are enforced (`4096 px` on the long edge,
  ~9.4 MP per frame), the padded canvas is capped at `3.5×` the source height, and at least
  `5%` of the video must stay visible so the frame can never end up completely empty. Odd
  dimensions are rounded to even numbers because H.264 requires it.

---

## Project layout

```
.
├── Sources/VidCropper/
│   ├── VidCropperApp.swift   # App entry point, window setup
│   ├── ContentView.swift     # Root layout, top bar, drop target
│   ├── EditorModel.swift     # State, loading, export pipeline, upscaling compositor
│   ├── VideoCanvas.swift     # Preview stage, padded canvas layout, player surface
│   ├── CropOverlay.swift     # Crop frame, handles, drag gestures
│   ├── PlayerBar.swift       # Playback controls and trim range bar
│   ├── Sidebar.swift         # Aspect presets, crop summary, upscale, export footer
│   ├── CropMath.swift        # Crop geometry, clamping, export pixel rect maths
│   ├── Models.swift          # Aspect presets, output formats, error types, formatters
│   ├── Theme.swift           # Colors, typography, shared UI components
│   └── Overlays.swift        # Export progress overlay and toast
├── Resources/                # Info.plist and generated app icon
├── Tools/make_icon.swift     # Regenerates AppIcon.icns from the iconset
├── build.sh                  # Release build + .app assembly + ad-hoc signing
├── run.sh                    # build.sh, then launch the app
└── Package.swift             # SwiftPM manifest (macOS 14+, executable product)
```

---

## Roadmap

- **AI enhance (Real-ESRGAN)** — the option is present in the UI but disabled and marked
  `SOON`. It will add a super-resolution pass for footage that needs detail rebuilt rather
  than just sharpened.
- **Notarized / signed releases** so Gatekeeper doesn't need to be worked around.
- **Clean-up of remaining Swift concurrency `Sendable` warnings.**

---

## License

Released under the **MIT License**. See [LICENSE](LICENSE) for the full text.

---

## Acknowledgements

Built on Apple's SwiftUI, AVFoundation, Core Image and AppKit frameworks. No third-party
dependencies.

import AVFoundation
import SwiftUI

struct VideoCanvas: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasBackdrop()

                if model.videoURL != nil, model.displaySize.width > 0 {
                    if model.isPreviewingCrop {
                        cropPreview(in: geometry.size)
                    } else {
                        videoContent(in: geometry.size)
                    }
                } else if model.isLoading {
                    LoadingCard()
                } else {
                    EmptyState()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if model.videoURL != nil, model.displaySize.width > 0 {
                    PreviewToggle()
                        .padding(.top, 14)
                        .padding(.trailing, 16)
                }
            }
        }
        .background(Theme.canvas)
    }

    @ViewBuilder
    private func videoContent(in containerSize: CGSize) -> some View {
        let available = CGSize(
            width: max(80, containerSize.width - 88),
            height: max(80, containerSize.height - 76)
        )
        let layout = stageLayout(inside: available)

        ZStack(alignment: .topLeading) {
            Color.black

            if let posterImage = model.posterImage {
                Image(nsImage: posterImage)
                    .resizable()
                    .frame(width: layout.videoFrame.width, height: layout.videoFrame.height)
                    .offset(x: layout.videoFrame.minX, y: layout.videoFrame.minY)
            }

            VideoPlayerSurface(player: model.player)
                .frame(width: layout.videoFrame.width, height: layout.videoFrame.height)
                .offset(x: layout.videoFrame.minX, y: layout.videoFrame.minY)

            CropOverlay(
                crop: $model.crop,
                displaySize: model.displaySize,
                aspectRatio: model.aspect.ratio,
                videoRect: layout.videoFrame
            )
            .frame(width: layout.stageSize.width, height: layout.stageSize.height)

            if model.isLoading {
                LoadingCard(compact: true)
            }
        }
        .frame(width: layout.stageSize.width, height: layout.stageSize.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 32, y: 16)
        .animation(.easeInOut(duration: 0.2), value: layout.stageSize)
    }

    /// The video plus any padding the crop box adds around it. Everything is
    /// scaled together so the whole output canvas stays inside `bounds`.
    private func stageLayout(inside bounds: CGSize) -> (stageSize: CGSize, videoFrame: CGRect) {
        let source = model.displaySize
        guard source.width > 0, source.height > 0 else { return (.zero, .zero) }

        let cropPixels = CGRect(
            x: model.crop.minX * source.width,
            y: model.crop.minY * source.height,
            width: model.crop.width * source.width,
            height: model.crop.height * source.height
        )
        let union = CGRect(origin: .zero, size: source).union(cropPixels)

        guard union.width > 0, union.height > 0, bounds.width > 0, bounds.height > 0 else {
            return (source, CGRect(origin: .zero, size: source))
        }

        let scale = min(bounds.width / union.width, bounds.height / union.height)
        let stageSize = CGSize(
            width: max(1, (union.width * scale).rounded(.down)),
            height: max(1, (union.height * scale).rounded(.down))
        )
        let videoFrame = CGRect(
            x: (0 - union.minX) * scale,
            y: (0 - union.minY) * scale,
            width: max(1, (source.width * scale).rounded(.down)),
            height: max(1, (source.height * scale).rounded(.down))
        )
        return (stageSize, videoFrame)
    }

    /// Shows only the area inside the crop frame, exactly as it will be exported.
    @ViewBuilder
    private func cropPreview(in containerSize: CGSize) -> some View {
        let available = CGSize(
            width: max(80, containerSize.width - 88),
            height: max(80, containerSize.height - 76)
        )
        let cropPixels = CropMath.pixelSize(for: model.crop, displaySize: model.displaySize)
        let fitted = fittedSize(source: cropPixels, inside: available)
        let scale = min(fitted.width / cropPixels.width, fitted.height / cropPixels.height)
        let previewSize = CGSize(
            width: max(1, cropPixels.width * scale),
            height: max(1, cropPixels.height * scale)
        )
        let sourceSize = CGSize(
            width: model.displaySize.width * scale,
            height: model.displaySize.height * scale
        )
        let offset = CGSize(
            width: -model.crop.minX * sourceSize.width,
            height: -model.crop.minY * sourceSize.height
        )

        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("PREVIEW")
                    .font(.mono(8.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.accent)
                Text("·")
                    .foregroundStyle(Theme.textTertiary)
                Text(verbatim: "\(Int(cropPixels.width))×\(Int(cropPixels.height)) · \(model.outputFormat.label)")
                    .font(.mono(8.5, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Theme.panel.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            ZStack(alignment: .topLeading) {
                Color.black

                if let posterImage = model.posterImage {
                    Image(nsImage: posterImage)
                        .resizable()
                        .frame(width: sourceSize.width, height: sourceSize.height)
                        .offset(x: offset.width, y: offset.height)
                }

                VideoPlayerSurface(player: model.player)
                    .frame(width: sourceSize.width, height: sourceSize.height)
                    .offset(x: offset.width, y: offset.height)

                if model.isLoading {
                    LoadingCard(compact: true)
                }
            }
            // The stack is larger than the visible frame, so pin it top-leading
            // before clipping; centering it would reveal the wrong region.
            .frame(width: previewSize.width, height: previewSize.height, alignment: .topLeading)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.55), radius: 32, y: 16)
        }
        .animation(.easeInOut(duration: 0.2), value: previewSize)
    }

    private func fittedSize(source: CGSize, inside bounds: CGSize) -> CGSize {
        guard source.width > 0, source.height > 0,
              bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(
            width: max(1, (source.width * scale).rounded(.down)),
            height: max(1, (source.height * scale).rounded(.down))
        )
    }
}

private struct PreviewToggle: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                model.isPreviewingCrop.toggle()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: model.isPreviewingCrop ? "crop" : "eye")
                    .font(.system(size: 11, weight: .semibold))
                Text(model.isPreviewingCrop ? "Edit frame" : "Preview crop")
                    .font(.ui(11.5, weight: .semibold))
            }
            .foregroundStyle(
                model.isPreviewingCrop
                    ? Color(hex: 0x111408)
                    : (isHovered ? Theme.textPrimary : Theme.textSecondary)
            )
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                model.isPreviewingCrop
                    ? Theme.accent
                    : (isHovered ? Theme.cardHover : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovered = $0 }
        .help(
            model.isPreviewingCrop
                ? "Back to the crop frame"
                : "Preview exactly what will be exported"
        )
    }
}

struct CanvasBackdrop: View {
    var body: some View {
        ZStack {
            Theme.canvas

            RadialGradient(
                colors: [Theme.accent.opacity(0.055), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 620
            )

            RadialGradient(
                colors: [Color(hex: 0x3C65FF).opacity(0.05), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 560
            )

            Canvas { context, size in
                let spacing: CGFloat = 24
                let dot = Color.white.opacity(0.04)
                var x: CGFloat = 12
                while x < size.width {
                    var y: CGFloat = 12
                    while y < size.height {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                            with: .color(dot)
                        )
                        y += spacing
                    }
                    x += spacing
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct EmptyState: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 20) {
            CropIllustration()

            VStack(spacing: 8) {
                Text("Crop video for any format")
                    .font(.ui(25, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Choose a clip, frame the shot, and export a clean crop.\nThe original video is never modified.")
                    .font(.ui(12.5))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                model.chooseVideo()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Choose a video")
                        .font(.ui(13, weight: .bold))
                }
                .foregroundStyle(Color(hex: 0x111408))
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Theme.accent.opacity(isHovered ? 0.26 : 0.14), radius: 16, y: 6)
            }
            .buttonStyle(PressableButtonStyle())
            .onHover { isHovered = $0 }

            Text("or drop a video anywhere in this window")
                .font(.ui(10.5, weight: .medium))
                .foregroundStyle(Theme.textTertiary)

            HStack(spacing: 7) {
                ForEach(["MP4", "MOV", "M4V"], id: \.self) { format in
                    Text(format)
                        .font(.mono(9, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 30)
        .background(Theme.panel.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Color.white.opacity(0.075),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct CropIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
                .frame(width: 220, height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.borderStrong, lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x4F3FDB), Color(hex: 0xB0488C), Color(hex: 0xE39B57)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 176, height: 100)
                .overlay(alignment: .center) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .overlay(alignment: .topLeading) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(14)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.18))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 2)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                        .offset(
                            x: (index == 0 || index == 2) ? -43 : 43,
                            y: (index < 2) ? -51 : 51
                        )
                }
            }
            .frame(width: 88, height: 104)
            .offset(x: 20)

            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.72))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.88))
                .clipShape(Circle())
                .offset(x: -54, y: 30)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        }
        .frame(width: 232, height: 144)
    }
}

struct LoadingCard: View {
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
            Text("Loading video…")
                .font(.ui(12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(compact ? Color.black.opacity(0.2) : Color.clear)
    }
}

struct VideoPlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }
}

final class PlayerLayerView: NSView {
    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = NSColor.clear.cgColor
        playerLayer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

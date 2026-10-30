import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var model: EditorModel

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 7),
        count: 3
    )

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        SectionLabel(title: "Crop frame")
                        Spacer()
                        if model.hasPadding {
                            Button {
                                model.centerCropVertically()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.and.down")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Center")
                                        .font(.ui(10.5, weight: .semibold))
                                }
                                .foregroundStyle(Theme.textSecondary)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .help("Center the video inside the padded canvas")
                        }
                        Button {
                            model.resetCrop()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Reset")
                                    .font(.ui(10.5, weight: .semibold))
                            }
                            .foregroundStyle(Theme.textSecondary)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(model.videoURL == nil)
                    }

                    CropSummaryCard()

                    HStack {
                        SectionLabel(title: "Aspect ratio")
                        Spacer()
                        Text(model.aspect.name)
                            .font(.ui(10, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(AspectPreset.allCases) { preset in
                            AspectButton(
                                preset: preset,
                                isSelected: model.aspect == preset
                            ) {
                                model.selectAspect(preset)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 1)
                        Text("Drag inside the frame to reposition it. Drag a corner to resize. Pull a top or bottom edge past the video to add black bars — then drag the frame to move the video within them.")
                            .font(.ui(10.5))
                            .foregroundStyle(Theme.textTertiary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    UpscaleCard()
                }
                .padding(18)
            }

            PanelDivider()
            ExportFooter()
        }
        .frame(width: 312)
        .background(Theme.panel)
    }
}

private struct CropSummaryCard: View {
    @EnvironmentObject private var model: EditorModel

    private var hasVideo: Bool {
        model.videoURL != nil && model.displaySize.width > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CROP SIZE")
                        .font(.mono(8.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textTertiary)

                    if hasVideo {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(verbatim: "\(Int(model.cropPixelSize.width))")
                                .font(.mono(18, weight: .semibold))
                            Text("×")
                                .font(.mono(13, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                            Text(verbatim: "\(Int(model.cropPixelSize.height))")
                                .font(.mono(18, weight: .semibold))
                            Text("px")
                                .font(.mono(9, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.leading, 1)
                        }
                        .foregroundStyle(Theme.textPrimary)
                    } else {
                        Text("— × —")
                            .font(.mono(18, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Spacer(minLength: 4)

                Text(model.aspect == .free ? "FREE" : model.aspect.label)
                    .font(.mono(9, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Theme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            HStack(spacing: 6) {
                Text("Source")
                    .font(.ui(10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Text(hasVideo ? model.sourceLabel : "No video loaded")
                    .font(.mono(9.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let fileSize = model.fileSizeLabel, hasVideo {
                    Text(fileSize)
                        .font(.mono(9, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(13)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct UpscaleCard: View {
    @EnvironmentObject private var model: EditorModel

    private var hasVideo: Bool {
        model.videoURL != nil && model.displaySize.width > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Upscale")

                Spacer()

                if hasVideo, model.isUpscaling {
                    Text(verbatim: "\(Int(model.upscaledPixelSize.width))×\(Int(model.upscaledPixelSize.height))")
                        .font(.mono(9, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }

            HStack(spacing: 7) {
                ForEach(UpscaleMethod.allCases) { method in
                    UpscaleMethodTile(method: method)
                }
            }

            HStack(spacing: 7) {
                ForEach(EditorModel.upscaleFactors, id: \.self) { factor in
                    UpscaleFactorTile(factor: factor)
                }
            }

            Text(
                hasVideo && model.isUpscaling
                    ? model.upscaleMethod.detail
                    : "Larger frames don't recover detail that isn't in the source, but sharpening makes soft footage read better."
            )
            .font(.ui(10))
            .foregroundStyle(Theme.textTertiary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(hasVideo ? 1 : 0.5)
        .allowsHitTesting(hasVideo)
    }
}

private struct UpscaleMethodTile: View {
    @EnvironmentObject private var model: EditorModel
    let method: UpscaleMethod

    @State private var isHovered = false

    private var isSelected: Bool { model.upscaleMethod == method }
    private var isUsable: Bool { method.isAvailable && model.videoURL != nil }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                model.upscaleMethod = method
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(method.label)
                        .font(.ui(10.5, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                        .lineLimit(1)

                    if !method.isAvailable {
                        Text("SOON")
                            .font(.mono(7, weight: .bold))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Theme.cardHover)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }

                Text(method.isAvailable ? "Core Image · fast" : "Real-ESRGAN · slow")
                    .font(.mono(8, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .frame(height: 44)
            .background(
                isSelected
                    ? Theme.accentSoft
                    : (isHovered && isUsable ? Theme.cardHover : Theme.canvas.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? Theme.accent.opacity(0.8) : Theme.border,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovered = $0 }
        .disabled(!isUsable)
        .opacity(method.isAvailable ? 1 : 0.5)
        .help(method.detail)
    }
}

private struct UpscaleFactorTile: View {
    @EnvironmentObject private var model: EditorModel
    let factor: Int

    @State private var isHovered = false

    private var isSelected: Bool { model.effectiveUpscaleFactor == factor }
    private var isAllowed: Bool { model.isUpscaleFactorAllowed(factor) }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                model.upscaleFactor = factor
            }
        } label: {
            Text(factor == 1 ? "Off" : "\(factor)×")
                .font(.ui(11, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    isSelected
                        ? Theme.accentSoft
                        : (isHovered && isAllowed ? Theme.cardHover : Theme.canvas.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            isSelected ? Theme.accent.opacity(0.8) : Theme.border,
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .onHover { isHovered = $0 }
        .disabled(!isAllowed)
        .opacity(isAllowed ? 1 : 0.35)
        .help(factor == 1 ? "Keep the crop size" : "Scale the crop by \(factor)×")
    }
}

private struct AspectButton: View {
    let preset: AspectPreset
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                AspectGlyph(
                    ratio: preset.ratio,
                    color: isSelected ? Theme.accent : Theme.textSecondary
                )
                .frame(width: 22, height: 22)

                Text(preset.label)
                    .font(.ui(10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isSelected
                    ? Theme.accentSoft
                    : (isHovered ? Theme.cardHover : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? Theme.accent.opacity(0.8) : Theme.border,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovered = $0 }
        .help("\(preset.name) · \(preset.label)")
    }
}

private struct AspectGlyph: View {
    let ratio: CGFloat?
    let color: Color

    var body: some View {
        if let ratio {
            let width: CGFloat = ratio >= 1 ? 21 : 21 * ratio
            let height: CGFloat = ratio >= 1 ? 21 / ratio : 21

            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(color, lineWidth: 1.5)
                .frame(width: max(6, width), height: max(6, height))
        } else {
            Image(systemName: "crop")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

private struct ExportFooter: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isExportHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Export")
                Spacer()
                Text("H.264")
                    .font(.mono(8.5, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            FormatSelector()

            HStack(spacing: 6) {
                Image(systemName: "rectangle.dashed")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(model.videoURL == nil ? "No output yet" : "\(model.outputLabel) · \(model.trimLabel)")
                    .font(.mono(9.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                if model.hasAudio {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 8.5, weight: .medium))
                        Text("Audio kept")
                            .font(.ui(9.5, weight: .medium))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }

            Button {
                model.chooseExportDestination()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "scissors")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Export crop")
                        .font(.ui(12.5, weight: .bold))
                    Spacer()
                    Text("⌘E")
                        .font(.mono(9.5, weight: .semibold))
                        .opacity(model.canExport ? 0.55 : 0.3)
                }
                .foregroundStyle(model.canExport ? Color(hex: 0x111408) : Theme.textTertiary)
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(model.canExport ? Theme.accent : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(
                    color: model.canExport ? Theme.accent.opacity(isExportHovered ? 0.3 : 0.13) : .clear,
                    radius: 14,
                    y: 6
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!model.canExport)
            .keyboardShortcut("e", modifiers: .command)
            .onHover { isExportHovered = $0 }
            .help("Export the cropped video (⌘E)")
        }
        .padding(18)
    }
}

private struct FormatSelector: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 2) {
            ForEach(OutputFormat.allCases) { format in
                let selected = model.outputFormat == format
                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        model.outputFormat = format
                    }
                } label: {
                    Text(format.label)
                        .font(.ui(10.5, weight: .semibold))
                        .foregroundStyle(selected ? Theme.textPrimary : Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 27)
                        .background(
                            selected
                                ? Theme.cardHover
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle(scale: 0.98))
            }
        }
        .padding(3)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

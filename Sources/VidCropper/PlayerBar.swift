import SwiftUI

struct PlayerBar: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isPlayHovered = false
    @State private var isMuteHovered = false

    private var maximumTime: Double {
        max(model.duration, 0.01)
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelDivider()

            TrimStrip()

            PanelDivider()

            HStack(spacing: 14) {
                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(model.videoURL == nil ? Theme.textTertiary : Theme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(isPlayHovered ? Theme.cardHover : Theme.card)
                        .overlay(
                            Circle()
                                .stroke(Theme.borderStrong, lineWidth: 1)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.videoURL == nil)
                .onHover { isPlayHovered = $0 }
                .keyboardShortcut(.space, modifiers: [])
                .help("Play / pause (Space)")

                Text(TimeFormat.string(model.currentTime))
                    .font(.mono(10.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { min(max(model.currentTime, 0), maximumTime) },
                        set: { model.seek(to: $0) }
                    ),
                    in: 0...maximumTime,
                    onEditingChanged: { editing in
                        if editing {
                            model.beginScrubbing()
                        } else {
                            model.endScrubbing()
                        }
                    }
                )
                .tint(Theme.accent)
                .controlSize(.small)
                .disabled(model.videoURL == nil)

                Text(TimeFormat.string(model.duration))
                    .font(.mono(10.5, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 44, alignment: .leading)

                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)

                Button {
                    model.toggleMute()
                } label: {
                    Image(systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(
                            model.hasAudio
                                ? (isMuteHovered ? Theme.textPrimary : Theme.textSecondary)
                                : Theme.textTertiary
                        )
                        .frame(width: 30, height: 30)
                        .background(isMuteHovered && model.hasAudio ? Theme.cardHover : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!model.hasAudio)
                .onHover { isMuteHovered = $0 }
                .help(model.hasAudio ? "Mute / unmute" : "No audio track")

                CropPill()
            }
            .padding(.horizontal, 18)
            .frame(height: 64)
            .background(Theme.panel)
        }
    }
}

private struct TrimStrip: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                SectionLabel(title: "Trim")

                Spacer(minLength: 8)

                Text(verbatim: "\(TimeFormat.string(model.trimStart)) → \(TimeFormat.string(model.trimEnd))")
                    .font(.mono(9.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                Text("·")
                    .font(.ui(9))
                    .foregroundStyle(Theme.textTertiary)

                Text(model.trimLabel)
                    .font(.mono(9.5, weight: .bold))
                    .foregroundStyle(model.hasTrim ? Theme.accent : Theme.textSecondary)

                Button {
                    model.resetTrim()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8.5, weight: .semibold))
                        Text("Reset")
                            .font(.ui(10, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(model.videoURL == nil || !model.hasTrim)
                .opacity(model.hasTrim ? 1 : 0.45)
                .help("Use the whole clip")
            }

            TrimRangeBar()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }
}

/// Dual-handle range bar that sets the in/out points of the clip.
private struct TrimRangeBar: View {
    @EnvironmentObject private var model: EditorModel
    @State private var dragging: DragTarget?
    @State private var originValue: Double = 0

    private enum DragTarget { case start, end }

    private let trackHeight: CGFloat = 6
    private let handleWidth: CGFloat = 10
    private let handleHeight: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let height = max(geo.size.height, 1)
            let duration = max(model.duration, 0.001)
            let inset = handleWidth / 2
            let trackWidth = max(1, width - inset * 2)

            let position = { (seconds: Double) -> CGFloat in
                let clamped = min(max(seconds / duration, 0), 1)
                return inset + CGFloat(clamped) * trackWidth
            }

            let startX = position(model.trimStart)
            let endX = position(model.trimEnd)
            let playX = position(model.currentTime)

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(seekGesture(inset: inset, trackWidth: trackWidth, duration: duration))

                Capsule()
                    .fill(Theme.card)
                    .frame(width: trackWidth, height: trackHeight)
                    .position(x: width / 2, y: height / 2)
                    .allowsHitTesting(false)

                Capsule()
                    .fill(Theme.accentSoft)
                    .frame(width: max(0, endX - startX), height: trackHeight)
                    .position(x: (startX + endX) / 2, y: height / 2)
                    .allowsHitTesting(false)

                Rectangle()
                    .fill(Theme.textPrimary.opacity(0.85))
                    .frame(width: 1.5, height: handleHeight)
                    .position(x: playX, y: height / 2)
                    .allowsHitTesting(false)

                handle
                    .position(x: startX, y: height / 2)
                    .gesture(dragGesture(.start, trackWidth: trackWidth, duration: duration))

                handle
                    .position(x: endX, y: height / 2)
                    .gesture(dragGesture(.end, trackWidth: trackWidth, duration: duration))
            }
        }
        .frame(height: handleHeight + 4)
        .opacity(model.videoURL == nil ? 0.45 : 1)
        .allowsHitTesting(model.videoURL != nil)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.accent)
            .frame(width: handleWidth, height: handleHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.black.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
            .contentShape(Rectangle())
    }

    private func seekGesture(inset: CGFloat, trackWidth: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard dragging == nil else { return }
                if !model.isScrubbing { model.beginScrubbing() }
                let seconds = Double((value.location.x - inset) / trackWidth) * duration
                model.seek(to: min(max(seconds, 0), duration))
            }
            .onEnded { _ in
                if dragging == nil { model.endScrubbing() }
            }
    }

    private func dragGesture(_ target: DragTarget, trackWidth: CGFloat, duration: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging != target {
                    dragging = target
                    originValue = target == .start ? model.trimStart : model.trimEnd
                    model.beginScrubbing()
                }
                let delta = Double(value.translation.width / trackWidth) * duration
                switch target {
                case .start: model.setTrimStart(originValue + delta)
                case .end: model.setTrimEnd(originValue + delta)
                }
            }
            .onEnded { _ in
                dragging = nil
                model.endScrubbing()
            }
    }
}

private struct CropPill: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: model.aspect == .free ? "crop" : "rectangle.dashed")
                .font(.system(size: 9, weight: .semibold))
            Text(model.aspect == .free ? "FREE" : model.aspect.label)
                .font(.mono(9, weight: .bold))
            Text("·")
                .foregroundStyle(Theme.textTertiary)
            Text(verbatim: "\(Int(model.cropPixelSize.width))×\(Int(model.cropPixelSize.height))")
                .font(.mono(9, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Theme.accentSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .opacity(model.videoURL == nil ? 0.4 : 1)
    }
}

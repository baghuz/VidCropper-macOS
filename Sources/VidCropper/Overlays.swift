import SwiftUI

struct ExportOverlay: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Theme.accentSoft)
                        Image(systemName: "scissors")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isCancellingExport ? "Cancelling export…" : "Exporting crop")
                            .font(.ui(14, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(model.aspect == .free ? "Freeform" : model.aspect.label) · \(model.outputLabel) · \(model.outputFormat.label)")
                            .font(.mono(9.5, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Spacer()
                }

                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.cardHover)
                            Capsule()
                                .fill(Theme.accent)
                                .frame(
                                    width: max(4, geometry.size.width * model.exportProgress)
                                )
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text("Keep VidCropper open while the video is rendered.")
                            .font(.ui(10))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("\(Int((model.exportProgress * 100).rounded()))%")
                            .font(.mono(10, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        model.cancelExport()
                    } label: {
                        Text(model.isCancellingExport ? "Cancelling…" : "Cancel")
                            .font(.ui(11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Theme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(model.isCancellingExport)
                }
            }
            .padding(20)
            .frame(width: 410)
            .background(Theme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 40, y: 18)
        }
    }
}

struct ToastView: View {
    @EnvironmentObject private var model: EditorModel
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(Theme.accentSoft)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.ui(11.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.mono(9.5, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 12)

            if let url = toast.fileURL {
                Button {
                    model.revealInFinder(url)
                } label: {
                    Text("Show in Finder")
                        .font(.ui(10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }

            Button {
                model.dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 466)
        .background(Theme.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.borderStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 26, y: 10)
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = EditorModel()
    @State private var isDropTarget = false

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar()
                PanelDivider()
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        VideoCanvas()
                        PlayerBar()
                    }
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: 1)
                    Sidebar()
                }
            }

            if model.isExporting {
                ExportOverlay()
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.top, 68)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(30)
            }

            if isDropTarget {
                DropTargetOverlay()
                    .transition(.opacity)
                    .zIndex(40)
            }
        }
        .environmentObject(model)
        .background(WindowChromeConfigurator())
        .onAppear {
            if let path = ProcessInfo.processInfo.environment["VIDCROPPER_OPEN"] {
                model.openVideo(URL(fileURLWithPath: path))
            }
            if ProcessInfo.processInfo.environment["VIDCROPPER_PREVIEW"] != nil {
                model.isPreviewingCrop = true
            }
            if let spec = ProcessInfo.processInfo.environment["VIDCROPPER_TRIM"] {
                Task { @MainActor in
                    for _ in 0..<200 where model.duration <= 0 {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    let parts = spec.split(separator: ",").compactMap { Double($0) }
                    guard parts.count == 2 else { return }
                    model.setTrimStart(parts[0])
                    model.setTrimEnd(parts[1])
                }
            }
            if let factor = ProcessInfo.processInfo.environment["VIDCROPPER_UPSCALE"],
               let value = Int(factor) {
                model.upscaleFactor = value
            }
            if let spec = ProcessInfo.processInfo.environment["VIDCROPPER_CROP"] {
                Task { @MainActor in
                    for _ in 0..<200 where model.displaySize.width <= 0 {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    let parts = spec.split(separator: ",").compactMap { Double($0) }
                    guard parts.count == 4 else { return }
                    model.crop = CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
                }
            }
            if let outPath = ProcessInfo.processInfo.environment["VIDCROPPER_EXPORT"] {
                Task { @MainActor in
                    for _ in 0..<200 where model.isLoading || model.displaySize.width <= 0 {
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                    // Give the crop hook a beat to apply before exporting.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    model.startExport(to: URL(fileURLWithPath: outPath))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    guard model.isExporting else { exit(2) }
                    for _ in 0..<1200 where model.isExporting {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    exit(model.errorMessage == nil ? 0 : 1)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.88), value: model.isExporting)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: model.toast?.id)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { object, _ in
                guard let url = object else { return }
                Task { @MainActor in
                    model.openVideo(url)
                }
            }
            return true
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct TopBar: View {
    @EnvironmentObject private var model: EditorModel
    @State private var isOpenHovered = false

    var body: some View {
        ZStack {
            Theme.panel
            WindowDragArea()

            HStack(spacing: 12) {
                AppMark()

                Text("VidCropper")
                    .font(.ui(14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                if model.videoURL != nil {
                    Rectangle()
                        .fill(Theme.borderStrong)
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 2)

                    HStack(spacing: 7) {
                        Image(systemName: "film")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                        Text(model.fileName)
                            .font(.ui(12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 270, alignment: .leading)
                    }

                    Text(model.sourceLabel)
                        .font(.mono(10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Spacer(minLength: 16)

                Button {
                    model.chooseVideo()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .semibold))
                        Text(model.videoURL == nil ? "Open video" : "Change video")
                            .font(.ui(12, weight: .semibold))
                    }
                    .foregroundStyle(isOpenHovered ? Theme.textPrimary : Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(isOpenHovered ? Theme.cardHover : Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .keyboardShortcut("o", modifiers: .command)
                .onHover { isOpenHovered = $0 }
                .help("Open a video (⌘O)")
            }
            .padding(.leading, 84)
            .padding(.trailing, 18)
            .frame(height: 56)
        }
        .frame(height: 56)
    }
}

struct AppMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.accent)
            Image(systemName: "crop")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: 0x111408))
        }
        .frame(width: 26, height: 26)
        .shadow(color: Theme.accent.opacity(0.18), radius: 8, y: 2)
    }
}

struct DropTargetOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("Drop video to open")
                    .font(.ui(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("MP4, MOV, M4V and other video files")
                    .font(.ui(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(Theme.panel.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 30, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Theme.accent,
                    style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                )
                .padding(12)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
}

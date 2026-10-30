import AppKit
import AVFoundation
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorModel: ObservableObject {
    @Published private(set) var videoURL: URL?
    @Published private(set) var displaySize: CGSize = .zero
    @Published private(set) var duration: Double = 0
    @Published private(set) var hasAudio = false
    @Published private(set) var frameRate: Double = 0
    @Published private(set) var fileSizeLabel: String?
    @Published private(set) var isLoading = false
    @Published private(set) var posterImage: NSImage?

    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var isScrubbing = false
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 0
    @Published var crop: CGRect = CropMath.unitRect
    @Published var aspect: AspectPreset = .portrait9x16
    @Published var outputFormat: OutputFormat = .mp4
    @Published var upscaleFactor: Int = 1
    @Published var upscaleMethod: UpscaleMethod = .localSharpen
    @Published var isPreviewingCrop = false

    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var isCancellingExport = false
    @Published var errorMessage: String?
    @Published var toast: ToastMessage?

    let player = AVPlayer()

    /// Smallest trim range the user can select, in seconds.
    private let minTrimDuration: Double = 0.2

    /// Shared Core Image context for the upscaling compositor.
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    private var asset: AVURLAsset?
    private var loadID = UUID()
    private var periodicTimeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var wasPlayingBeforeScrub = false
    private var exportSession: AVAssetExportSession?
    private var exportMonitor: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var cancelRequested = false

    init() {
        player.actionAtItemEnd = .pause
        player.isMuted = false
        installObservers()
    }

    deinit {
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    // MARK: - Loaded video

    var fileName: String {
        videoURL?.lastPathComponent ?? "No video selected"
    }

    var cropPixelSize: CGSize {
        CropMath.pixelSize(for: crop, displaySize: displaySize)
    }

    var sourceLabel: String {
        guard displaySize.width > 0 else { return "—" }
        return "\(Int(displaySize.width)) × \(Int(displaySize.height))"
    }

    var frameRateLabel: String {
        guard frameRate > 0 else { return "—" }
        return String(format: "%.0f fps", frameRate)
    }

    var canExport: Bool {
        videoURL != nil && !isLoading && !isExporting && displaySize.width > 0 && trimDuration > 0.05
    }

    var outputLabel: String {
        let size = isUpscaling ? upscaledPixelSize : cropPixelSize
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    /// Highest factor the user can pick without the encoder choking on the frame size.
    static let upscaleFactors = [1, 2, 3, 4]

    /// The requested factor, downgraded when it would exceed what the encoder accepts.
    var effectiveUpscaleFactor: Int {
        var factor = max(1, min(upscaleFactor, Self.upscaleFactors.last ?? 4))
        while factor > 1, !isUpscaleFactorAllowed(factor) {
            factor -= 1
        }
        return factor
    }

    var isUpscaling: Bool {
        effectiveUpscaleFactor > 1
    }

    var upscaledPixelSize: CGSize {
        let factor = CGFloat(effectiveUpscaleFactor)
        return CGSize(
            width: (cropPixelSize.width * factor).rounded(),
            height: (cropPixelSize.height * factor).rounded()
        )
    }

    func isUpscaleFactorAllowed(_ factor: Int) -> Bool {
        let size = CGSize(
            width: cropPixelSize.width * CGFloat(factor),
            height: cropPixelSize.height * CGFloat(factor)
        )
        guard size.width > 0, size.height > 0 else { return true }
        return max(size.width, size.height) <= CropMath.maxRenderEdge
            && size.width * size.height <= CropMath.maxRenderPixels
    }

    /// True when the crop box reaches past the video, which adds black bars.
    var hasPadding: Bool {
        crop.minY < -0.002 || crop.maxY > 1.002
    }

    /// Tallest crop the encoder can handle for the loaded source.
    var maxCanvasHeight: CGFloat {
        CropMath.maxCropHeight(displaySize: displaySize)
    }

    /// Length of the selected trim range, in seconds.
    var trimDuration: Double {
        max(0, trimEnd - trimStart)
    }

    /// True when the trim range no longer covers the whole clip.
    var hasTrim: Bool {
        duration > 0 && (trimStart > 0.05 || trimEnd < duration - 0.05)
    }

    var trimLabel: String {
        TimeFormat.string(trimDuration)
    }

    // MARK: - Opening

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.title = "Choose a video"
        panel.message = "Select an MP4, MOV, M4V or another video file."
        panel.prompt = "Open"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK, let url = panel.url {
            openVideo(url)
        }
    }

    func openVideo(_ url: URL) {
        guard !isExporting else {
            showToast(ToastMessage(title: "Export in progress", detail: "Wait for the export to finish first.", fileURL: nil))
            return
        }
        Task { await loadVideo(from: url) }
    }

    private func loadVideo(from url: URL) async {
        let token = UUID()
        loadID = token
        isLoading = true
        player.pause()
        isPlaying = false

        defer {
            if loadID == token {
                isLoading = false
            }
        }

        let newAsset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        do {
            let videoTracks = try await newAsset.loadTracks(withMediaType: .video)
            guard let track = videoTracks.first else {
                throw VideoError.noVideoTrack
            }

            async let naturalSizeValue = track.load(.naturalSize)
            async let transformValue = track.load(.preferredTransform)
            async let frameRateValue = track.load(.nominalFrameRate)
            async let durationValue = newAsset.load(.duration)
            async let audioTracksValue = newAsset.loadTracks(withMediaType: .audio)

            let naturalSize = try await naturalSizeValue
            let transform = try await transformValue
            let loadedFrameRate = try await frameRateValue
            let loadedDuration = try await durationValue
            let audioTracks = try await audioTracksValue

            guard loadID == token else { return }

            let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(transform)
            let size = CGSize(
                width: max(2, abs(transformedRect.width).rounded()),
                height: max(2, abs(transformedRect.height).rounded())
            )

            let seconds = loadedDuration.seconds
            let safeDuration = seconds.isFinite && seconds > 0 ? seconds : 0

            let generator = AVAssetImageGenerator(asset: newAsset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1600, height: 1600)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            let poster = try? await generator.image(at: .zero)

            asset = newAsset
            videoURL = url
            displaySize = size
            duration = safeDuration
            frameRate = Double(loadedFrameRate)
            hasAudio = !audioTracks.isEmpty
            fileSizeLabel = FileSizeFormat.string(for: url)
            posterImage = poster.map { NSImage(cgImage: $0.image, size: .zero) }
            currentTime = 0
            exportProgress = 0

            trimStart = 0
            trimEnd = safeDuration

            aspect = .portrait9x16
            crop = CropMath.fittedRect(displaySize: size, ratio: aspect.ratio)

            let item = AVPlayerItem(asset: newAsset)
            player.isMuted = isMuted
            player.replaceCurrentItem(with: item)
            await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        } catch {
            guard loadID == token else { return }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        guard videoURL != nil, !isLoading else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if currentTime >= trimEnd - 0.05 || currentTime < trimStart {
                seek(to: trimStart)
            }
            player.play()
            isPlaying = true
        }
    }

    func beginScrubbing() {
        guard videoURL != nil else { return }
        isScrubbing = true
        wasPlayingBeforeScrub = isPlaying
        if isPlaying {
            player.pause()
            isPlaying = false
        }
    }

    func endScrubbing() {
        guard isScrubbing else { return }
        isScrubbing = false
        if wasPlayingBeforeScrub {
            player.play()
            isPlaying = true
        }
        wasPlayingBeforeScrub = false
    }

    func seek(to seconds: Double) {
        guard videoURL != nil else { return }
        let maximum = max(duration, 0)
        let target = min(max(0, seconds), maximum)
        currentTime = target
        let time = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    // MARK: - Crop

    func selectAspect(_ preset: AspectPreset) {
        guard aspect != preset else { return }
        aspect = preset
        guard let ratio = preset.ratio, displaySize.width > 0 else { return }

        let center = CGPoint(x: crop.midX, y: crop.midY)
        let target = CropMath.fittedRect(displaySize: displaySize, ratio: ratio, center: center)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            crop = target
        }
    }

    func resetCrop() {
        guard displaySize.width > 0 else { return }
        let target = CropMath.fittedRect(
            displaySize: displaySize,
            ratio: aspect.ratio,
            center: CGPoint(x: 0.5, y: 0.5)
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            crop = target
        }
    }

    /// Puts the video back in the middle of the padded canvas.
    func centerCropVertically() {
        guard displaySize.width > 0 else { return }
        var target = crop
        target.origin.y = CropMath.clampVerticalOrigin(
            0.5 - crop.height / 2,
            height: crop.height,
            maxHeight: maxCanvasHeight
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            crop = target
        }
    }

    // MARK: - Trim

    func setTrimStart(_ seconds: Double) {
        guard duration > 0 else { return }
        let upper = max(0, trimEnd - minTrimDuration)
        trimStart = min(max(0, seconds), upper)
        seek(to: trimStart)
    }

    func setTrimEnd(_ seconds: Double) {
        guard duration > 0 else { return }
        let lower = min(duration, trimStart + minTrimDuration)
        trimEnd = max(min(duration, seconds), lower)
        seek(to: trimEnd)
    }

    func resetTrim() {
        guard duration > 0 else { return }
        trimStart = 0
        trimEnd = duration
        seek(to: 0)
    }

    // MARK: - Export

    func chooseExportDestination() {
        guard canExport, let videoURL else { return }

        let panel = NSSavePanel()
        panel.title = "Export cropped video"
        panel.message = "Choose where to save the cropped video."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [outputFormat.contentType]
        panel.nameFieldStringValue = defaultExportName(for: videoURL)
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        startExport(to: url)
    }

    private func defaultExportName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let ratioSuffix = aspect.label.replacingOccurrences(of: ":", with: "x")
        let suffix = aspect == .free ? "cropped" : "crop-\(ratioSuffix)"
        return "\(base)-\(suffix).\(outputFormat.fileExtension)"
    }

    func startExport(to outputURL: URL) {
        guard let asset, let videoURL, canExport else { return }

        if outputURL.standardizedFileURL == videoURL.standardizedFileURL {
            errorMessage = "Choose a different name or folder so the original video isn't overwritten."
            return
        }

        let pixelCrop = CropMath.exportPixelRect(for: crop, displaySize: displaySize)
        let format = outputFormat
        let timeRange = exportTimeRange()
        let upscaleFactor = effectiveUpscaleFactor
        cancelRequested = false
        isCancellingExport = false
        exportProgress = 0
        isExporting = true

        Task {
            await performExport(
                asset: asset,
                pixelCrop: pixelCrop,
                format: format,
                timeRange: timeRange,
                upscaleFactor: upscaleFactor,
                outputURL: outputURL
            )
        }
    }

    /// The trim selection expressed as a media time range.
    private func exportTimeRange() -> CMTimeRange {
        let total = max(duration, 0)
        let start = min(max(0, trimStart), total)
        let end = min(max(start + 0.01, trimEnd), max(total, start + 0.01))
        return CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: max(0.01, end - start), preferredTimescale: 600)
        )
    }

    func cancelExport() {
        guard isExporting else { return }
        isCancellingExport = true
        cancelRequested = true
        exportSession?.cancelExport()
    }

    /// Offsets every layer so the crop rectangle starts at the render origin.
    private func applyCropTransform(
        to composition: AVMutableVideoComposition,
        pixelCrop: CGRect
    ) {
        for case let instruction as AVMutableVideoCompositionInstruction in composition.instructions {
            for case let layerInstruction as AVMutableVideoCompositionLayerInstruction in instruction.layerInstructions {
                var start = CGAffineTransform.identity
                var end = CGAffineTransform.identity
                _ = layerInstruction.getTransformRamp(
                    for: .zero,
                    start: &start,
                    end: &end,
                    timeRange: nil
                )
                if start == .identity {
                    start = end
                }
                let offset = CGAffineTransform(
                    translationX: -pixelCrop.minX,
                    y: -pixelCrop.minY
                )
                layerInstruction.setTransform(start.concatenating(offset), at: .zero)
            }
        }
    }

    /// Crops and then upscales every frame through Core Image, sharpening as it goes.
    private func upscalingComposition(
        asset: AVAsset,
        pixelCrop: CGRect,
        factor: Int
    ) -> AVMutableVideoComposition {
        let displaySize = self.displaySize
        let renderSize = CGSize(
            width: (pixelCrop.width * CGFloat(factor)).rounded(),
            height: (pixelCrop.height * CGFloat(factor)).rounded()
        )
        let context = ciContext

        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage
                let extent = source.extent

                guard displaySize.width > 0,
                      displaySize.height > 0,
                      extent.width > 0,
                      extent.height > 0 else {
                    request.finish(with: source, context: context)
                    return
                }

                // Work in normalized coordinates so rotated and mirrored tracks
                // land in the same place the crop overlay shows.
                let nx = pixelCrop.minX / displaySize.width
                let ny = pixelCrop.minY / displaySize.height
                let nw = pixelCrop.width / displaySize.width
                let nh = pixelCrop.height / displaySize.height

                // Core Image is bottom-left based; the crop rect is top-left based.
                // The rect can reach past the frame, which is where padding comes from.
                let paddedRect = CGRect(
                    x: extent.minX + nx * extent.width,
                    y: extent.minY + (1 - ny - nh) * extent.height,
                    width: nw * extent.width,
                    height: nh * extent.height
                ).integral

                let visibleRect = paddedRect.intersection(extent)
                let black = CIImage(color: .black).cropped(to: paddedRect)
                var image: CIImage
                if visibleRect.isNull || visibleRect.isEmpty {
                    image = black
                } else {
                    image = source.cropped(to: visibleRect).composited(over: black)
                }
                image = image.transformed(
                    by: CGAffineTransform(translationX: -paddedRect.minX, y: -paddedRect.minY)
                )

                image = image.applyingFilter(
                    "CILanczosScaleTransform",
                    parameters: [
                        kCIInputScaleKey: renderSize.width / max(paddedRect.width, 1),
                        kCIInputAspectRatioKey: 1.0
                    ]
                )

                image = image.applyingFilter(
                    "CIUnsharpMask",
                    parameters: [
                        kCIInputRadiusKey: 2.2,
                        kCIInputIntensityKey: 0.7
                    ]
                )

                let scaled = image.extent
                if scaled.minX != 0 || scaled.minY != 0 {
                    image = image.transformed(
                        by: CGAffineTransform(translationX: -scaled.minX, y: -scaled.minY)
                    )
                }

                // Edge-replicate before clipping so rounding never leaves a
                // one pixel gap along the bottom or trailing edge.
                image = image
                    .clampedToExtent()
                    .cropped(to: CGRect(origin: .zero, size: renderSize))

                request.finish(with: image, context: context)
            }
        )
        composition.renderSize = renderSize
        return composition
    }

    private func performExport(
        asset: AVURLAsset,
        pixelCrop: CGRect,
        format: OutputFormat,
        timeRange: CMTimeRange,
        upscaleFactor: Int,
        outputURL: URL
    ) async {
        defer {
            exportMonitor?.cancel()
            exportMonitor = nil
            exportSession = nil
            isExporting = false
            isCancellingExport = false
        }

        do {
            let composition: AVMutableVideoComposition
            if upscaleFactor > 1 {
                composition = upscalingComposition(
                    asset: asset,
                    pixelCrop: pixelCrop,
                    factor: upscaleFactor
                )
            } else {
                let cropComposition = AVMutableVideoComposition(propertiesOf: asset)
                guard !cropComposition.instructions.isEmpty else {
                    throw VideoError.exportFailed("The video composition couldn't be created.")
                }
                cropComposition.renderSize = CGSize(width: pixelCrop.width, height: pixelCrop.height)
                applyCropTransform(to: cropComposition, pixelCrop: pixelCrop)
                composition = cropComposition
            }

            guard let session = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw VideoError.exportFailed("This video can't be exported with the available encoder.")
            }

            guard session.supportedFileTypes.contains(format.avFileType) else {
                throw VideoError.exportFailed("The selected export format isn't supported for this video.")
            }

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            session.outputURL = outputURL
            session.outputFileType = format.avFileType
            session.videoComposition = composition
            session.timeRange = timeRange
            session.shouldOptimizeForNetworkUse = true
            exportSession = session

            if cancelRequested {
                session.cancelExport()
            }

            exportMonitor = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    if let session = self?.exportSession {
                        self?.exportProgress = min(max(Double(session.progress), 0), 0.99)
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.exportAsynchronously {
                    switch session.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: VideoError.exportCancelled)
                    case .failed:
                        let message = session.error?.localizedDescription ?? "The export failed."
                        continuation.resume(throwing: VideoError.exportFailed(message))
                    default:
                        continuation.resume(throwing: VideoError.exportFailed("The export stopped unexpectedly."))
                    }
                }
            }

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw VideoError.saveFailed
            }

            exportProgress = 1
            showToast(
                ToastMessage(
                    title: "Crop exported",
                    detail: outputURL.lastPathComponent,
                    fileURL: outputURL
                )
            )
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            if let videoError = error as? VideoError, case .exportCancelled = videoError {
                // A cancelled export isn't an error the user needs to dismiss.
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Toast

    func showToast(_ message: ToastMessage) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = message
        }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self?.toast = nil
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            toast = nil
        }
    }

    // MARK: - Observers

    private func installObservers() {
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, !self.isScrubbing else { return }
                guard time.seconds.isFinite else { return }
                let position = min(max(0, time.seconds), max(self.duration, 0))
                // Loop playback inside the trimmed range instead of running past it.
                if self.isPlaying, self.trimEnd > 0, position >= self.trimEnd - 0.02 {
                    self.seek(to: self.trimStart)
                } else {
                    self.currentTime = position
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self,
                      let item = notification.object as? AVPlayerItem,
                      item === self.player.currentItem else { return }
                self.isPlaying = false
                self.seek(to: self.trimStart)
            }
        }
    }
}

import AVFoundation
import Foundation
import UniformTypeIdentifiers

enum AspectPreset: String, CaseIterable, Identifiable {
    case free
    case portrait9x16
    case landscape16x9
    case portrait4x5
    case square1x1
    case landscape4x3
    case portrait3x4
    case landscape3x2
    case portrait2x3
    case ultrawide21x9

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: return "Free"
        case .portrait9x16: return "9:16"
        case .landscape16x9: return "16:9"
        case .portrait4x5: return "4:5"
        case .square1x1: return "1:1"
        case .landscape4x3: return "4:3"
        case .portrait3x4: return "3:4"
        case .landscape3x2: return "3:2"
        case .portrait2x3: return "2:3"
        case .ultrawide21x9: return "21:9"
        }
    }

    /// Width divided by height, in video pixels.
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .portrait9x16: return 9.0 / 16.0
        case .landscape16x9: return 16.0 / 9.0
        case .portrait4x5: return 4.0 / 5.0
        case .square1x1: return 1
        case .landscape4x3: return 4.0 / 3.0
        case .portrait3x4: return 3.0 / 4.0
        case .landscape3x2: return 3.0 / 2.0
        case .portrait2x3: return 2.0 / 3.0
        case .ultrawide21x9: return 21.0 / 9.0
        }
    }

    var name: String {
        switch self {
        case .free: return "Freeform"
        case .portrait9x16: return "Vertical"
        case .landscape16x9: return "Widescreen"
        case .portrait4x5: return "Portrait"
        case .square1x1: return "Square"
        case .landscape4x3: return "Classic"
        case .portrait3x4: return "Tall portrait"
        case .landscape3x2: return "Photo wide"
        case .portrait2x3: return "Photo tall"
        case .ultrawide21x9: return "Cinematic"
        }
    }
}

enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4
    case mov

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }

    var fileExtension: String { rawValue }

    var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        }
    }

    var contentType: UTType {
        switch self {
        case .mp4: return .mpeg4Movie
        case .mov: return .quickTimeMovie
        }
    }
}

enum UpscaleMethod: String, CaseIterable, Identifiable {
    case localSharpen
    case aiEnhanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .localSharpen: return "Local sharpen"
        case .aiEnhanced: return "AI enhance"
        }
    }

    var detail: String {
        switch self {
        case .localSharpen:
            return "Lanczos upscale plus an unsharp mask pass, rendered on the GPU."
        case .aiEnhanced:
            return "Real-ESRGAN super-resolution. Rebuilds fine detail, but takes much longer."
        }
    }

    /// Whether the method is wired up and usable right now.
    var isAvailable: Bool {
        switch self {
        case .localSharpen: return true
        case .aiEnhanced: return false
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String?
    let fileURL: URL?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum VideoError: LocalizedError {
    case noVideoTrack
    case unreadable
    case exportFailed(String)
    case exportCancelled
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "This file doesn't contain a video track."
        case .unreadable:
            return "The video couldn't be read. It may be damaged or use an unsupported codec."
        case .exportFailed(let message):
            return message
        case .exportCancelled:
            return "Export was cancelled."
        case .saveFailed:
            return "The cropped video couldn't be saved."
        }
    }
}

enum TimeFormat {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

enum FileSizeFormat {
    static func string(for url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let bytes = values.fileSize else { return nil }
        let count = Double(bytes)
        if count >= 1_073_741_824 {
            return String(format: "%.1f GB", count / 1_073_741_824)
        }
        if count >= 1_048_576 {
            return String(format: "%.1f MB", count / 1_048_576)
        }
        return "\(max(1, bytes / 1024)) KB"
    }
}

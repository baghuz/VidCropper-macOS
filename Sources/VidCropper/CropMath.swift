import CoreGraphics
import Foundation

enum CropHandle: Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case move
}

enum CropMath {
    static let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// H.264 level 5.1 ceilings: 4096 on the long edge and ~9.4 MP per frame.
    static let maxRenderEdge: CGFloat = 4096
    static let maxRenderPixels: CGFloat = 4096 * 2304

    /// The crop can grow past the video to add padding, but the video must stay
    /// at least this fraction visible so the frame never ends up empty.
    static let minVisibleFraction: CGFloat = 0.05

    /// Hard ceiling for the padded canvas, expressed as a multiple of the source height.
    static let maxCanvasHeightFactor: CGFloat = 3.5

    /// Tallest crop (in normalized units) the encoder can still handle for this source.
    static func maxCropHeight(displaySize: CGSize) -> CGFloat {
        guard displaySize.width > 0, displaySize.height > 0 else {
            return maxCanvasHeightFactor
        }
        let byEdge = maxRenderEdge / displaySize.height
        let byPixels = (maxRenderPixels / displaySize.width) / displaySize.height
        return max(1, min(maxCanvasHeightFactor, min(byEdge, byPixels)))
    }

    /// Largest crop with the given pixel aspect ratio, centered as close as possible to `center`.
    /// The returned rect uses normalized 0...1 video coordinates with a top-left origin.
    static func fittedRect(
        displaySize: CGSize,
        ratio: CGFloat?,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) -> CGRect {
        guard let ratio, ratio > 0, displaySize.width > 0, displaySize.height > 0 else {
            return unitRect
        }

        var pixelWidth = displaySize.width
        var pixelHeight = pixelWidth / ratio
        if pixelHeight > displaySize.height {
            pixelHeight = displaySize.height
            pixelWidth = pixelHeight * ratio
        }

        let normalizedWidth = min(1, pixelWidth / displaySize.width)
        let normalizedHeight = min(1, pixelHeight / displaySize.height)
        let x = clamp(center.x - normalizedWidth / 2, lower: 0, upper: 1 - normalizedWidth)
        let y = clamp(center.y - normalizedHeight / 2, lower: 0, upper: 1 - normalizedHeight)

        return CGRect(x: x, y: y, width: normalizedWidth, height: normalizedHeight)
    }

    /// Keeps the crop from drifting so far that the video disappears.
    static func clampVerticalOrigin(_ originY: CGFloat, height: CGFloat, maxHeight: CGFloat) -> CGFloat {
        let lower = minVisibleFraction - height
        let upper = 1 - minVisibleFraction
        return clamp(originY, lower: lower, upper: upper)
    }

    static func movedRect(
        start: CGRect,
        translation: CGSize,
        containerSize: CGSize,
        maxCanvasHeight: CGFloat = 1
    ) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else { return start }
        var rect = start
        rect.origin.x = clamp(
            start.origin.x + translation.width / containerSize.width,
            lower: 0,
            upper: 1 - start.width
        )
        rect.origin.y = clampVerticalOrigin(
            start.origin.y + translation.height / containerSize.height,
            height: start.height,
            maxHeight: maxCanvasHeight
        )
        return rect
    }

    static func resizedRect(
        start: CGRect,
        handle: CropHandle,
        currentPoint: CGPoint,
        containerSize: CGSize,
        ratio: CGFloat?,
        displaySize: CGSize,
        maxCanvasHeight: CGFloat = 1
    ) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0,
              currentPoint.x.isFinite, currentPoint.y.isFinite else { return start }

        // Vertical is intentionally unclamped to 0...1 so the box can be dragged
        // past the video edge; the extra area becomes black padding on export.
        let currentNormalized = CGPoint(
            x: clamp(currentPoint.x / containerSize.width, lower: 0, upper: 1),
            y: clamp(
                currentPoint.y / containerSize.height,
                lower: -maxCanvasHeight,
                upper: 1 + maxCanvasHeight
            )
        )

        let isLeft = handle == .topLeft || handle == .bottomLeft
        let isTop = handle == .topLeft || handle == .topRight
        let anchor = CGPoint(
            x: isLeft ? start.maxX : start.minX,
            y: isTop ? start.maxY : start.minY
        )

        let maxWidth = isLeft ? anchor.x : 1 - anchor.x
        let maxHeight = max(maxCanvasHeight, 0.05)
        let desiredWidth = abs(currentNormalized.x - anchor.x)
        let desiredHeight = abs(currentNormalized.y - anchor.y)

        let minWidthPixels: CGFloat = 44
        let minHeightPixels: CGFloat = 44
        let minWidth = min(maxWidth, minWidthPixels / containerSize.width)
        let minHeight = min(maxHeight, minHeightPixels / containerSize.height)

        var width: CGFloat
        var height: CGFloat

        if let ratio, ratio > 0, displaySize.width > 0, displaySize.height > 0 {
            // Convert the pixel aspect ratio into normalized coordinate space.
            let normalizedRatio = ratio * displaySize.height / displaySize.width
            let widthFromX = desiredWidth
            let widthFromY = desiredHeight * normalizedRatio
            width = (widthFromX + widthFromY) / 2

            let maxWidthForHeight = maxHeight * normalizedRatio
            let allowedMaxWidth = max(0, min(maxWidth, maxWidthForHeight))
            let allowedMinWidth = min(allowedMaxWidth, max(minWidth, minHeight * normalizedRatio))
            width = clamp(width, lower: allowedMinWidth, upper: allowedMaxWidth)
            height = normalizedRatio > 0 ? width / normalizedRatio : heightFallback(maxHeight)
            height = min(height, maxHeight)
        } else {
            width = clamp(desiredWidth, lower: minWidth, upper: maxWidth)
            height = clamp(desiredHeight, lower: minHeight, upper: maxHeight)
        }

        guard width > 0, height > 0 else { return start }

        var rect = CGRect(
            x: isLeft ? anchor.x - width : anchor.x,
            y: isTop ? anchor.y - height : anchor.y,
            width: width,
            height: height
        )
        rect.origin.x = clamp(rect.origin.x, lower: 0, upper: 1 - rect.width)
        rect.origin.y = clampVerticalOrigin(rect.origin.y, height: rect.height, maxHeight: maxCanvasHeight)
        return rect
    }

    static func hitTest(
        point: CGPoint,
        pixelRect rect: CGRect,
        threshold: CGFloat = 24
    ) -> CropHandle? {
        let corners: [(CropHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.maxY))
        ]

        for (handle, corner) in corners {
            if hypot(point.x - corner.x, point.y - corner.y) <= threshold {
                return handle
            }
        }

        if rect.contains(point) {
            return .move
        }
        return nil
    }

    static func pixelSize(for crop: CGRect, displaySize: CGSize) -> CGSize {
        CGSize(
            width: max(1, (crop.width * displaySize.width).rounded()),
            height: max(1, (crop.height * displaySize.height).rounded())
        )
    }

    /// Pixel crop used for export. Coordinates are rounded and dimensions are forced to even
    /// numbers. The origin can be negative, which is how padding turns into black bars.
    static func exportPixelRect(for crop: CGRect, displaySize: CGSize) -> CGRect {
        let sourceWidth = max(2, Int(displaySize.width.rounded()))
        let sourceHeight = max(2, Int(displaySize.height.rounded()))

        var x = Int((crop.minX * CGFloat(sourceWidth)).rounded())
        var y = Int((crop.minY * CGFloat(sourceHeight)).rounded())
        var width = Int((crop.width * CGFloat(sourceWidth)).rounded())
        var height = Int((crop.height * CGFloat(sourceHeight)).rounded())

        width -= width % 2
        height -= height % 2
        if sourceWidth % 2 == 0 {
            x -= x % 2
        }
        if sourceHeight % 2 == 0 {
            y -= y % 2
        }

        width = max(2, min(width, sourceWidth))
        let maxHeight = max(
            2,
            Int((maxCropHeight(displaySize: displaySize) * CGFloat(sourceHeight)).rounded())
        )
        height = max(2, min(height, maxHeight))
        if height % 2 != 0 {
            height -= 1
        }

        x = min(max(0, x), sourceWidth - width)

        let minVisible = max(1, Int((minVisibleFraction * CGFloat(sourceHeight)).rounded()))
        y = min(max(y, minVisible - height), sourceHeight - minVisible)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard upper >= lower else { return lower }
        return min(max(value, lower), upper)
    }

    private static func heightFallback(_ value: CGFloat) -> CGFloat {
        value > 0 ? value : 1
    }
}

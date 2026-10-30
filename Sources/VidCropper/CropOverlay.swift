import AppKit
import SwiftUI

struct CropOverlay: View {
    @Binding var crop: CGRect
    let displaySize: CGSize
    let aspectRatio: CGFloat?
    /// Where the video itself sits inside this view, in local points. The view
    /// covers the whole padded stage, so the crop box may sit partly outside it.
    let videoRect: CGRect

    @State private var activeHandle: CropHandle?
    @State private var startCrop: CGRect = CropMath.unitRect
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = pixelRect
            let dimensions = CropMath.pixelSize(for: crop, displaySize: displaySize)

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    draw(in: &context, size: canvasSize, cropRect: rect)
                }

                Text(verbatim: "\(Int(dimensions.width)) × \(Int(dimensions.height))")
                    .font(.mono(10, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                    .position(
                        x: badgeCenterX(for: rect, in: size),
                        y: badgeCenterY(for: rect)
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(in: size))
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    updateCursor(at: point, in: size)
                case .ended:
                    NSCursor.arrow.set()
                }
            }
        }
    }

    private var maxCanvasHeight: CGFloat {
        CropMath.maxCropHeight(displaySize: displaySize)
    }

    private var pixelRect: CGRect {
        CGRect(
            x: videoRect.minX + crop.minX * videoRect.width,
            y: videoRect.minY + crop.minY * videoRect.height,
            width: crop.width * videoRect.width,
            height: crop.height * videoRect.height
        )
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    startCrop = crop
                    activeHandle = CropMath.hitTest(
                        point: value.startLocation,
                        pixelRect: pixelRect
                    )
                }

                guard let handle = activeHandle else { return }

                if handle == .move {
                    crop = CropMath.movedRect(
                        start: startCrop,
                        translation: value.translation,
                        containerSize: videoRect.size,
                        maxCanvasHeight: maxCanvasHeight
                    )
                } else {
                    crop = CropMath.resizedRect(
                        start: startCrop,
                        handle: handle,
                        currentPoint: CGPoint(
                            x: value.location.x - videoRect.minX,
                            y: value.location.y - videoRect.minY
                        ),
                        containerSize: videoRect.size,
                        ratio: aspectRatio,
                        displaySize: displaySize,
                        maxCanvasHeight: maxCanvasHeight
                    )
                }
            }
            .onEnded { _ in
                isDragging = false
                activeHandle = nil
            }
    }

    private func updateCursor(at point: CGPoint, in size: CGSize) {
        switch CropMath.hitTest(point: point, pixelRect: pixelRect) {
        case .move:
            NSCursor.openHand.set()
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            NSCursor.crosshair.set()
        case nil:
            NSCursor.arrow.set()
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, cropRect: CGRect) {
        var dimming = Path(CGRect(origin: .zero, size: size))
        dimming.addRect(cropRect)
        context.fill(
            dimming,
            with: .color(Color.black.opacity(0.62)),
            style: FillStyle(eoFill: true)
        )

        let ruleColor = Color.white.opacity(0.2)
        for index in 1...2 {
            let fraction = CGFloat(index) / 3.0
            var vertical = Path()
            vertical.move(to: CGPoint(x: cropRect.minX + cropRect.width * fraction, y: cropRect.minY))
            vertical.addLine(to: CGPoint(x: cropRect.minX + cropRect.width * fraction, y: cropRect.maxY))
            context.stroke(vertical, with: .color(ruleColor), lineWidth: 0.75)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + cropRect.height * fraction))
            horizontal.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + cropRect.height * fraction))
            context.stroke(horizontal, with: .color(ruleColor), lineWidth: 0.75)
        }

        context.stroke(
            Path(cropRect),
            with: .color(Color.black.opacity(0.45)),
            lineWidth: 4
        )
        context.stroke(
            Path(cropRect),
            with: .color(Color.white.opacity(0.92)),
            lineWidth: 1.25
        )

        let handles = [
            CGPoint(x: cropRect.minX, y: cropRect.minY),
            CGPoint(x: cropRect.maxX, y: cropRect.minY),
            CGPoint(x: cropRect.minX, y: cropRect.maxY),
            CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        ]

        for point in handles {
            let outer = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
            let inner = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: outer), with: .color(Color.black.opacity(0.4)))
            context.fill(Path(ellipseIn: inner), with: .color(Theme.accent))
        }
    }

    private func badgeCenterX(for rect: CGRect, in size: CGSize) -> CGFloat {
        let estimatedWidth: CGFloat = 96
        return min(max(rect.midX, estimatedWidth / 2 + 6), size.width - estimatedWidth / 2 - 6)
    }

    private func badgeCenterY(for rect: CGRect) -> CGFloat {
        rect.minY > 34 ? rect.minY - 17 : rect.minY + 17
    }
}

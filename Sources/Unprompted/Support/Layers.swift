import AppKit

/// A layer that draws itself with a closure, for parts of a character that change too often to
/// keep as a picture. Never animates implicitly: characters move every frame on their own.
final class PaintedLayer: CALayer {
    private var paint: ((CGContext) -> Void)?

    override init() {
        super.init()
        // 8 bits per channel is plenty for cartoons. On wide-color displays the default is 16-bit
        // float, which doubles the cost of painting.
        contentsFormat = .RGBA8Uint
    }

    // Used by Core Animation for its copies of the layer.
    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(in ctx: CGContext) {
        guard let paint else { return }
        // Text drawing (NSString.draw) needs an AppKit context.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        paint(ctx)
        NSGraphicsContext.restoreGraphicsState()
    }

    override func action(forKey event: String) -> CAAction? { nil }

    /// Covers `rect` (in the superlayer's coordinates) and paints it right away. `paint` draws in
    /// those same coordinates.
    func repaint(_ rect: CGRect, _ paint: @escaping (CGContext) -> Void) {
        bounds = CGRect(origin: .zero, size: rect.size)
        position = CGPoint(x: rect.midX, y: rect.midY)
        self.paint = { ctx in
            ctx.translateBy(x: -rect.minX, y: -rect.minY)
            paint(ctx)
        }
        setNeedsDisplay()
        displayIfNeeded()
    }
}

extension CALayer {
    /// Makes the layer show a picture of `rect` (in its superlayer's coordinates, y up) and puts it
    /// there. `scale` is pixels per point; more than the screen's keeps the picture crisp when the
    /// layer is scaled up or turned.
    func showPicture(of rect: CGRect, scale: CGFloat, drawing: (CGContext) -> Void) {
        let pixels = CGSize(width: max(1, (rect.width * scale).rounded(.up)), height: max(1, (rect.height * scale).rounded(.up)))
        let size = CGSize(width: pixels.width / scale, height: pixels.height / scale)
        // An AppKit bitmap context, so shadow blurs are measured in points like in a view.
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?.retagging(with: .sRGB)
        else { return }
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.translateBy(x: -rect.minX, y: -rect.minY)
        drawing(context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        contents = rep.cgImage
        contentsScale = scale
        bounds = CGRect(origin: .zero, size: size)
        position = CGPoint(x: rect.minX + size.width * anchorPoint.x, y: rect.minY + size.height * anchorPoint.y)
    }
}

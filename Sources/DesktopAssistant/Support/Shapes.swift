import CoreGraphics

enum Shapes {
    /// A four-pointed sparkle (✨) centered on the origin. Higher `pinch` = chubbier.
    static func sparkle(radius r: CGFloat, pinch: CGFloat) -> CGPath {
        let k = r * pinch
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: k, y: k))
        p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: k, y: -k))
        p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -k, y: -k))
        p.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: -k, y: k))
        p.closeSubpath()
        return p
    }
}

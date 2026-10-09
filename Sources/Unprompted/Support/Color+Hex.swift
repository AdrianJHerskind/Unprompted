import CoreGraphics

extension CGColor {
    /// An sRGB color from a 0xRRGGBB literal.
    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(value >> 16 & 0xff) / 255,
                green: CGFloat(value >> 8 & 0xff) / 255,
                blue: CGFloat(value & 0xff) / 255,
                alpha: alpha)
    }
}

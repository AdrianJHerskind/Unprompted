// Draws the app icon (Sparkle with a "…" speech bubble) and builds Resources/AppIcon.icns.
// Usage: swift tools/generate-icon.swift Resources
//
// Every size is drawn from vectors rather than scaled down, so small icons stay crisp.
// The smallest sizes drop the bubble and twinkles to stay readable.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func starPath(center c: CGPoint, radius r: CGFloat, pinch: CGFloat) -> CGPath {
    let k = r * pinch
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
    p.closeSubpath()
    return p
}

let ink = rgb(0x22143A)

func drawIcon(size px: Int) -> CGImage {
    let S = CGFloat(px)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let tiny = px <= 32

    // macOS icon grid: an 824/1024 rounded square, centered, with a soft drop shadow.
    let inset = S * 100 / 1024
    let tile = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: S * 0.18, cornerHeight: S * 0.18, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.03, color: rgb(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(rgb(0x1A1040))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()

    // Night-sky background with a violet glow behind the star.
    ctx.drawLinearGradient(gradient([rgb(0x2E1C66), rgb(0x130B30)], [0, 1]),
                           start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    let center = CGPoint(x: S * 0.5, y: tiny ? S * 0.5 : S * 0.46)
    ctx.drawRadialGradient(gradient([rgb(0x9D6BFF, 0.55), rgb(0x9D6BFF, 0)], [0, 1]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: S * 0.4, options: [])

    // Background twinkles
    if !tiny {
        for (x, y, r) in [(0.22, 0.73, 0.045), (0.80, 0.24, 0.032), (0.25, 0.25, 0.022), (0.84, 0.56, 0.018)] {
            ctx.addPath(starPath(center: CGPoint(x: S * x, y: S * y), radius: S * r, pinch: 0.16))
            ctx.setFillColor(rgb(0xFFE99A, 0.9))
            ctx.fillPath()
        }
    }

    // The sparkle body
    let R = S * (tiny ? 0.36 : 0.30)
    let body = starPath(center: center, radius: R, pinch: 0.28)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S * 0.04, color: rgb(0xFFC83D, 0.8))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0xFFB72B))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFFE45C), rgb(0xFFB72B), rgb(0xFF8650)], [0, 0.5, 1]),
                           start: CGPoint(x: center.x - R, y: center.y + R),
                           end: CGPoint(x: center.x + R, y: center.y - R), options: [])
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.4))
    ctx.fillEllipse(in: CGRect(x: center.x - R * 0.16, y: center.y + R * 0.42, width: R * 0.1, height: R * 0.36))
    ctx.restoreGState()

    ctx.addPath(body)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.6))
    ctx.setLineWidth(max(1, S * 0.005))
    ctx.strokePath()

    // Face: googly eyes glancing up at the speech bubble, blush and a smile.
    let eyeY = center.y + R * 0.1
    let eyeR = R * 0.17
    let look = CGVector(dx: 0.55, dy: 0.45)
    if !tiny {
        ctx.setFillColor(rgb(0xFF7AB8, 0.5))
        for side in [-1.0, 1.0] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: center.x + side * R * 0.4 - R * 0.07, y: eyeY - R * 0.25,
                                       width: R * 0.14, height: R * 0.08))
        }
    }
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = center.x + side * R * 0.24
        let eye = CGRect(x: x - eyeR, y: eyeY - eyeR * 1.1, width: eyeR * 2, height: eyeR * 2.2)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: eye)
        let pr = eyeR * 0.55
        let reach = (eyeR - pr) * 0.85
        let pupil = CGPoint(x: x + look.dx * reach, y: eyeY + look.dy * reach * 1.1)
        ctx.setFillColor(ink)
        ctx.fillEllipse(in: CGRect(x: pupil.x - pr, y: pupil.y - pr, width: pr * 2, height: pr * 2))
        if !tiny {
            let g = pr * 0.35
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: pupil.x - pr * 0.3 - g, y: pupil.y + pr * 0.35 - g, width: g * 2, height: g * 2))
        }
    }
    let my = center.y - R * 0.22
    let w = R * 0.13
    ctx.move(to: CGPoint(x: center.x - w, y: my))
    ctx.addQuadCurve(to: CGPoint(x: center.x + w, y: my), control: CGPoint(x: center.x, y: my - w * 1.2))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(max(1, R * 0.055))
    ctx.setLineCap(.round)
    ctx.strokePath()

    // The obligatory "I have a suggestion…" bubble.
    if !tiny {
        let bubble = CGRect(x: S * 0.60, y: S * 0.70, width: S * 0.26, height: S * 0.14)
        let p = CGMutablePath()
        p.addRoundedRect(in: bubble, cornerWidth: S * 0.05, cornerHeight: S * 0.05)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: S * 0.645, y: bubble.minY + S * 0.01))
        tail.addLine(to: CGPoint(x: S * 0.615, y: S * 0.645))
        tail.addLine(to: CGPoint(x: S * 0.705, y: bubble.minY + S * 0.01))
        tail.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.006), blur: S * 0.015, color: rgb(0x000000, 0.35))
        ctx.addPath(p)
        ctx.addPath(tail)
        ctx.setFillColor(rgb(0xFFFFE1))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.setFillColor(ink)
        for i in 0..<3 {
            let r = S * 0.017
            let c = CGPoint(x: bubble.midX + CGFloat(i - 1) * S * 0.062, y: bubble.midY)
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
    }

    ctx.restoreGState()
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    writePNG(drawIcon(size: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(drawIcon(size: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
writePNG(drawIcon(size: 1024), to: outDir.appendingPathComponent("AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(outDir.path)/AppIcon.icns and AppIcon.png")

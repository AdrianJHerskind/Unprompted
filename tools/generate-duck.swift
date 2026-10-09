// Draws the Rubber Duck pixel-art frames as PNGs.
// Usage: swift tools/generate-duck.swift Resources/Characters/rubberduck
//
// The classic debugging duck, facing right. Each frame is 28×36 pixels: the top 10 rows are
// headroom for hats, the duck itself lives in the 28×26 area below. The app scales it up 4×.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let W = 28, H = 36
let headroom = 10

struct RGBA: Equatable { var r, g, b, a: UInt8 }
func hex(_ v: UInt32) -> RGBA { RGBA(r: UInt8(v >> 16 & 0xff), g: UInt8(v >> 8 & 0xff), b: UInt8(v & 0xff), a: 255) }

let outline = hex(0x9C6B00), yellow = hex(0xFFD83D), light = hex(0xFFF1A0), shade = hex(0xF0B92A)
let wingFill = hex(0xF7C531), wingLine = hex(0xC99000)
let beak = hex(0xFF8A1F), beakDark = hex(0xE06A00), mouth = hex(0x7A2E00)
let eye = hex(0x1E1E1E), glint = hex(0xFFFFFF), zColor = hex(0x8A7CFF)

struct Canvas {
    var px = [RGBA?](repeating: nil, count: W * H)

    // (0,0) is the top-left pixel of the duck area, below the headroom.
    mutating func set(_ x: Int, _ y: Int, _ c: RGBA) {
        let y = y + headroom
        guard x >= 0, x < W, y >= 0, y < H else { return }
        px[y * W + x] = c
    }

    mutating func points(_ pts: [(Int, Int)], _ c: RGBA) { for (x, y) in pts { set(x, y, c) } }

    func write(to url: URL) {
        var bytes: [UInt8] = []
        for p in px { if let p { bytes += [p.r, p.g, p.b, p.a] } else { bytes += [0, 0, 0, 0] } }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}

/// Pixels inside an ellipse (tested at pixel centers).
func ellipse(cx: Double, cy: Double, rx: Double, ry: Double) -> Set<[Int]> {
    var s = Set<[Int]>()
    for y in Int(cy - ry - 1)...Int(cy + ry + 1) {
        for x in Int(cx - rx - 1)...Int(cx + rx + 1) {
            let dx = (Double(x) + 0.5 - cx) / rx, dy = (Double(y) + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1 { s.insert([x, y]) }
        }
    }
    return s
}

/// Fills a shape and draws its border pixels in `line`.
func fillShape(_ c: inout Canvas, _ shape: Set<[Int]>, fill: RGBA, line: RGBA, dy: Int = 0) {
    for p in shape {
        let edge = [[1, 0], [-1, 0], [0, 1], [0, -1]].contains { !shape.contains([p[0] + $0[0], p[1] + $0[1]]) }
        c.set(p[0], p[1] + dy, edge ? line : fill)
    }
}

enum Eye { case open, blink, wide, happy, sulky }
enum Beak { case closed, open }
enum Wing { case down, up, mid, droop }
enum Feet { case stand, stepA, stepB, dangle }

struct Pose {
    var eye = Eye.open
    var beak = Beak.closed
    var wing = Wing.down
    var feet = Feet.stand
    var bob = 0
    var z: Int? = nil
}

func draw(_ p: Pose) -> Canvas {
    var c = Canvas()
    let b = -p.bob

    // Feet first, so the body overlaps them.
    switch p.feet {
    case .stand:
        c.points((9...12).map { ($0, 24) } + (15...18).map { ($0, 24) }, beak)
    case .stepA:
        c.points((8...11).map { ($0, 24) } + (16...19).map { ($0, 24) }, beak)
    case .stepB:
        c.points((9...12).map { ($0, 24) } + (15...18).map { ($0, 23) }, beak)
    case .dangle:
        c.points([(10, 24), (10, 25), (11, 25), (16, 24), (16, 25), (17, 25)], beak)
    }

    // Body, head and tail as one silhouette with an outline.
    var duck = ellipse(cx: 13.5, cy: 18.5, rx: 9.5, ry: 5.5)
    duck.formUnion(ellipse(cx: 18.5, cy: 8.5, rx: 5.2, ry: 5.2))
    duck.formUnion([[3, 12], [3, 13], [4, 13], [4, 14], [5, 14], [5, 15]])
    fillShape(&c, duck, fill: yellow, line: outline, dy: b)
    // Highlights and shading.
    for p in duck where !([[1, 0], [-1, 0], [0, 1], [0, -1]].contains { !duck.contains([p[0] + $0[0], p[1] + $0[1]]) }) {
        if (p[1] <= 6 && p[0] <= 18) || (p[1] == 14 && (8...14).contains(p[0])) { c.set(p[0], p[1] + b, light) }
        if p[1] >= 22 { c.set(p[0], p[1] + b, shade) }
    }

    // Wing
    let wing: Set<[Int]>
    switch p.wing {
    case .down: wing = ellipse(cx: 11, cy: 18, rx: 4, ry: 2.5)
    case .mid: wing = ellipse(cx: 10, cy: 15.5, rx: 3.8, ry: 2.4)
    case .up: wing = ellipse(cx: 9, cy: 12.5, rx: 3.5, ry: 2.6)
    case .droop: wing = ellipse(cx: 11, cy: 19.5, rx: 4, ry: 2.2)
    }
    fillShape(&c, wing, fill: wingFill, line: wingLine, dy: b)

    // Beak
    switch p.beak {
    case .closed:
        c.points([(23, 9), (24, 9), (25, 9), (23, 10), (24, 10), (25, 10), (26, 10)].map { ($0.0, $0.1 + b) }, beak)
        c.points([(23, 11), (24, 11), (25, 11)].map { ($0.0, $0.1 + b) }, beakDark)
    case .open:
        c.points([(23, 8), (24, 8), (25, 8), (23, 9), (24, 9), (25, 9), (26, 9)].map { ($0.0, $0.1 + b) }, beak)
        c.points([(23, 10), (24, 10), (25, 10)].map { ($0.0, $0.1 + b) }, mouth)
        c.points([(23, 11), (24, 11), (25, 11), (23, 12), (24, 12)].map { ($0.0, $0.1 + b) }, beakDark)
    }

    // Eye
    func e(_ pts: [(Int, Int)], _ color: RGBA) { c.points(pts.map { ($0.0, $0.1 + b) }, color) }
    switch p.eye {
    case .open: e([(19, 6), (20, 6), (19, 7), (20, 7)], eye); e([(20, 6)], glint)
    case .blink: e([(19, 7), (20, 7)], eye)
    case .wide: e([(18, 5), (19, 5), (20, 5), (18, 6), (19, 6), (20, 6), (18, 7), (19, 7), (20, 7)], eye); e([(19, 5)], glint)
    case .happy: e([(18, 7), (19, 6), (20, 6), (21, 7)], eye)
    case .sulky: e([(18, 6), (19, 6), (20, 6), (21, 6)], outline); e([(19, 7), (20, 7)], eye)
    }

    if let z = p.z {
        // A 4×4 "Z" (a 3×3 one can't show the diagonal and reads as an "I").
        let (zx, zy) = z == 0 ? (21, -1) : (23, -4)
        c.points([(zx, zy), (zx + 1, zy), (zx + 2, zy), (zx + 3, zy), (zx + 2, zy + 1), (zx + 1, zy + 2),
                  (zx, zy + 3), (zx + 1, zy + 3), (zx + 2, zy + 3), (zx + 3, zy + 3)], zColor)
    }
    return c
}

let frames: [String: Pose] = [
    "idle_0": Pose(),
    "idle_1": Pose(eye: .blink),
    "walk_0": Pose(feet: .stepA),
    "walk_1": Pose(feet: .stand, bob: 1),
    "walk_2": Pose(feet: .stepB),
    "walk_3": Pose(feet: .stand, bob: 1),
    "fall_0": Pose(eye: .wide, beak: .open, wing: .up, feet: .dangle),
    "drag_0": Pose(eye: .wide, beak: .open, wing: .up, feet: .dangle),
    "drag_1": Pose(eye: .wide, beak: .open, wing: .mid, feet: .dangle),
    "talk_0": Pose(beak: .open),
    "talk_1": Pose(beak: .closed),
    "sulk_0": Pose(eye: .sulky, wing: .droop),
    "sleep_0": Pose(eye: .blink, z: 0),
    "sleep_1": Pose(eye: .blink, z: 1),
    "happy_0": Pose(eye: .happy, beak: .open, wing: .up, bob: 1),
    "happy_1": Pose(eye: .happy, beak: .open, wing: .mid),
]

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for (name, pose) in frames.sorted(by: { $0.key < $1.key }) {
    draw(pose).write(to: outDir.appendingPathComponent("\(name).png"))
}
print("Wrote \(frames.count) frames to \(outDir.path)")

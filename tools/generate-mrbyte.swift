// Draws the "Mr. Byte" pixel-art frames as PNGs.
// Usage: swift tools/generate-mrbyte.swift Resources/Characters/mrbyte
//
// Mr. Byte is a 1990s beige computer with a face on its screen and little legs.
// Each frame is 28×40 pixels (the top 12 rows are headroom for hats); the app scales it up 4×.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let W = 28, H = 40
/// Empty rows above the character, so costumes have room.
let headroom = 12

struct RGBA { var r, g, b, a: UInt8 }
func hex(_ v: UInt32) -> RGBA { RGBA(r: UInt8(v >> 16 & 0xff), g: UInt8(v >> 8 & 0xff), b: UInt8(v & 0xff), a: 255) }

let outline = hex(0x4A3B2E), beige = hex(0xEADFC4), shade = hex(0xCDBE9C), highlight = hex(0xFFF8E6)
let screenOn = hex(0x15301D), screenDim = hex(0x0C1A10), glare = hex(0x2C5238)
let phosphor = hex(0x6CFF8A), phosphorDim = hex(0x3B9E55)
let ledGreen = hex(0x6CFF8A), ledAmber = hex(0xFFB020)
let legColor = hex(0x4B4B57), shoe = hex(0x26262E), glove = hex(0xFFFFFF), zColor = hex(0x8A7CFF)

struct Canvas {
    var px = [RGBA](repeating: RGBA(r: 0, g: 0, b: 0, a: 0), count: W * H)

    // (0,0) is the top-left pixel of the character, below the headroom.
    mutating func set(_ x: Int, _ y: Int, _ c: RGBA) {
        let y = y + headroom
        guard x >= 0, x < W, y >= 0, y < H else { return }
        px[y * W + x] = c
    }

    mutating func rect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ c: RGBA) {
        for y in min(y0, y1)...max(y0, y1) { for x in min(x0, x1)...max(x0, x1) { set(x, y, c) } }
    }

    mutating func points(_ pts: [(Int, Int)], _ c: RGBA) {
        for (x, y) in pts { set(x, y, c) }
    }

    func write(to url: URL) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(W * H * 4)
        for p in px { bytes += [p.r, p.g, p.b, p.a] }
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

enum Eyes { case open, lookRight, blink, wide, squint, happy }
enum Mouth { case smile, open, closed, oh, wavy, frown, tiny, grin }
enum Legs { case stand, stride, liftLeft, liftRight }
enum Arms { case down, up, wave, droop }

struct Pose {
    var eyes = Eyes.open
    var mouth = Mouth.smile
    var legs = Legs.stand
    var arms = Arms.down
    var bob = 0        // body raised by this many pixels
    var dim = false    // screen dimmed (sulking/sleeping)
    var z: Int? = nil  // floating "z" frame for sleeping
}

func draw(_ p: Pose) -> Canvas {
    var c = Canvas()
    let b = -p.bob

    // Legs (behind the body). They always reach the floor at row 26.
    let legTop = 21 + b
    switch p.legs {
    case .stand:
        c.rect(12, legTop, 12, 25, legColor); c.rect(11, 26, 13, 26, shoe)
        c.rect(16, legTop, 16, 25, legColor); c.rect(16, 26, 18, 26, shoe)
    case .stride:
        c.rect(12, legTop, 12, 23, legColor); c.rect(11, 24, 11, 25, legColor); c.rect(9, 26, 11, 26, shoe)
        c.rect(16, legTop, 16, 23, legColor); c.rect(17, 24, 17, 25, legColor); c.rect(17, 26, 19, 26, shoe)
    case .liftLeft:
        c.rect(12, legTop, 12, 24, legColor); c.rect(12, 25, 14, 25, shoe)
        c.rect(16, legTop, 16, 25, legColor); c.rect(16, 26, 18, 26, shoe)
    case .liftRight:
        c.rect(12, legTop, 12, 25, legColor); c.rect(11, 26, 13, 26, shoe)
        c.rect(16, legTop, 16, 24, legColor); c.rect(16, 25, 18, 25, shoe)
    }

    // Arms
    func arm(_ x: Int, _ y0: Int, _ y1: Int, hand hx: Int, _ hy: Int) {
        c.rect(x, y0 + b, x, y1 + b, outline)
        c.rect(hx, hy + b, hx + 1, hy + 1 + b, glove)
    }
    switch p.arms {
    case .down:
        arm(4, 9, 13, hand: 3, 14); arm(23, 9, 13, hand: 23, 14)
    case .up:
        arm(4, 5, 9, hand: 3, 3); arm(23, 5, 9, hand: 23, 3)
    case .wave:
        arm(4, 9, 13, hand: 3, 14); arm(23, 5, 9, hand: 23, 3)
    case .droop:
        arm(4, 10, 15, hand: 4, 16); arm(23, 10, 15, hand: 22, 16)
    }

    // Case
    c.rect(5, 3 + b, 22, 18 + b, outline)
    c.rect(6, 4 + b, 21, 17 + b, beige)
    c.rect(6, 4 + b, 21, 4 + b, highlight)
    c.rect(21, 5 + b, 21, 17 + b, shade)
    c.rect(6, 17 + b, 21, 17 + b, shade)
    // Screen with bezel
    c.rect(7, 5 + b, 20, 14 + b, shade)
    c.rect(8, 6 + b, 19, 13 + b, p.dim ? screenDim : screenOn)
    if !p.dim { c.points([(18, 7 + b), (19, 7 + b), (19, 8 + b)], glare) }
    // Floppy slot and power LED
    c.rect(15, 16 + b, 19, 16 + b, outline)
    c.set(8, 16 + b, p.dim ? ledAmber : ledGreen)
    // Stand
    c.rect(10, 19 + b, 17, 19 + b, outline)
    c.rect(11, 19 + b, 16, 19 + b, shade)
    c.rect(10, 20 + b, 17, 20 + b, outline)

    // Face, in phosphor green
    let ink = p.dim ? phosphorDim : phosphor
    func face(_ pts: [(Int, Int)]) { c.points(pts.map { ($0.0, $0.1 + b) }, ink) }
    func faceRect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) { c.rect(x0, y0 + b, x1, y1 + b, ink) }

    switch p.eyes {
    case .open:
        faceRect(10, 8, 11, 9); faceRect(16, 8, 17, 9)
    case .lookRight:
        faceRect(11, 8, 12, 9); faceRect(17, 8, 18, 9)
    case .blink:
        faceRect(10, 9, 11, 9); faceRect(16, 9, 17, 9)
    case .wide:
        face([(9, 7), (10, 7), (11, 7), (9, 8), (11, 8), (9, 9), (10, 9), (11, 9)])
        face([(16, 7), (17, 7), (18, 7), (16, 8), (18, 8), (16, 9), (17, 9), (18, 9)])
    case .squint:
        face([(10, 7), (11, 8), (10, 9)])
        face([(17, 7), (16, 8), (17, 9)])
    case .happy:
        face([(9, 9), (10, 8), (11, 8), (12, 9)])
        face([(15, 9), (16, 8), (17, 8), (18, 9)])
    }

    switch p.mouth {
    case .smile:
        faceRect(11, 12, 16, 12); face([(10, 11), (17, 11)])
    case .open:
        faceRect(12, 11, 15, 12)
    case .closed:
        faceRect(12, 12, 15, 12)
    case .oh:
        faceRect(13, 11, 14, 12)
    case .wavy:
        face([(11, 12), (12, 11), (13, 12), (14, 11), (15, 12), (16, 11)])
    case .frown:
        faceRect(11, 11, 16, 11); face([(10, 12), (17, 12)])
    case .tiny:
        faceRect(13, 12, 14, 12)
    case .grin:
        faceRect(10, 11, 17, 11); faceRect(11, 12, 16, 12)
    }

    // A little "z" drifting up while asleep
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
    "idle_1": Pose(eyes: .blink),
    "walk_0": Pose(eyes: .lookRight, legs: .stride),
    "walk_1": Pose(eyes: .lookRight, legs: .stand, bob: 1),
    "walk_2": Pose(eyes: .lookRight, legs: .liftLeft),
    "walk_3": Pose(eyes: .lookRight, legs: .stand, bob: 1),
    "fall_0": Pose(eyes: .wide, mouth: .oh, arms: .up),
    "drag_0": Pose(eyes: .squint, mouth: .wavy, legs: .liftLeft, arms: .up),
    "drag_1": Pose(eyes: .squint, mouth: .wavy, legs: .liftRight, arms: .up),
    "talk_0": Pose(mouth: .open, arms: .wave),
    "talk_1": Pose(mouth: .closed, arms: .down),
    "sulk_0": Pose(eyes: .blink, mouth: .frown, arms: .droop, dim: true),
    "happy_0": Pose(eyes: .happy, mouth: .grin, arms: .up, bob: 1),
    "happy_1": Pose(eyes: .happy, mouth: .grin, arms: .wave),
    "sleep_0": Pose(eyes: .blink, mouth: .tiny, dim: true, z: 0),
    "sleep_1": Pose(eyes: .blink, mouth: .tiny, dim: true, z: 1),
]

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for (name, pose) in frames.sorted(by: { $0.key < $1.key }) {
    draw(pose).write(to: outDir.appendingPathComponent("\(name).png"))
}
print("Wrote \(frames.count) frames to \(outDir.path)")

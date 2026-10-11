import AppKit
import ImageIO

/// The `character.json` inside a sprite character folder.
struct SpriteManifest: Decodable {
    struct Animation: Decodable {
        var frames: [String]
        var fps: Double
        var loop: Bool?
    }

    /// A point in source pixels (top-left origin) plus a size: the hat's width or the prop's height.
    struct Anchor: Decodable {
        var x: Double
        var y: Double
        var size: Double

        private enum CodingKeys: String, CodingKey { case x, y, width, height }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = try c.decode(Double.self, forKey: .x)
            y = try c.decode(Double.self, forKey: .y)
            // Hats give a "width" and props a "height"; older manifests used "width" for both.
            size = try c.decodeIfPresent(Double.self, forKey: .height) ?? c.decode(Double.self, forKey: .width)
        }
    }

    var name: String
    /// Size of one frame image, in pixels.
    var frameWidth: Double
    var frameHeight: Double
    /// How many points each pixel becomes on screen (pixel art looks best at whole numbers).
    var scale: Double?
    /// Empty pixel rows below the feet.
    var footInset: Double?
    var walkSpeed: Double?
    var bounciness: Double?
    /// Which way the artwork faces. Frames are mirrored for the other direction.
    var facesRight: Bool?
    /// Where a hat's bottom-center goes, and how wide it is.
    var hat: Anchor?
    /// Where a held prop's bottom-center goes, and how tall it is.
    var hand: Anchor?
    /// walk, waddle, hop, roll or float.
    var movement: String?
    /// Keyed by state name: idle, walk, fall, drag, talk, sulk, sleep, happy. Only idle is required.
    var animations: [String: Animation]
    var quips: [String]?
}

struct CharacterLoadError: Error, CustomStringConvertible {
    let description: String
}

/// A character made of frame-by-frame images, loaded from a folder.
final class SpritePack: CharacterPack {
    struct Animation {
        let frames: [CGImage]
        let fps: Double
        let loop: Bool
    }

    let id: String
    let name: String
    let size: NSSize
    let headTop: CGFloat
    let footInset: CGFloat
    let walkSpeed: CGFloat
    let bounciness: CGFloat
    let quips: [String]
    let facesRight: Bool
    let movement: MovementStyle
    /// Hat anchor and width in points, in the character's own (unflipped) coordinates.
    let hat: (anchor: CGPoint, width: CGFloat)?
    let hand: (anchor: CGPoint, height: CGFloat)?
    private let animations: [CreatureState: Animation]

    init(folder: URL) throws {
        let manifestURL = folder.appendingPathComponent("character.json")
        let manifest = try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: manifestURL))
        let scale = manifest.scale ?? 1
        guard manifest.frameWidth > 0, manifest.frameHeight > 0, scale > 0,
              max(manifest.frameWidth, manifest.frameHeight) * scale <= 1000 else {
            throw CharacterLoadError(description: "frameWidth, frameHeight and scale must be positive (and not absurdly big)")
        }

        var cache: [String: CGImage] = [:]
        var animations: [CreatureState: Animation] = [:]
        for (key, anim) in manifest.animations {
            guard let state = CreatureState(rawValue: key) else {
                throw CharacterLoadError(description: "Unknown animation '\(key)'. Use one of: \(CreatureState.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            let frames = try anim.frames.map { file -> CGImage in
                if let cached = cache[file] { return cached }
                let url = folder.appendingPathComponent(file)
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    throw CharacterLoadError(description: "Can't read image \(file)")
                }
                cache[file] = image
                return image
            }
            if !frames.isEmpty {
                animations[state] = Animation(frames: frames, fps: min(max(anim.fps, 0.1), 60), loop: anim.loop ?? true)
            }
        }
        guard animations[.idle] != nil else {
            throw CharacterLoadError(description: "An 'idle' animation is required")
        }

        // Converts a manifest anchor to points in the character's own (y-up) coordinates.
        func points(_ a: SpriteManifest.Anchor) -> (CGPoint, CGFloat) {
            (CGPoint(x: a.x * scale, y: (manifest.frameHeight - a.y) * scale), CGFloat(a.size * scale))
        }

        id = folder.lastPathComponent
        name = manifest.name
        size = NSSize(width: manifest.frameWidth * scale, height: manifest.frameHeight * scale)
        // The hat sits on the head, so its anchor marks the top of the head.
        headTop = manifest.hat.map { CGFloat((manifest.frameHeight - $0.y) * scale) } ?? size.height
        footInset = CGFloat(max(manifest.footInset ?? 0, 0) * scale)
        walkSpeed = CGFloat(min(max(manifest.walkSpeed ?? 60, 5), 400))
        // At 1 or more it would never stop bouncing.
        bounciness = CGFloat(min(max(manifest.bounciness ?? 0.3, 0), 0.9))
        quips = manifest.quips ?? []
        facesRight = manifest.facesRight ?? true
        movement = manifest.movement.flatMap(MovementStyle.init(rawValue:)) ?? .walk
        hat = manifest.hat.map(points)
        hand = manifest.hand.map(points)
        self.animations = animations
    }

    /// Missing animations fall back to idle, so a minimal pack can be a single image.
    func animation(for state: CreatureState) -> Animation {
        animations[state] ?? animations[.idle]!
    }

    func makeView() -> CharacterView {
        SpriteView(pack: self)
    }
}

/// Shows the frames as layer contents, so the window server scales, turns and mirrors them on the
/// GPU and nothing is redrawn until the animation moves on to the next frame.
final class SpriteView: CharacterView {
    private let pack: SpritePack
    /// The character's own drawing area (`pack.size`), spun and mirrored; shows the current frame.
    private let sprite = CALayer()
    private let costumeLayer = CALayer()
    private let propLayer = PaintedLayer()
    private var shownImage: CGImage?
    private var shownCostume: Costume?

    init(pack: SpritePack) {
        self.pack = pack
        super.init(frame: NSRect(origin: .zero, size: pack.size))
        // Pixel art stays crisp, enlarged or shrunk.
        sprite.magnificationFilter = .nearest
        sprite.minificationFilter = .nearest
        contentLayer.addSublayer(sprite)
        sprite.addSublayer(costumeLayer)
        sprite.addSublayer(propLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func remakePictures() {
        propLayer.contentsScale = pictureScale
        shownCostume = nil
        costumeLayer.contents = nil
    }

    override func updateContent() {
        let anim = pack.animation(for: state)
        let index = Int(stateTime * anim.fps)
        let image = anim.frames[anim.loop ? index % anim.frames.count : min(index, anim.frames.count - 1)]
        if image !== shownImage {
            shownImage = image
            sprite.contents = image
        }

        // In the character's own coordinates (not `bounds`), so the creature can scale and spin us.
        let content = CGRect(origin: .zero, size: pack.size)
        sprite.bounds = content
        sprite.position = CGPoint(x: content.midX, y: content.midY)
        var transform = CGAffineTransform(rotationAngle: spin)
        if facingRight != pack.facesRight { transform = transform.scaledBy(x: -1, y: 1) }
        sprite.setAffineTransform(transform)

        if costume != shownCostume {
            shownCostume = costume
            costumeLayer.contents = nil
            if let costume, let hat = pack.hat {
                costumeLayer.showPicture(of: costume.area(anchor: hat.anchor, width: hat.width), scale: pictureScale) { ctx in
                    costume.draw(in: ctx, anchor: hat.anchor, width: hat.width)
                }
            }
        }
        propLayer.isHidden = prop == nil || pack.hand == nil
        if let prop, let hand = pack.hand {
            propLayer.repaint(prop.area(anchor: hand.anchor, height: hand.height)) { [time] ctx in
                prop.draw(in: ctx, anchor: hand.anchor, height: hand.height, t: CGFloat(time))
            }
        }
    }
}

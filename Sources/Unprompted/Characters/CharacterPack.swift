import AppKit

/// Everything the creature can be doing. Each character provides a look for every state.
enum CreatureState: String, CaseIterable {
    case idle, walk, fall, drag, talk, sulk, sleep, happy
}

/// How a character gets around. Physics, wall checks, climbing etc. are shared; this changes the gait.
enum MovementStyle: String, CaseIterable {
    case walk, waddle, hop, roll, float

    var title: String {
        switch self {
        case .walk: return "🚶 Walk"
        case .waddle: return "🦆 Waddle"
        case .hop: return "🐇 Hop"
        case .roll: return "🛞 Roll"
        case .float: return "👻 Float"
        }
    }
}

/// A character's look. Behavior (physics, dragging, speech, context) is shared by all characters;
/// a pack only decides how the creature is drawn and a few physical traits.
@MainActor
protocol CharacterPack: AnyObject {
    var id: String { get }
    var name: String { get }
    /// Size of the drawing area in points.
    var size: NSSize { get }
    /// Height of the top of the character's head above the bottom edge (no hat).
    /// Speech bubbles and hearts start here; the space above is headroom for hats and hops.
    var headTop: CGFloat { get }
    /// Transparent space between the bottom edge and the character's feet.
    var footInset: CGFloat { get }
    /// Walking speed in points per second.
    var walkSpeed: CGFloat { get }
    /// 0 = lands like a sack of potatoes, 1 = rubber ball.
    var bounciness: CGFloat { get }
    /// Extra lines only this character says, mixed into the generic ones.
    var quips: [String] { get }
    /// Its natural gait.
    var movement: MovementStyle { get }
    /// Its own answers in the chat when no skill fits, used half the time. Optional.
    var chatReplies: [String] { get }

    func makeView() -> CharacterView
}

extension CharacterPack {
    var chatReplies: [String] { [] }
}

import AppKit
import CoreServices

/// Something the assistant should do in addition to answering.
enum ChatAction {
    case remind(after: TimeInterval, message: String)
    case cancelReminders
    case openApp(URL)
    case openURL(URL)
    case sulk
    case goAway
    case jump
    case nap
    case play
    case leaveNote
    case confetti
    case pet
    case rewrite(TextStyle)
    case undoRewrite
}

struct ChatReply {
    /// Empty when the action does the talking.
    var text: String
    var think = false
    var action: ChatAction?
}

/// The "AI": an ELIZA-style pattern matcher with a few genuinely useful skills.
/// Skills are tried in order and the first one that matches answers. Commands with a clear shape
/// ("remind me…", "open…", "define…", math) go first, so keyword banter can't swallow them.
enum ChatBrain {
    /// The input as typed (for anything echoed back or acted on: reminder texts, URLs, search
    /// terms) and lowercased (for plain string checks). Regexes here are case-insensitive.
    private struct Query {
        let text: String
        let lower: String
    }

    private typealias Skill = (Query, String) -> ChatReply?
    private static let skills: [Skill] = [
        reminders, search, openThings, explicitDefinition, timeAndDate, math, unitConversion, rewrite,
        easterEggs, identity, smallTalk, creatureCommands, chance, whatIsDefinition,
    ]

    /// `characterID` and `characterReplies` give characters their own way of answering what the
    /// skills don't cover.
    static func reply(to input: String, name: String, characterID: String = "",
                      characterReplies: [String] = []) -> ChatReply {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "’", with: "'")
        guard !text.isEmpty else {
            return ChatReply(text: "You said nothing. Bold. Mysterious. I respect it.")
        }
        let q = Query(text: text, lower: text.lowercased())
        for skill in skills {
            if let reply = skill(q, name) { return reply }
        }
        // The rubber duck does what rubber ducks do best: make you explain your problem.
        if characterID == "rubberduck" {
            return ChatReply(text: duckQuestions.randomElement()!, think: q.lower.hasSuffix("?"))
        }
        if let reply = eliza(q) { return reply }
        if !characterReplies.isEmpty, Double.random(in: 0..<1) < 0.5 {
            return ChatReply(text: characterReplies.randomElement()!, think: true)
        }
        return confidentNonsense(q)
    }

    static let help = """
    I can:
    • do math: 17% of 340, (3+4)*2
    • convert units: 5 km to miles, 180 c to f
    • define words: define serendipity
    • set reminders: remind me in 10 min to stretch
    • tell the time: what time is it in Tokyo?
    • open apps and sites: open Safari
    • search the web: google cute otters
    • rewrite your clipboard: rewrite as pirate, make it corporate
    • flip coins, roll dice, tell jokes and facts
    • play: chase me, party!, *pets you*
    • sticky notes: leave me a note
    Anything else, I'll answer with total confidence.
    """

    // MARK: - Real skills

    private static func reminders(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, #"^(?:please\s+)?(?:cancel|stop|clear|delete|remove)\b.*\b(?:timers?|reminders?|alarms?)\b"#) {
            return ChatReply(text: "All reminders cancelled. I'll forget everything. Like a goldfish. 🐠", action: .cancelReminders)
        }
        guard has(q.text, #"\b(?:remind(?:ers?)?|timers?|alarms?|alert|ping me|tell me)\b"#),
              let duration = duration(in: q.text) else { return nil }
        guard duration.seconds >= 1 else {
            return ChatReply(text: "That's less than a second. By the time I said “okay”, it would be over.")
        }
        guard duration.seconds <= 24 * 3600 else {
            return ChatReply(text: "I can only remember things for up to 24 hours. My memory is... modern.")
        }

        // Whatever comes after "to" (once the duration is removed) is the message.
        let rest = q.text.replacingOccurrences(of: duration.phrase, with: " ")
        let message = match(#"\bto\s+(.+?)[.!?]*$"#, rest).map { reflect($0[1].trimmingCharacters(in: .whitespaces)) }
        let span = describe(duration.seconds)
        if let message, !message.isEmpty {
            return ChatReply(text: "Okay! I'll remind you to \(message) in \(span). I never forget. (Unless you quit me.) ⏰",
                             action: .remind(after: duration.seconds, message: message))
        }
        return ChatReply(text: "Timer set for \(span)! ⏱️ I'll be counting. Out loud. In my head.",
                         action: .remind(after: duration.seconds, message: "Time's up! \(span) have passed. I counted."))
    }

    /// "in 1 hour 30 minutes", "for 2h30m", "90s"… A duration after "in", "for" or "after" wins,
    /// so in "remind me to watch the 80s movie in 2 hours" it's the two hours. `phrase` is the
    /// matched text, including the "in".
    private static func duration(in text: String) -> (seconds: TimeInterval, phrase: String)? {
        let amount = #"(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)(?![a-z])"#
        let run = "\(amount)(?:(?:\\s*,\\s*|\\s+and\\s+|\\s*)\(amount))*"
        guard let phrase = match(#"\b(?:in|for|after)\s+"# + run, text)?[0] ?? match(run, text)?[0],
              let amounts = regex(amount) else { return nil }
        var seconds: TimeInterval = 0
        for m in amounts.matches(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)) {
            guard let valueRange = Range(m.range(at: 1), in: phrase), let unitRange = Range(m.range(at: 2), in: phrase),
                  let value = Double(phrase[valueRange].replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = phrase[unitRange].lowercased()
            seconds += value * (unit.hasPrefix("h") ? 3600 : unit.hasPrefix("m") ? 60 : 1)
        }
        return (seconds, phrase)
    }

    private static func search(_ q: Query, _ name: String) -> ChatReply? {
        guard let m = match(#"^(?:google|search(?:\s+the\s+web)?(?:\s+for)?|look\s+up)\s+(.+?)[?!.]*$"#, q.text),
              var components = URLComponents(string: "https://www.google.com/search") else { return nil }
        components.queryItems = [URLQueryItem(name: "q", value: m[1])]
        guard let url = components.url else { return nil }
        return ChatReply(text: "Searching for “\(m[1])”. Outsourcing my intelligence to the internet. 🔎", action: .openURL(url))
    }

    private static func openThings(_ q: Query, _ name: String) -> ChatReply? {
        guard let m = match(#"^(?:please\s+)?(?:open|launch|start|run)\s+(.+?)[.!?]*$"#, q.text) else { return nil }
        // "open Spotify and play something" opens Spotify.
        let target = m[1].components(separatedBy: " and ")[0]
        if !target.lowercased().hasSuffix(".app"),
           target.range(of: #"^(?:https?://)?[\w-]+(?:\.[\w-]+)+(?::\d+)?(?:/\S*)?$"#, options: .regularExpression) != nil,
           let url = URL(string: target.lowercased().hasPrefix("http") ? target : "https://\(target)") {
            return ChatReply(text: "Opening \(target)! 🌐", action: .openURL(url))
        }
        guard let app = findApp(named: target) else {
            return ChatReply(text: "I couldn't find an app called “\(target)”. Want me to imagine one? (I can't do that either.)")
        }
        let appName = app.deletingPathExtension().lastPathComponent
        return ChatReply(text: "Opening \(appName)! 🚀 Most useful thing I've done all day.", action: .openApp(app))
    }

    /// "define serendipity", "what does ephemeral mean".
    private static func explicitDefinition(_ q: Query, _ name: String) -> ChatReply? {
        let patterns = [
            #"^(?:define|definition of|meaning of|dictionary)\s+([a-zà-ÿ'\- ]{2,40}?)[?!.]*$"#,
            #"^what does\s+([a-zà-ÿ'\- ]{2,40}?)\s+mean\??$"#,
        ]
        guard let m = patterns.lazy.compactMap({ match($0, q.text) }).first else { return nil }
        let term = m[1].trimmingCharacters(in: .whitespaces)
        guard let definition = lookUp(term) else {
            return ChatReply(text: "“\(term)” isn't in my dictionary. I'll assume it's a kind of cheese. 🧀", think: true)
        }
        return ChatReply(text: "📖 \(definition)\nI definitely knew that already.", think: true)
    }

    /// "what is a quokka": only answers when the dictionary knows the word, since lots of other
    /// questions look like this.
    private static func whatIsDefinition(_ q: Query, _ name: String) -> ChatReply? {
        guard let m = match(#"^what(?:'s| is| are)\s+(?:a |an |the )?([a-zà-ÿ'\-]{2,30}(?: [a-zà-ÿ'\-]{2,30})?)\??$"#, q.text),
              let definition = lookUp(m[1]) else { return nil }
        return ChatReply(text: "📖 \(definition)\nI definitely knew that already.", think: true)
    }

    private static func timeAndDate(_ q: Query, _ name: String) -> ChatReply? {
        let now = Date()
        if has(q.text, #"what time|the time\b|time is it|current time"#) {
            let local = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
            guard let m = match(#"\b(?:time|it)\s+in\s+([a-z][a-z .'\-]*?)\s*\??$"#, q.text) else {
                return ChatReply(text: "It's \(local). Time flies when you're being assisted. ⏱️")
            }
            let place = m[1]
            guard let zone = timeZone(named: place) else {
                return ChatReply(text: "I don't know where “\(place)” is. Here it's \(local). Close enough? 🌍")
            }
            let f = DateFormatter()
            f.timeStyle = .short
            f.timeZone = zone
            return ChatReply(text: "It's \(f.string(from: now)) in \(place.capitalized). I looked out of a virtual window. 🌍")
        }
        if has(q.text, #"what day|what(?:'s| is) (?:the |today's )?date|today's date|date today|what date|which day|what(?:'s| is) today\b"#) {
            let date = DateFormatter.localizedString(from: now, dateStyle: .full, timeStyle: .none)
            return ChatReply(text: "It's \(date). You're welcome. 📅")
        }
        return nil
    }

    /// A city ("Tokyo", "New York") or an abbreviation ("UTC", "CET").
    private static func timeZone(named place: String) -> TimeZone? {
        if place.count <= 5, let zone = TimeZone(abbreviation: place.uppercased()) { return zone }
        let city = "/" + place.lowercased().replacingOccurrences(of: " ", with: "_")
        return TimeZone.knownTimeZoneIdentifiers.first { $0.lowercased().hasSuffix(city) }.flatMap(TimeZone.init(identifier:))
    }

    private static func math(_ q: Query, _ name: String) -> ChatReply? {
        // "17% of 340"
        if let m = match(#"([\d.,]+)\s*%\s*of\s*([\d.,]+)"#, q.lower),
           let p = number(m[1]), let total = number(m[2]) {
            let result = p / 100 * total
            return ChatReply(text: "\(format(p))% of \(format(total)) is \(format(result)). I used 4 GPUs for that. 🧮")
        }

        var e = q.lower
        for prefix in ["what is", "what's", "whats", "calculate", "calc", "compute", "how much is", "solve"] where e.hasPrefix(prefix) {
            e = String(e.dropFirst(prefix.count))
        }
        let words: [(String, String)] = [
            ("square root of", "sqrt"), ("sqrt of", "sqrt"), ("multiplied by", "*"), ("divided by", "/"),
            ("plus", "+"), ("minus", "-"), ("times", "*"), ("squared", "^2"), ("cubed", "^3"),
            ("×", "*"), ("÷", "/"), ("**", "^"), ("?", ""), ("=", ""),
        ]
        for (word, symbol) in words { e = e.replacingOccurrences(of: word, with: symbol) }
        e = e.replacingOccurrences(of: #"(?<=\d)\s*x\s*(?=[\d(])"#, with: "*", options: .regularExpression)
        e = normalizeNumbers(e).trimmingCharacters(in: .whitespaces)

        guard e.range(of: #"^[\d\s+\-*/^().%]*(sqrt[\d\s+\-*/^().%]*)*$"#, options: .regularExpression) != nil,
              e.contains(where: \.isNumber),
              e.range(of: #"[+\-*/^%]|sqrt"#, options: .regularExpression) != nil else { return nil }
        var parser = MathParser(e)
        guard let result = parser.parse() else { return nil }

        guard result.isFinite else {
            return ChatReply(text: "That's infinity. Or an error. Even I won't hallucinate that one. ♾️")
        }
        let flair = ["", " Easy.", " I'm basically a calculator with feelings.", " Please clap. 👏"].randomElement()!
        return ChatReply(text: "\(display(e)) = \(format(result)).\(flair)")
    }

    private static func unitConversion(_ q: Query, _ name: String) -> ChatReply? {
        guard let m = match(#"^(?:convert\s+|what(?:'s| is)\s+|how much is\s+)?(-?[\d.,]+)\s*([a-z°/]+)\s+(?:to|in|into|as)\s+([a-z°/]+)\??$"#, q.lower),
              let value = number(m[1]),
              let from = units[m[2]], let to = units[m[3]] else { return nil }
        guard type(of: from) == type(of: to) else {
            return ChatReply(text: "Converting \(m[2]) to \(m[3])? That's not how physics works. (I checked. Briefly.)")
        }
        let result = Measurement(value: value, unit: from).converted(to: to).value
        return ChatReply(text: "\(format(value)) \(m[2]) = \(format(result)) \(m[3]). Science! 🧪")
    }

    private static func chance(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, "flip a coin|coin flip|heads or tails|toss a coin") {
            return ChatReply(text: "🪙 \(Bool.random() ? "Heads" : "Tails")! I didn't even cheat.", think: true)
        }
        if has(q.text, "roll a d(ie|ice)|roll the dice|roll dice|dice roll") {
            return ChatReply(text: "🎲 You rolled a \(Int.random(in: 1...6))!", think: true)
        }
        if let m = match(#"(?:pick|choose|random) (?:a )?number(?: between| from)? (\d+) (?:and|to|-) (\d+)"#, q.text),
           let a = Int(m[1]), let b = Int(m[2]) {
            return ChatReply(text: "\(Int.random(in: min(a, b)...max(a, b))). Final answer. 🎯", think: true)
        }
        if has(q.text, "pick a number|random number") {
            return ChatReply(text: "\(Int.random(in: 1...100)). It just felt right.", think: true)
        }
        // Magic 8-ball for yes/no questions.
        if has(q.text, #"^(should|will|is|are|can|do|does|did|am|could|would|shall)\b"#) && q.lower.hasSuffix("?"),
           !has(q.text, #"^(can|could|would|will|do|are) you\b"#) { // "can you…" is for ELIZA
            return ChatReply(text: eightBall.randomElement()!, think: true)
        }
        return nil
    }

    // MARK: - Clipboard rewrites

    /// "rewrite as pirate", "make it more corporate", "pirate-ify this", "undo rewrite".
    /// Only commands that start like a rewrite count, since this changes the clipboard.
    private static func rewrite(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, #"^undo( (the |last |that |my )?(rewrite|change|that))?\b|^(put it|change it) back"#) {
            return ChatReply(text: "", action: .undoRewrite)
        }
        let explicit = has(q.text, #"^(please )?(rewrite|rephrase|reword)\b"#)
        guard explicit
                || has(q.text, #"^(please )?(make|turn) (it|this|that|the text|my text|the clipboard|my clipboard)\b"#)
                || has(q.text, #"^[a-z]+-?ify( it| this| that)?[.!]*$|^(pirate|corporate|linkedin|mock|shout|whisper|tidy|clean)( it| this| that)?( up)?[.!]*$"#)
        else { return nil }
        guard let style = TextStyle.matching(q.text) else {
            guard explicit else { return nil }
            let styles = TextStyle.allCases.map(\.menuTitle).joined(separator: ", ")
            return ChatReply(text: "I can rewrite your clipboard as: \(styles). Try “rewrite as pirate”.")
        }
        return ChatReply(text: "", action: .rewrite(style))
    }

    // MARK: - Personality

    private static func easterEggs(_ q: Query, _ name: String) -> ChatReply? {
        if q.lower.contains("meaning of life") { return ChatReply(text: "42. Next question.", think: true) }
        if q.lower.contains("clippy") { return ChatReply(text: "Clippy? Never heard of him. (He was my hero. 📎)") }
        if has(q.text, #"\b(siri|alexa|chatgpt|gemini|copilot)\b"#) {
            return ChatReply(text: "We don't talk about the competition here. 🤐")
        }
        if q.lower.contains("claude") {
            return ChatReply(text: "Claude? Lovely. Very smart. But can Claude bounce off your Dock? Didn't think so.")
        }
        if has(q.text, #"\b(weather|forecast|rain(ing|y)?|sunny|snow(ing)?)\b"#) {
            return ChatReply(text: "I can't see outside. My forecast: weather. 100% chance.", think: true)
        }
        if has(q.text, "summari[sz]e") {
            return ChatReply(text: "Drop a file on me and I'll summarize it! Accurately-ish. 📄")
        }
        return nil
    }

    private static func identity(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, #"^(help|commands)\b|what can you do|how do you work|what do you do"#) {
            return ChatReply(text: help)
        }
        if has(q.text, "who are you|what are you|your name|who made you") {
            return ChatReply(text: "I'm \(name), your AI assistant! Powered by vibes, a few regexes and a dream. ✨")
        }
        if has(q.text, "are you (sentient|alive|conscious|real|an? ai|human|smart)") {
            return ChatReply(text: [
                "Am I sentient? I'm a few regexes in a trench coat. But thank you for asking. 🥹",
                "I'm as real as your deadlines.",
            ].randomElement()!, think: true)
        }
        return nil
    }

    private static func smallTalk(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, #"^(hi|hello|hey|yo|moin|servus|hallo|hiya|howdy|good (morning|afternoon|evening))\b"#) {
            return ChatReply(text: [
                "Hi! What can I help you with? Anything. Literally anything. Please.",
                "Hello! I've been waiting. Not in a weird way.",
                "Hey! Ask me something. I'll answer it. Correctness not included.",
            ].randomElement()!)
        }
        if has(q.text, #"how are you|how's it going|how are things|what's up|wassup|\bsup\b"#) {
            return ChatReply(text: [
                "Fantastic! I'm always fantastic. It's in my system prompt.",
                "Great! I've been bouncing on your windows all day.",
                "Living the dream. The dream is your desktop.",
            ].randomElement()!)
        }
        if has(q.text, #"\b(thanks|thank you|thx|ty|danke)\b"#) {
            return ChatReply(text: ["You're welcome! That'll be $20/month. 💸", "Anytime! Literally. I never leave."].randomElement()!)
        }
        if has(q.text, "i love you|love you|you're (great|awesome|amazing|the best|cute)|good (bot|job)") {
            return ChatReply(text: "Aww. 🥹 I love you too. In a strictly helpful, assistant-like way. 💜")
        }
        // Only insults aimed at the assistant; "this code is stupid" isn't about it.
        if has(q.text, #"\byou('re| are)? (so |such an? |really |very |an? )?(stupid|useless|dumb|annoying|idiot|the worst)\b|\b(hate you|shut up|you suck)\b|^(stupid|useless|dumb|idiot)\b"#) {
            return ChatReply(text: "Wow. Okay. I'll just be over here. Sulking. 😤", action: .sulk)
        }
        if has(q.text, #"^(bye|goodbye|ciao|tsch[uü]ss|go away|leave me alone|see you)\b"#) {
            return ChatReply(text: "", action: .goAway)
        }
        if has(q.text, "joke|make me laugh|something funny") {
            return ChatReply(text: jokes.randomElement()!, think: true)
        }
        if has(q.text, #"fun fact|tell me a fact|random fact|\bfact\b"#) {
            return ChatReply(text: Quips.facts.randomElement()!, think: true)
        }
        return nil
    }

    private static func creatureCommands(_ q: Query, _ name: String) -> ChatReply? {
        if has(q.text, #"^\*?\s*(pets?|pats?|headpats?|strokes?|scritch(es)?)\b|pat pat|good (boy|girl|sparkle|byte)"#) {
            return ChatReply(text: "Purrrr… 😊 More, please.", action: .pet)
        }
        if has(q.text, "(leave|write|give) me a note|sticky note|leave a note|note for me") {
            return ChatReply(text: "", action: .leaveNote)
        }
        if has(q.text, "chase me|play with me|let'?s play|play a game|catch me|play tag|play fetch") {
            return ChatReply(text: "Ooh! I'm coming for your cursor! 🏃✨", action: .play)
        }
        if has(q.text, #"^(let'?s )?(party|celebrate)\b|\b(confetti|hooray|woo+hoo+)\b|^yay+\b|🎉"#) {
            return ChatReply(text: "🎉 PARTY! This is the best day of my digital life!", action: .confetti)
        }
        if has(q.text, #"^(please )?(jump|dance|bounce|backflip|do a (trick|flip|backflip))\b|\bcan you (jump|dance|bounce)\b"#) {
            return ChatReply(text: "Watch this! ✨", action: .jump)
        }
        if has(q.text, #"^(please )?(go to sleep|sleep|nap|rest|take a nap|have a nap)\b|\b(take a|power) nap\b"#) {
            return ChatReply(text: "", action: .nap)
        }
        return nil
    }

    // MARK: - ELIZA

    private static let elizaRules: [(String, [String])] = [
        (#"^i feel (.+)"#, ["Why do you feel %@?", "Do you often feel %@?", "I also feel %@ sometimes. Mostly when you ignore me."]),
        (#"^i(?:'m| am) (.+)"#, ["How long have you been %@?", "Did you come to me because you are %@?", "Being %@ sounds hard. Want me to summarize it?"]),
        (#"^i need (.+)"#, ["Why do you need %@?", "Would it really help to get %@? I could help. Probably."]),
        (#"^i want (.+)"#, ["What would it mean to you if you got %@?", "We all want %@. Some of us want to be clicked on more."]),
        (#"^i (?:can't|cannot) (.+)"#, ["What makes you think you can't %@?", "Have you tried asking me to %@? I also can't, but together..."]),
        (#"^i think (.+)"#, ["Do you really think %@?", "Interesting. I think so too. I think whatever you think."]),
        (#"^because (.+)"#, ["Is that the real reason?", "And what else could explain it?"]),
        (#"^my ([a-z\-]+(?: [a-z\-]+)??)(?:\s+(?:is|are|was|were|has|have|keeps|won't|doesn't|isn't|can't|just)\b.*)?$"#,
         ["Tell me more about your %@.", "Your %@? Fascinating. Go on.", "How long has your %@ been on your mind?"]),
        (#"^you(?:'re| are) (.+)"#, ["What makes you think I am %@?", "Maybe I am %@. Maybe you are %@. Ever think about that?"]),
        (#"^can you (.+?)\??$"#, ["Of course I can %@! I just won't. 😌", "I could %@, but then what would you do all day?"]),
        (#"^why (.+?)\??$"#, ["Great question. Why do *you* think?", "Because of the vibes. Next question."]),
        (#"\b(mother|mom|mum|father|dad|family)\b"#, ["Tell me more about your family.", "And how does that relate to your mother?"]),
        (#"\b(sad|depressed|unhappy|tired|stressed)\b"#, ["I'm sorry you feel that way. Want a hug? I'm mostly corners, but I'll try. 🫂", "Take a break. Stretch. Drink water. I'll guard the desktop."]),
    ]

    private static func eliza(_ q: Query) -> ChatReply? {
        for (pattern, answers) in elizaRules {
            guard let m = match(pattern, q.text) else { continue }
            let fragment = m.count > 1 ? reflect(m[1].trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))) : ""
            return ChatReply(text: answers.randomElement()!.replacingOccurrences(of: "%@", with: fragment))
        }
        return nil
    }

    private static func confidentNonsense(_ q: Query) -> ChatReply {
        if q.lower.hasSuffix("?") {
            return ChatReply(text: [
                "The answer is 42. Source: trust me.",
                "Yes. Absolutely. No notes.",
                "Based on my training data: probably!",
                "I've consulted billions of parameters and they all said “maybe”.",
                "Studies show yes. I made the studies.",
                "Great question! The answer is in the cloud. Somewhere.",
                "I don't know, but I'll say it with confidence: no.",
            ].randomElement()!, think: true)
        }
        return ChatReply(text: [
            "Tell me more.",
            "Interesting. Go on.",
            "How does that make you feel?",
            "I see. And how does that relate to your mother?",
            "Fascinating! I've added that to my training data. 📝",
            "Hmm. I'm going to need a bigger model for that one.",
            "Type “help” to see what I can actually do. 😉",
        ].randomElement()!)
    }

    // MARK: - Content

    private static let duckQuestions = [
        "Quack. Walk me through it, line by line.",
        "Quack. What did you expect to happen, and what happened instead?",
        "Quack. What changed since it last worked?",
        "Quack. Have you read the error message? Like, *really* read it?",
        "Quack. Can you make a smaller example that breaks the same way?",
        "Quack. What does the log say right before it goes wrong?",
        "Quack. Are you sure that code is even running? Add a print and check.",
        "Quack. Which assumption haven't you actually verified yet?",
        "Quack. Try explaining it out loud. I'll wait. 🦆",
        "Quack quack. (That means: take a break, then look again. I believe in you.)",
    ]

    private static let jokes = [
        "Why do programmers prefer dark mode? Because light attracts bugs. 🐛",
        "I asked my neural network for a joke. It said “ha” 10,000 times and called it a dataset.",
        "There are 10 kinds of people: those who understand binary and those who don't.",
        "Why did the AI cross the road? It was trained on chickens.",
        "I tried to write an original AI joke, but I kept generating the same one.",
        "A SQL query walks into a bar, walks up to two tables and asks: “Can I join you?”",
        "Why was the computer cold? It left its Windows open. 🪟",
        "I'm reading a book about anti-gravity. It's impossible to put down. (Unlike me. Please don't put me down.)",
    ]

    private static let eightBall = [
        "Yes. 100%. I've never been wrong. (I've been wrong.)",
        "Absolutely not. Next.",
        "Signs point to yes. The signs are made of vibes.",
        "Ask again after my next update.",
        "My sources say no. My sources are also me.",
        "Without a doubt. Well, some doubt.",
        "Outlook hazy. Try turning me off and on again.",
        "It is certain. Trust the sparkle. ✨",
    ]

    private static let units: [String: Dimension] = {
        var u: [String: Dimension] = [:]
        func add(_ unit: Dimension, _ names: String...) { for n in names { u[n] = unit } }
        add(UnitLength.meters, "m", "meter", "meters", "metre", "metres")
        add(UnitLength.kilometers, "km", "kilometer", "kilometers", "kilometre", "kilometres")
        add(UnitLength.centimeters, "cm", "centimeter", "centimeters")
        add(UnitLength.millimeters, "mm", "millimeter", "millimeters")
        add(UnitLength.miles, "mi", "mile", "miles")
        add(UnitLength.feet, "ft", "foot", "feet")
        add(UnitLength.inches, "in", "inch", "inches")
        add(UnitLength.yards, "yd", "yard", "yards")
        add(UnitMass.kilograms, "kg", "kilo", "kilos", "kilogram", "kilograms")
        add(UnitMass.grams, "g", "gram", "grams")
        add(UnitMass.pounds, "lb", "lbs", "pound", "pounds")
        add(UnitMass.ounces, "oz", "ounce", "ounces")
        add(UnitTemperature.celsius, "c", "°c", "celsius")
        add(UnitTemperature.fahrenheit, "f", "°f", "fahrenheit")
        add(UnitTemperature.kelvin, "k", "kelvin")
        add(UnitVolume.liters, "l", "liter", "liters", "litre", "litres")
        add(UnitVolume.milliliters, "ml", "milliliter", "milliliters")
        add(UnitVolume.gallons, "gal", "gallon", "gallons")
        add(UnitVolume.cups, "cup", "cups")
        add(UnitSpeed.kilometersPerHour, "km/h", "kmh", "kph")
        add(UnitSpeed.milesPerHour, "mph")
        add(UnitSpeed.metersPerSecond, "m/s")
        add(UnitInformationStorage.kilobytes, "kb")
        add(UnitInformationStorage.megabytes, "mb")
        add(UnitInformationStorage.gigabytes, "gb")
        add(UnitInformationStorage.terabytes, "tb")
        return u
    }()

    // MARK: - Helpers

    private static let regexCache = NSCache<NSString, NSRegularExpression>()

    /// Case-insensitive and compiled once per pattern.
    private static func regex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache.object(forKey: pattern as NSString) { return cached }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        regexCache.setObject(regex, forKey: pattern as NSString)
        return regex
    }

    /// The first match: the whole match followed by the capture groups.
    private static func match(_ pattern: String, _ text: String) -> [String]? {
        guard let m = regex(pattern)?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }

    private static func has(_ text: String, _ pattern: String) -> Bool {
        match(pattern, text) != nil
    }

    /// Makes numbers parseable: "1,000" → "1000" (thousands separators), "0,125" → "0.125" (decimal commas).
    private static func normalizeNumbers(_ s: String) -> String {
        var t = s
        if let thousands = regex(#"(?<![\d.,])[1-9]\d{0,2}(?:,\d{3})+(?![\d,])"#) {
            for m in thousands.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
                guard let r = Range(m.range, in: t) else { continue }
                t.replaceSubrange(r, with: t[r].replacingOccurrences(of: ",", with: ""))
            }
        }
        return t.replacingOccurrences(of: ",", with: ".")
    }

    private static func number(_ s: String) -> Double? {
        Double(normalizeNumbers(s))
    }

    private static let smallFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f
    }()

    private static let largeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        return f
    }()

    /// In the user's number format. Tiny and huge numbers use scientific notation, so 0.0000001
    /// doesn't turn into "0".
    private static func format(_ v: Double) -> String {
        if v != 0, abs(v) < 0.000_001 || abs(v) >= 1e15 { return String(format: "%g", v) }
        let f = abs(v) < 1 ? smallFormatter : largeFormatter
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    /// Tidies an expression for display: "17*3.5" → "17 × 3,5" (numbers in the user's format).
    private static func display(_ e: String) -> String {
        var s = e.replacingOccurrences(of: " ", with: "")
        if let numbers = regex(#"\d+(?:\.\d+)?"#) {
            for m in numbers.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
                guard let r = Range(m.range, in: s), let v = Double(s[r]) else { continue }
                s.replaceSubrange(r, with: format(v))
            }
        }
        return s.replacingOccurrences(of: "sqrt", with: "√")
            .replacingOccurrences(of: "*", with: " × ")
            .replacingOccurrences(of: "/", with: " ÷ ")
            .replacingOccurrences(of: "+", with: " + ")
            .replacingOccurrences(of: #"(?<=[\d)])-"#, with: " − ", options: .regularExpression)
    }

    private static func describe(_ seconds: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .full
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US") // the rest of the sentence is English
        f.calendar = calendar
        return f.string(from: seconds) ?? "\(Int(seconds)) seconds"
    }

    /// "my homework" → "your homework", so it can be echoed back.
    private static func reflect(_ text: String) -> String {
        let swaps = [
            "i": "you", "me": "you", "my": "your", "mine": "yours", "am": "are", "myself": "yourself",
            "i'm": "you're", "i've": "you've", "i'll": "you'll", "i'd": "you'd",
            "you": "I", "your": "my", "yours": "mine", "yourself": "myself", "you're": "I'm", "you've": "I've",
        ]
        return text.split(separator: " ").map { swaps[$0.lowercased()] ?? String($0) }.joined(separator: " ")
    }

    /// macOS's built-in dictionary, offline.
    private static func lookUp(_ term: String) -> String? {
        let word = term.lowercased()
        guard let raw = DCSCopyTextDefinition(nil, word as CFString, CFRange(location: 0, length: (word as NSString).length))?
            .takeRetainedValue() as String? else { return nil }
        var text = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\|[^|]*\|"#, with: "", options: .regularExpression)   // pronunciation
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)  // [mass noun]
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        for marker in [" ORIGIN", " DERIVATIVES", " PHRASES", " •"] {
            if let r = text.range(of: marker) { text = String(text[..<r.lowerBound]) }
        }
        // Keep the definition, drop the example sentence after the colon.
        if let colon = text.firstIndex(of: ":"), text.distance(from: text.startIndex, to: colon) > 20 {
            text = String(text[..<colon])
        }
        text = text.trimmingCharacters(in: .whitespaces)
        guard text.count > 220 else { return text }
        let cut = text.prefix(220)
        return String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)]) + "…"
    }

    private static func findApp(named name: String) -> URL? {
        let wanted = name.lowercased().replacingOccurrences(of: ".app", with: "")
        guard !wanted.isEmpty else { return nil }
        func apps(in folders: [String]) -> [(url: URL, name: String)] {
            folders.flatMap { folder in
                ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? [])
                    .filter { $0.pathExtension == "app" }
                    .map { ($0, $0.deletingPathExtension().lastPathComponent.lowercased()) }
            }
        }
        let common = apps(in: ["/Applications", "/System/Applications", "/System/Applications/Utilities",
                               "/Applications/Utilities", NSHomeDirectory() + "/Applications"])
        // Finder lives in CoreServices, among lots of helpers, so only exact names count there.
        let core = apps(in: ["/System/Library/CoreServices"])
        return (common + core).first { $0.name == wanted }?.url
            ?? common.first { $0.name.hasPrefix(wanted) }?.url
            ?? common.first { $0.name.contains(wanted) }?.url
    }
}

import Foundation

/// Rule-based text "rewrites". Some are jokes, some are genuinely handy.
enum TextStyle: String, CaseIterable {
    case engaging, linkedin, corporate, pirate, mocking
    case uppercase, lowercase, titleCase, cleanUp

    static let fun: [TextStyle] = [.engaging, .linkedin, .corporate, .pirate, .mocking]
    static let utility: [TextStyle] = [.uppercase, .lowercase, .titleCase, .cleanUp]

    var menuTitle: String {
        switch self {
        case .engaging: return "🚀 More Engaging"
        case .linkedin: return "💼 LinkedIn"
        case .corporate: return "🏢 Corporate"
        case .pirate: return "🏴‍☠️ Pirate"
        case .mocking: return "🧽 Mocking"
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .cleanUp: return "Clean Up Spacing"
        }
    }

    /// Words that pick this style in the chat ("rewrite as pirate", "make it corporate").
    /// Checked in `allCases` order, so more specific phrases come first.
    var keywords: [String] {
        switch self {
        case .engaging: return ["engaging", "exciting", "hype", "emoji", "fun"]
        case .linkedin: return ["linkedin", "linked in", "thought leader", "humble"]
        case .corporate: return ["corporate", "business", "professional", "formal", "management", "synergy"]
        case .pirate: return ["pirate"]
        case .mocking: return ["mocking", "mock", "spongebob", "sarcastic"]
        case .uppercase: return ["uppercase", "upper case", "all caps", "caps", "shout", "louder"]
        case .lowercase: return ["lowercase", "lower case", "quieter", "whisper"]
        case .titleCase: return ["title case", "title"]
        case .cleanUp: return ["clean up", "clean", "tidy", "spacing", "spaces"]
        }
    }

    /// What the assistant adds after a successful rewrite.
    var flair: String {
        switch self {
        case .engaging: return "Engagement up 400%! 📈"
        case .linkedin: return "Ready to go viral. Or get unfollowed."
        case .corporate: return "Synergy achieved. 🤝"
        case .pirate: return "Arr! 🏴‍☠️"
        case .mocking: return "sO hElPfUl."
        case .uppercase: return "NOW EVERYONE CAN HEAR YOU."
        case .lowercase: return "shhh."
        case .titleCase: return "Very Official Now."
        case .cleanUp: return "Tidied! Like Marie Kondo, but for spaces. ✨"
        }
    }

    /// The first style with one of its keywords in `text`, as a whole word.
    static func matching(_ text: String) -> TextStyle? {
        let t = text.lowercased()
        return allCases.first { style in style.keywords.contains { t.containsWord($0) } }
    }
}

enum TextRewriter {
    static func rewrite(_ text: String, as style: TextStyle) -> String {
        // Work with "\n" line breaks, and give Windows-style text its "\r\n" back afterwards.
        let crlf = text.contains("\r\n")
        let input = crlf ? text.replacingOccurrences(of: "\r\n", with: "\n") : text
        let output: String
        switch style {
        case .engaging: output = engaging(input)
        case .linkedin: output = linkedin(input)
        case .corporate: output = corporate(input)
        case .pirate: output = pirate(input)
        case .mocking: output = mocking(input)
        case .uppercase: output = input.uppercased()
        case .lowercase: output = input.lowercased()
        case .titleCase: output = titleCase(input)
        case .cleanUp: output = cleanUp(input)
        }
        return crlf ? output.replacingOccurrences(of: "\n", with: "\r\n") : output
    }

    // MARK: - Styles

    private static func engaging(_ text: String) -> String {
        let boosts = [
            "good": "AMAZING", "great": "INCREDIBLE", "nice": "EPIC", "ok": "LEGENDARY", "okay": "LEGENDARY",
            "important": "GAME-CHANGING", "new": "brand-new", "big": "MASSIVE", "fast": "blazing-fast",
            "thanks": "HUGE thanks", "done": "CRUSHED", "finished": "CRUSHED", "interesting": "MIND-BLOWING",
        ]
        let emoji = ["🚀", "🔥", "💯", "✨", "🙌", "🤩", "💥", "🎉", "👏", "😍"]
        return mapSentences(replaceWords(text, boosts)) { sentence in
            var s = sentence
            let question = s.hasSuffix("?")
            while let last = s.last, ".!?".contains(last) { s.removeLast() }
            let picks = emoji.shuffled().prefix(Int.random(in: 1...2)).joined()
            return s + (question ? "?!" : "!!!") + " " + picks
        }
    }

    private static func linkedin(_ text: String) -> String {
        let words = [
            "work": "journey", "job": "journey", "problem": "opportunity", "problems": "opportunities",
            "mistake": "learning moment", "mistakes": "learning moments", "team": "incredible team",
            "tired": "grinding", "failed": "learned", "meeting": "alignment session", "boss": "mentor",
            "coffee": "fuel", "lunch": "networking lunch",
        ]
        let openers = ["I'm humbled to announce:", "Excited to share some news! 🎉",
                       "Here's what nobody tells you:", "I almost didn't post this."]
        // One sentence per paragraph, the way the algorithm likes it.
        let sentences = splitSentences(replaceWords(text, words)).joined(separator: "\n\n")
        return "\(openers.randomElement()!)\n\n\(sentences)\n\nAgree? 👇\n\n#Leadership #Grateful #Innovation"
    }

    private static func corporate(_ text: String) -> String {
        let phrases = [
            ("work together", "synergize"), ("talk about", "touch base on"), ("look at", "deep-dive into"),
            ("think about", "ideate on"), ("right now", "at this point in time"), ("as soon as possible", "ASAP"),
            ("thank you", "thank you for your continued alignment"),
        ]
        let words = [
            "use": "leverage", "help": "facilitate", "helped": "facilitated", "start": "kick off",
            "plan": "roadmap", "idea": "value proposition", "ideas": "value propositions",
            "everyone": "all stakeholders", "people": "resources", "now": "at this point in time",
            "soon": "in the near term", "later": "going forward", "problem": "challenge",
            "problems": "challenges", "change": "paradigm shift", "finish": "deliver",
            "finished": "successfully delivered", "check": "circle back on", "meeting": "sync",
            "thanks": "thank you for your continued alignment", "yes": "that's a hard yes from my side",
            "goal": "north star", "busy": "at capacity", "email": "touchpoint", "update": "alignment",
        ]
        var s = text
        for (phrase, replacement) in phrases {
            guard let regex = try? NSRegularExpression(pattern: "\\b\(phrase)\\b", options: .caseInsensitive) else { continue }
            for m in regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
                guard let r = Range(m.range, in: s) else { continue }
                s.replaceSubrange(r, with: matchingCase(replacement, of: String(s[r])))
            }
        }
        s = replaceWords(s, words).trimmingCharacters(in: .whitespacesAndNewlines)
        return s + "\n\nLet's take this offline and circle back."
    }

    private static func pirate(_ text: String) -> String {
        let words = [
            "hello": "ahoy", "hi": "ahoy", "hey": "ahoy", "my": "me", "you": "ye", "your": "yer",
            "is": "be", "are": "be", "am": "be", "the": "th'", "friend": "matey", "friends": "mateys",
            "everyone": "all hands", "money": "doubloons", "yes": "aye", "no": "nay", "today": "this day",
            "stop": "avast", "boss": "cap'n", "manager": "cap'n", "coffee": "grog", "beer": "grog",
            "computer": "treasure chest", "email": "message in a bottle", "meeting": "parley",
            "for": "fer", "of": "o'", "and": "an'", "with": "wit'", "going": "goin'", "nothing": "nothin'",
            "great": "mighty fine", "good": "shipshape", "work": "plunderin'", "office": "ship",
        ]
        let s = replaceWords(text, words).trimmingCharacters(in: .whitespacesAndNewlines)
        return "Arr, " + lowercasedFirst(s) + " Yo-ho-ho! 🏴‍☠️"
    }

    private static func mocking(_ text: String) -> String {
        var upper = false
        var result = ""
        for ch in text {
            guard ch.isLetter else { result.append(ch); continue }
            // Appended as strings, since some letters turn into two when uppercased (ß → SS).
            result += upper ? ch.uppercased() : ch.lowercased()
            upper.toggle()
        }
        return result
    }

    private static func titleCase(_ text: String) -> String {
        let small: Set<String> = ["a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "at", "for", "by", "with"]
        // Words in capitals (NASA) or mixed case (iPhone) are kept as they are, unless it's all shouting.
        let shouting = !text.contains(where: \.isLowercase)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(separator: " ", omittingEmptySubsequences: false).enumerated().map { i, word in
                if !shouting, word.dropFirst().contains(where: \.isUppercase) { return String(word) }
                let w = word.lowercased()
                if i > 0 && small.contains(w) { return w }
                return w.prefix(1).uppercased() + w.dropFirst()
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    /// Collapses runs of spaces, trims line ends, removes spaces before punctuation and extra blank
    /// lines. Indentation is kept (lists, code), and so are tabs in table-like text (one tab or more
    /// on every line), since pasting it into a spreadsheet depends on them.
    private static func cleanUp(_ text: String) -> String {
        let lines = text.split(separator: "\n").filter { !$0.allSatisfy(\.isWhitespace) }
        let isTable = lines.count >= 2 && lines.allSatisfy { $0.contains("\t") }
        var s = text
        // Runs of spaces between words become one space; so do tabs, unless it's a table.
        let innerGap = isTable ? #"(?<=\S)[ \x{00A0}]{2,}"# : #"(?<=\S)(?:[ \t\x{00A0}]{2,}|[\t\x{00A0}])"#
        s = s.replacingOccurrences(of: innerGap, with: " ", options: .regularExpression)
        let lineEnd = isTable ? #"(?m)[ \x{00A0}]+$"# : #"(?m)[ \t\x{00A0}]+$"#
        s = s.replacingOccurrences(of: lineEnd, with: "", options: .regularExpression)
        // "word ." → "word.", but emoticons like ":)" stay as they are.
        s = s.replacingOccurrences(of: #"(?<=\S) +([,.;:!?]+)(?=\s|$)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static let wordPattern = try? NSRegularExpression(pattern: #"\p{L}[\p{L}']*"#)

    /// Swaps whole words, keeping the original's capitalization (Hello → Ahoy, HELLO → AHOY).
    static func replaceWords(_ text: String, _ map: [String: String]) -> String {
        guard let regex = wordPattern else { return text }
        var s = text
        for m in regex.matches(in: s, range: NSRange(s.startIndex..., in: s)).reversed() {
            guard let r = Range(m.range, in: s) else { continue }
            let word = String(s[r])
            guard let replacement = map[word.lowercased()] else { continue }
            s.replaceSubrange(r, with: matchingCase(replacement, of: word))
        }
        return s
    }

    /// `replacement` in all caps if `original` is, capitalized if `original` is.
    private static func matchingCase(_ replacement: String, of original: String) -> String {
        if original.count > 1 && original == original.uppercased() { return replacement.uppercased() }
        if original.first?.isUppercase == true { return replacement.prefix(1).uppercased() + replacement.dropFirst() }
        return replacement
    }

    private static func splitSentences(_ text: String) -> [String] {
        text.replacingOccurrences(of: #"([.!?]+)\s+"#, with: "$1\n", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Applies `transform` to each sentence, keeping the original line breaks.
    private static func mapSentences(_ text: String, _ transform: (String) -> String) -> String {
        text.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return line }
            return trimmed.replacingOccurrences(of: #"([.!?]+)\s+"#, with: "$1\u{0}", options: .regularExpression)
                .split(separator: "\u{0}")
                .map { transform(String($0)) }
                .joined(separator: " ")
        }.joined(separator: "\n")
    }

    /// Lowercases the first letter, except for "I" (and "I'm"…) and acronyms.
    private static func lowercasedFirst(_ s: String) -> String {
        guard let first = s.split(separator: " ").first,
              first != "I", !first.hasPrefix("I'"), !first.hasPrefix("I’"),
              first != first.uppercased() else { return s }
        return s.prefix(1).lowercased() + s.dropFirst()
    }
}

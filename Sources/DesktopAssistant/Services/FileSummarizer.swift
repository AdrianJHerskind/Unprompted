import AppKit
import AVFoundation
import ImageIO
import NaturalLanguage
import PDFKit
import UniformTypeIdentifiers

/// "AI summaries" that are really just honest stats, delivered with confidence.
/// Everything runs locally with built-in frameworks. Call off the main thread.
enum FileSummarizer {
    static func summarize(_ urls: [URL]) async -> String {
        guard let original = urls.first else { return "You gave me nothing. I summarized it anyway: nothing." }
        if urls.count > 1 { return summarizeMany(urls.map { $0.resolvingSymlinksInPath() }) }

        // Aliases and symlinks are followed, but the summary keeps the name you dropped.
        let url = original.resolvingSymlinksInPath()
        let title = shortName(original)
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .contentTypeKey])
        if values?.isDirectory == true && values?.isPackage != true { return summarizeFolder(url, title: title) }
        guard let type = values?.contentType else { return summarizeOther(url, title: title) }

        if type.conforms(to: .sourceCode) || type.conforms(to: .script) {
            return summarizeCode(url, title: title, type: type) ?? summarizeOther(url, title: title)
        }
        if type.conforms(to: .pdf) { return summarizePDF(url, title: title) ?? summarizeOther(url, title: title) }
        if type.conforms(to: .image) { return summarizeImage(url, title: title) ?? summarizeOther(url, title: title) }
        if type.conforms(to: .audiovisualContent) { return await summarizeMedia(url, title: title) ?? summarizeOther(url, title: title) }
        if let text = documentText(url, type: type) {
            return summarizeText(text, truncated: false, title: title)
        }
        if type.conforms(to: .html), let (html, truncated) = readText(url) {
            return summarizeText(plainText(fromHTML: html), truncated: truncated, title: title)
        }
        if type.conforms(to: .text), let (text, truncated) = readText(url) {
            return summarizeText(text, truncated: truncated, title: title)
        }
        return summarizeOther(url, title: title)
    }

    static func shortName(_ url: URL) -> String {
        let name = url.lastPathComponent
        guard name.count > 28 else { return name }
        return "\(name.prefix(18))…\(name.suffix(8))"
    }

    // MARK: - Text

    private static func summarizeText(_ text: String, truncated: Bool, title: String) -> String {
        let words = wordStats(text)
        guard words.count > 0 else {
            return "📄 Summary of “\(title)”\n• 0 words\nIt's empty. Best thing I've read all day. ✨"
        }
        let approx = truncated ? "~" : ""
        let minutes = max(1, Int((Double(words.count) / 230).rounded()))
        var lines = [
            "📄 Summary of “\(title)”",
            "• \(approx)\(num(words.count)) words · \(minutes) min read",
        ]
        if let language = language(of: text) { lines.append("• Language: \(language)") }
        if let top = words.mostUsed { lines.append("• Most-used word: “\(top)”") }
        if let mood = mood(of: text) { lines.append("• Vibe: \(mood)") }

        let exclamations = text.filter { $0 == "!" }.count
        let punchline: String
        if words.count < 40 {
            punchline = "Short and sweet. Like my attention span."
        } else if exclamations >= 3 && exclamations * 40 > words.count {
            punchline = "\(num(exclamations)) exclamation marks!!! Very engaging!!!"
        } else if minutes > 30 {
            punchline = "I read it so you don't have to. (I didn't read it.)"
        } else {
            punchline = [
                "Would you like me to make it longer?",
                "TL;DR: it's text. You're welcome.",
                "I'd rate it 4 stars. I didn't understand it, but it had nice letters.",
            ].randomElement()!
        }
        lines.append(punchline)
        return lines.joined(separator: "\n")
    }

    /// The plain text of a rich document (RTF, RTFD, Word, OpenDocument), or nil for other types.
    private static func documentText(_ url: URL, type: UTType) -> String? {
        // HTML is left out on purpose: AppKit's HTML importer must not run off the main thread.
        let formats: [(UTType?, NSAttributedString.DocumentType)] = [
            (.rtf, .rtf), (.rtfd, .rtfd),
            (UTType("org.openxmlformats.wordprocessingml.document"), .officeOpenXML),
            (UTType("com.microsoft.word.doc"), .docFormat),
            (UTType("org.oasis-open.opendocument.text"), .openDocument),
        ]
        guard let format = formats.first(where: { $0.0.map(type.conforms(to:)) ?? false })?.1 else { return nil }
        return (try? NSAttributedString(url: url, options: [.documentType: format], documentAttributes: nil))?.string
    }

    private static func plainText(fromHTML html: String) -> String {
        var s = html.replacingOccurrences(of: #"(?is)<(script|style)\b.*?</\1>"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            s = s.replacingOccurrences(of: entity, with: character)
        }
        return s
    }

    // MARK: - Code

    private static func summarizeCode(_ url: URL, title: String, type: UTType) -> String? {
        guard let (text, truncated) = readText(url) else { return nil }
        var allLines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        // A final line break ends the last line; it doesn't start a new one.
        if allLines.last?.isEmpty == true { allLines.removeLast() }
        var blank = 0, comments = 0, longest = (number: 0, length: 0)
        for (i, line) in allLines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { blank += 1; continue }
            if ["//", "/*", "*", "--", ";", "<!--", "# ", "##", "#!"].contains(where: t.hasPrefix) || t == "#" {
                comments += 1
            }
            if line.count > longest.length { longest = (i + 1, line.count) }
        }
        let todos = ["TODO", "FIXME", "HACK"].reduce(0) { $0 + text.components(separatedBy: $1).count - 1 }
        let functions = (try? NSRegularExpression(pattern: #"\b(func|def|function|fn|fun|sub)\s+\w"#))?
            .numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0
        let codeLines = allLines.count - blank - comments
        let language = type.localizedDescription ?? "Code"

        var lines = [
            "🧑‍💻 Summary of “\(title)”",
            "• \(language) · \(truncated ? "~" : "")\(num(allLines.count)) lines",
            "• \(num(codeLines)) code, \(num(comments)) comments, \(num(blank)) blank",
        ]
        if functions > 0 { lines.append("• \(num(functions)) functions") }
        if todos > 0 { lines.append("• \(num(todos)) TODO/FIXME/HACKs") }

        let punchline: String
        if todos >= 5 {
            punchline = "\(num(todos)) TODOs. Ambitious. Want me to add more?"
        } else if longest.length > 160 {
            punchline = "Line \(num(longest.number)) is \(num(longest.length)) characters long. Bold."
        } else if codeLines > 20 && comments * 20 < codeLines {
            punchline = "Barely any comments. You like to live dangerously."
        } else {
            punchline = [
                "Looks great. Have you considered rewriting it in Rust?",
                "I found 0 bugs. I also didn't look.",
                "10/10 code. It has letters AND symbols.",
            ].randomElement()!
        }
        lines.append(punchline)
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF

    private static func summarizePDF(_ url: URL, title: String) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        let pages = doc.pageCount
        let sampled = min(pages, 40)
        var text = ""
        for i in 0..<sampled { text += (doc.page(at: i)?.string ?? "") + "\n" }
        var words = wordStats(text)
        if pages > sampled, sampled > 0 { words.count = words.count * pages / sampled }

        var lines = ["📕 Summary of “\(title)”", "• \(num(pages)) page\(pages == 1 ? "" : "s")"]
        if words.count > 0 {
            let minutes = max(1, Int((Double(words.count) / 230).rounded()))
            lines[1] += " · \(pages > sampled ? "~" : "")\(num(words.count)) words · \(minutes) min read"
        }
        if let pdfTitle = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String, !pdfTitle.isEmpty {
            lines.append("• Title: “\(pdfTitle.prefix(40))”")
        }
        if let top = words.mostUsed { lines.append("• Most-used word: “\(top)”") }
        if let mood = mood(of: text) { lines.append("• Vibe: \(mood)") }

        if words.count == 0 {
            lines.append("No text inside. It's all pictures. Like a grown-up picture book.")
        } else if pages > 50 {
            lines.append("\(num(pages)) pages. I'll summarize it in one word: “long”.")
        } else {
            lines.append(["Key takeaway: there are words in it.", "I skimmed it. Vigorously."].randomElement()!)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Images

    private static func summarizeImage(_ url: URL, title: String) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = props[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        // EXIF orientations 5…8 are rotated a quarter turn: a portrait photo stored sideways.
        let rotated = (5...8).contains(props[kCGImagePropertyOrientation] as? Int ?? 1)
        let (width, height) = rotated ? (pixelHeight, pixelWidth) : (pixelWidth, pixelHeight)
        let megapixels = Double(width * height) / 1_000_000
        let model = (props[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFModel] as? String

        var lines = [
            "🖼️ Summary of “\(title)”",
            "• \(num(width)) × \(num(height)) px · \(String(format: "%.1f", megapixels)) MP · \(size(of: url))",
        ]
        if let model { lines.append("• Camera: \(model)") }

        var punchline = "Nice picture! I'd give it 7 fingers out of 10."
        if let (r, g, b) = averageColor(source) {
            let (name, brightness) = colorName(r, g, b)
            lines.append("• Average color: \(name)")
            if name.contains("teal") || name.contains("orange") {
                punchline = "Already teal and orange. My work here is done."
            } else if brightness < 0.3 {
                punchline = "Dark and moody. Very cinematic. Or the lens cap was on."
            } else if brightness > 0.85 {
                punchline = "Very bright. Did someone open a Word document?"
            }
        }
        if url.lastPathComponent.lowercased().hasPrefix("screenshot") {
            punchline = "A screenshot! Of what? Don't tell me, I'll hallucinate it."
        } else if let model, model.contains("iPhone") {
            punchline = "Shot on \(model). Not by me, I don't have hands."
        } else if megapixels > 30 {
            punchline = "\(Int(megapixels)) megapixels. Each one lovingly ignored by me."
        }
        lines.append(punchline)
        return lines.joined(separator: "\n")
    }

    private static func averageColor(_ source: CGImageSource) -> (CGFloat, CGFloat, CGFloat)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(thumb, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var r = 0, g = 0, b = 0, a = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            r += Int(pixels[i]); g += Int(pixels[i + 1]); b += Int(pixels[i + 2]); a += Int(pixels[i + 3])
        }
        guard a > 0 else { return nil }
        // Premultiplied, so dividing by total alpha gives the alpha-weighted average.
        return (CGFloat(r) / CGFloat(a), CGFloat(g) / CGFloat(a), CGFloat(b) / CGFloat(a))
    }

    private static func colorName(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (name: String, brightness: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: nil)
        if v < 0.15 { return ("basically black", v) }
        if s < 0.12 { return (v > 0.85 ? "white-ish" : v > 0.45 ? "grey" : "dark grey", v) }
        let base: String
        switch h * 360 {
        case ..<15: base = "red"
        case ..<40: base = "orange"
        case ..<65: base = "yellow"
        case ..<160: base = "green"
        case ..<200: base = "teal"
        case ..<255: base = "blue"
        case ..<290: base = "purple"
        case ..<335: base = "pink"
        default: base = "red"
        }
        let prefix = s < 0.35 && v < 0.5 ? "muddy " : v < 0.4 ? "dark " : s < 0.35 ? "dusty " : ""
        return (prefix + base, v)
    }

    // MARK: - Video & audio

    private static func summarizeMedia(_ url: URL, title: String) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.isNumeric, duration.seconds > 0 else { return nil }
        let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

        guard let video = videoTracks.first,
              let (naturalSize, transform, fps, formats) = try? await video.load(
                .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions) else {
            guard !audioTracks.isEmpty else { return nil }
            return [
                "🎵 Summary of “\(title)”",
                "• \(timecode(duration.seconds)) · \(size(of: url))",
                ["I'd listen, but I have no ears.", "Certified banger. Probably."].randomElement()!,
            ].joined(separator: "\n")
        }

        // Phone videos are often stored sideways, with a rotation to apply when playing.
        let shown = naturalSize.applying(transform)
        let width = Int(abs(shown.width)), height = Int(abs(shown.height))
        let codec = formats.first.map { codecName(CMFormatDescriptionGetMediaSubType($0)) } ?? "mystery codec"
        let rate = frameRate(fps)
        let audio = audioTracks.isEmpty ? " · no audio" : " · \(audioTracks.count) audio track\(audioTracks.count == 1 ? "" : "s")"
        var lines = [
            "🎬 Summary of “\(title)”",
            "• \(timecode(duration.seconds)) · \(size(of: url))",
            "• \(num(width)) × \(num(height))\(resolutionName(max(width, height))) · \(rate) fps",
            "• \(codec)\(audio)",
        ]

        let punchline: String
        if codec.hasPrefix("ProRes") {
            punchline = "ProRes! Fancy. Your disk is crying."
        } else if abs(fps - 24) < 0.1 {
            punchline = "\(rate) fps. Very cinematic. Want me to make it teal and orange?"
        } else if abs(fps - 25) < 0.1 {
            punchline = "25 fps. Ah, a PAL person. Respect."
        } else if abs(fps - 30) < 0.1 {
            punchline = "\(rate) fps. Strong TV news energy."
        } else if fps >= 48 {
            punchline = "High frame rate! Smooth. Like me."
        } else {
            punchline = "Great footage! Needs more lens flares."
        }
        lines.append(punchline)
        return lines.joined(separator: "\n")
    }

    private static func codecName(_ code: FourCharCode) -> String {
        let fourCC = String(bytes: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xff) }, encoding: .ascii) ?? "????"
        let known = [
            "avc1": "H.264", "hvc1": "HEVC", "hev1": "HEVC",
            "apco": "ProRes 422 Proxy", "apcs": "ProRes 422 LT", "apcn": "ProRes 422", "apch": "ProRes 422 HQ",
            "ap4h": "ProRes 4444", "ap4x": "ProRes 4444 XQ", "aprn": "ProRes RAW", "aprh": "ProRes RAW HQ",
            "jpeg": "Motion JPEG", "mp4v": "MPEG-4", "av01": "AV1", "vp09": "VP9",
        ]
        return known[fourCC] ?? "Codec “\(fourCC.trimmingCharacters(in: .whitespaces))”"
    }

    private static func frameRate(_ fps: Float) -> String {
        if abs(fps - 23.976) < 0.01 { return "23.976" }
        if abs(fps - 29.97) < 0.01 { return "29.97" }
        if abs(fps - 59.94) < 0.01 { return "59.94" }
        if abs(fps - fps.rounded()) < 0.01 { return "\(Int(fps.rounded()))" }
        return String(format: "%.2f", fps)
    }

    private static func resolutionName(_ longSide: Int) -> String {
        switch longSide {
        case 7600...: return " (8K)"
        case 5000...: return " (6K)"
        case 3800...: return " (4K)"
        case 1900...: return " (HD)"
        default: return ""
        }
    }

    private static func timecode(_ seconds: Double) -> String {
        if seconds < 10 { return String(format: "%.1f s", seconds) }
        let s = Int(seconds.rounded())
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Folders, other files, several files

    /// How many files and folders a folder summary looks at, at most, and how many items inside
    /// apps and other bundles it looks at to add up their sizes (apps are full of files).
    private static let scanLimit = 50_000
    private static let bundleScanLimit = 300_000

    private static func summarizeFolder(_ url: URL, title: String) -> String {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys,
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return summarizeOther(url, title: title)
        }
        var budget = scanLimit, bundleBudget = bundleScanLimit
        var files = 0, folders = 0, total: Int64 = 0
        var biggest: (name: String, size: Int64)?
        var extensions: [String: Int] = [:]
        var finals: [String] = []
        for case let item as URL in walker {
            budget -= 1
            if budget < 0 { break }
            let v = try? item.resourceValues(forKeys: Set(keys))
            let name = item.lastPathComponent
            let size: Int64
            if v?.isPackage == true {
                // Apps and other bundles count as one file, with everything inside.
                size = directorySize(item, budget: &bundleBudget)
            } else if v?.isDirectory == true {
                folders += 1
                continue
            } else if v?.isRegularFile == true {
                size = Int64(v?.fileSize ?? 0)
                if name.lowercased().range(of: #"(?<![a-z])final(?![a-z])"#, options: .regularExpression) != nil {
                    finals.append(name)
                }
            } else {
                continue
            }
            files += 1
            total += size
            if size > (biggest?.size ?? -1) { biggest = (name, size) }
            let ext = item.pathExtension.lowercased()
            extensions[ext.isEmpty ? "no extension" : "." + ext, default: 0] += 1
        }
        // "+" where it stopped counting.
        let moreItems = budget < 0 ? "+" : ""
        let moreBytes = budget < 0 || bundleBudget < 0 ? "+" : ""

        var lines = [
            "📁 Summary of “\(title)”",
            "• \(num(files))\(moreItems) files in \(num(folders))\(moreItems) folders · \(bytes(total))\(moreBytes)",
        ]
        let top = extensions.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(3)
        if !top.isEmpty { lines.append("• Mostly: " + top.map { "\($0.key) (\(num($0.value)))" }.joined(separator: ", ")) }
        if let biggest, files > 1 { lines.append("• Biggest: \(biggest.name.prefix(30)) (\(bytes(biggest.size)))") }

        if files == 0 {
            lines.append("It's empty. Minimalism. I respect it.")
        } else if let final = finals.first {
            lines.append("I see a file called “\(final.prefix(30))”. It's not final, is it?")
        } else if files > 1000 {
            lines.append("That's a lot of files. I summarized them as: “a lot of files”.")
        } else if let biggest, total > 0, biggest.size * 2 > total, files > 3 {
            lines.append("One file is hogging \(Int(Double(biggest.size) / Double(total) * 100))% of the space. Typical.")
        } else {
            lines.append(["Very organized! Want me to un-organize it?", "Folder vibes: tidy-ish."].randomElement()!)
        }
        return lines.joined(separator: "\n")
    }

    private static func summarizeOther(_ url: URL, title: String) -> String {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .contentModificationDateKey])
        let type = values?.contentType
        var lines = [
            "📦 Summary of “\(title)”",
            "• \(capitalized(type?.localizedDescription ?? "Mystery file")) · \(size(of: url))",
        ]
        if let modified = values?.contentModificationDate {
            lines.append("• Last changed \(RelativeDateTimeFormatter().localizedString(for: modified, relativeTo: Date()))")
        }
        let ext = url.pathExtension.lowercased()
        if ["mxf", "r3d", "ari", "arx", "braw", "crm", "mov", "mp4"].contains(ext) {
            lines.append("Professional footage! I can't open it, but I'm sure it's beautifully exposed.")
        } else if type?.conforms(to: .application) == true || type?.conforms(to: .applicationBundle) == true {
            lines.append("An app! I'm an app too. Are we related? 👀")
        } else if type?.conforms(to: .archive) == true {
            lines.append("A compressed file. I respect a file that keeps it together.")
        } else if type?.conforms(to: .diskImage) == true {
            lines.append("A disk image. Very 2009. I love it.")
        } else {
            lines.append(["I didn't open it. It looked scary.",
                          "No idea what this is, but I'm 100% confident about it."].randomElement()!)
        }
        return lines.joined(separator: "\n")
    }

    private static func summarizeMany(_ urls: [URL]) -> String {
        var counts: [String: Int] = [:]
        var total: Int64 = 0
        for url in urls {
            let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey, .isPackageKey, .fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
            let kind: String
            if values?.isPackage == true {
                kind = values?.contentType?.conforms(to: .applicationBundle) == true ? "app" : "bundle"
            } else if values?.isDirectory == true {
                kind = "folder"
            } else if let t = values?.contentType {
                if t.conforms(to: .image) { kind = "image" }
                else if t.conforms(to: .audiovisualContent) { kind = "video/audio file" }
                else if t.conforms(to: .pdf) { kind = "PDF" }
                else if t.conforms(to: .sourceCode) || t.conforms(to: .script) { kind = "code file" }
                else if t.conforms(to: .text) { kind = "text file" }
                else { kind = "mystery file" }
            } else {
                kind = "mystery file"
            }
            counts[kind, default: 0] += 1
        }
        let breakdown = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { "\($0.value) \($0.key)\($0.value == 1 ? "" : "s")" }
            .joined(separator: ", ")
        return [
            "🗂️ Summary of \(urls.count) things",
            "• \(breakdown)",
            "• \(bytes(total)) of files (not counting folders)",
            "Summary: you gave me homework. I'll get to it. (I won't.)",
        ].joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Up to 5 MB of text (UTF-8, or UTF-16 with a byte order mark). nil for binary files.
    private static func readText(_ url: URL, limit: Int = 5_000_000) -> (String, truncated: Bool)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: limit + 1) else { return ("", false) }
        let slice = data.prefix(limit)
        let truncated = data.count > limit
        // UTF-16 is full of zero bytes, so it has to be recognized before the binary check.
        if slice.starts(with: [0xFF, 0xFE]) || slice.starts(with: [0xFE, 0xFF]) {
            return String(data: slice.count % 2 == 0 ? slice : slice.dropLast(), encoding: .utf16).map { ($0, truncated) }
        }
        if slice.prefix(8000).contains(0) { return nil }
        let text = String(data: slice, encoding: .utf8) ?? String(decoding: slice, as: UTF8.self)
        return (text, truncated)
    }

    private static let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "they", "will", "would", "there", "their", "what", "about",
        "which", "when", "your", "were", "been", "than", "them", "then", "into", "some", "could", "other",
        "more", "also", "just", "only", "like", "over", "such", "these", "those", "here", "should", "because",
        "does", "each", "very", "much", "most", "where", "while", "being", "after", "before", "said", "make",
        "dass", "nicht", "sind", "eine", "einer", "einen", "auch", "oder", "wird", "werden", "wurde", "haben",
        "sich", "aber", "noch", "wenn", "dann", "diese", "dieser", "kann", "sein", "nach", "über", "beim",
        "durch", "sehr", "für", "ist", "und", "der", "die", "das", "den", "dem", "des", "mit", "von",
    ]

    private struct WordStats {
        var count: Int
        var mostUsed: String?
    }

    private static func wordStats(_ text: String) -> WordStats {
        var count = 0
        var frequency: [String: Int] = [:]
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { word, _, _, _ in
            guard let word else { return }
            count += 1
            let w = word.lowercased()
            if w.count >= 4, !stopWords.contains(w), w.allSatisfy(\.isLetter) {
                frequency[w, default: 0] += 1
            }
        }
        // Ties go to the alphabetically first word, so the answer doesn't change between runs.
        let top = frequency.max { ($0.value, $1.key) < ($1.value, $0.key) }
        return WordStats(count: count, mostUsed: (top?.value ?? 0) >= 2 ? top?.key : nil)
    }

    private static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(5000)))
        guard let code = recognizer.dominantLanguage?.rawValue else { return nil }
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code)
    }

    /// Apple's on-device sentiment score (-1…1), averaged over paragraphs.
    private static func mood(of text: String) -> String? {
        let sample = String(text.prefix(20_000))
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = sample
        var total = 0.0, paragraphs = 0
        tagger.enumerateTags(in: sample.startIndex..<sample.endIndex, unit: .paragraph,
                             scheme: .sentimentScore, options: [.omitWhitespace]) { tag, range in
            // Headings and one-liners carry no mood; let real paragraphs decide.
            if sample.distance(from: range.lowerBound, to: range.upperBound) >= 40,
               let value = tag.flatMap({ Double($0.rawValue) }) {
                total += value
                paragraphs += 1
            }
            return true
        }
        guard paragraphs > 0 else { return nil }
        switch total / Double(paragraphs) {
        case 0.5...: return "radiant ☀️"
        case 0.15...: return "pleasant 🙂"
        case (-0.15)...: return "neutral, like a beige wall"
        case (-0.5)...: return "a bit gloomy 🌧️"
        default: return "deeply dramatic 🎭"
        }
    }

    /// File size, or the total of everything inside for packages like apps.
    private static func size(of url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        guard values?.isDirectory == true else { return bytes(Int64(values?.fileSize ?? 0)) }
        var budget = bundleScanLimit
        let total = directorySize(url, budget: &budget)
        return bytes(total) + (budget < 0 ? "+" : "")
    }

    /// The total size of all files inside `url`. Each item looked at uses up one of `budget`.
    private static func directorySize(_ url: URL, budget: inout Int) -> Int64 {
        var total: Int64 = 0
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        while budget >= 0, let item = walker.nextObject() as? URL {
            budget -= 1
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    private static func capitalized(_ s: String) -> String {
        s.prefix(1).uppercased() + s.dropFirst()
    }

    private static func num(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }

    private static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}

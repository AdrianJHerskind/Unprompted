extension String {
    /// Whether `word` occurs with no letters directly before or after it, so "fun" is found in
    /// "make it fun!" but not in "function", and "craft" in "Craft" but not in "Minecraft".
    func containsWord(_ word: String) -> Bool {
        var searchStart = startIndex
        while let r = range(of: word, range: searchStart..<endIndex) {
            let letterBefore = r.lowerBound > startIndex && self[index(before: r.lowerBound)].isLetter
            let letterAfter = r.upperBound < endIndex && self[r.upperBound].isLetter
            if !letterBefore && !letterAfter { return true }
            searchStart = index(after: r.lowerBound)
        }
        return false
    }
}

import Foundation

/// A small, safe recursive-descent calculator: + − × ÷ ^ %, parentheses and sqrt.
/// (NSExpression would crash the app on malformed input.)
///
///     expression := term (("+" | "-") term)*
///     term       := unary (("*" | "/") unary)*
///     unary      := "-" unary | power
///     power      := postfix ("^" unary)?        right-associative, binds tighter than unary minus
///     postfix    := primary "%"*
///     primary    := number | "(" expression ")" | "sqrt" primary
struct MathParser {
    private let chars: [Character]
    private var i = 0

    init(_ expression: String) {
        chars = Array(expression.replacingOccurrences(of: " ", with: ""))
    }

    /// nil when the input isn't a complete, valid expression.
    mutating func parse() -> Double? {
        // Plenty for real calculations, and keeps the recursion (nesting depth) far from
        // overflowing the stack on pasted junk like "-----…1".
        guard chars.count <= 1000, let value = expression(), i == chars.count else { return nil }
        return value
    }

    private mutating func expression() -> Double? {
        guard var value = term() else { return nil }
        while i < chars.count, chars[i] == "+" || chars[i] == "-" {
            let op = chars[i]
            i += 1
            guard let rhs = term() else { return nil }
            value = op == "+" ? value + rhs : value - rhs
        }
        return value
    }

    private mutating func term() -> Double? {
        guard var value = unary() else { return nil }
        while i < chars.count, chars[i] == "*" || chars[i] == "/" {
            let op = chars[i]
            i += 1
            guard let rhs = unary() else { return nil }
            value = op == "*" ? value * rhs : value / rhs
        }
        return value
    }

    private mutating func unary() -> Double? {
        if i < chars.count, chars[i] == "-" {
            i += 1
            return unary().map { -$0 }
        }
        return power()
    }

    private mutating func power() -> Double? {
        guard let base = postfix() else { return nil }
        if i < chars.count, chars[i] == "^" {
            i += 1
            guard let exponent = unary() else { return nil }
            return pow(base, exponent)
        }
        return base
    }

    private mutating func postfix() -> Double? {
        guard var value = primary() else { return nil }
        while i < chars.count, chars[i] == "%" {
            i += 1
            value /= 100
        }
        return value
    }

    private mutating func primary() -> Double? {
        guard i < chars.count else { return nil }
        if chars[i] == "(" {
            i += 1
            guard let value = expression(), i < chars.count, chars[i] == ")" else { return nil }
            i += 1
            return value
        }
        if chars[i...].starts(with: "sqrt") {
            i += 4
            return primary().map { $0.squareRoot() }
        }
        let start = i
        while i < chars.count, chars[i].isNumber || chars[i] == "." { i += 1 }
        return i > start ? Double(String(chars[start..<i])) : nil
    }
}

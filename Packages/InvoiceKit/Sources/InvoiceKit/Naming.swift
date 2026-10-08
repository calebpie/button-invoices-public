import Foundation

/// The standard way a button is written on an invoice (SPEC.md, "Names"):
/// "Design, Color / Color, Size", e.g. "Daisy, Black / White, Large". Size is left out
/// when the button comes in one size: "Nautilus, Black".
public enum Naming {
    /// Sizes in the order the app offers them. Any other text she types is kept as written.
    public static let sizes = ["Mini", "Small", "Medium", "Large", "Extra Large"]

    /// "  ladybugs " → "Ladybug", "cowrie shells" → "Cowrie Shell", "lips" → "Lips".
    public static func cleanDesign(_ raw: String) -> String {
        var words = splitWords(raw)
        guard let last = words.popLast() else { return "" }
        words.append(singular(last))
        return words.map(capitalized).joined(separator: " ")
    }

    /// "black/white", "black and white", "Black & white" → ["Black", "White"].
    /// A two-word color such as "pale pink" stays one color.
    public static func cleanColors(_ raw: String) -> [String] {
        raw.replacingOccurrences(of: #"\s*(/|,|&|\+|\band\b|\bwith\b)\s*"#, with: "|",
                                 options: [.regularExpression, .caseInsensitive])
            .split(separator: "|")
            .map { cleanColor(String($0)) }
            .filter { !$0.isEmpty }
    }

    /// "  pale   PINK " → "Pale Pink".
    public static func cleanColor(_ raw: String) -> String {
        splitWords(raw).map(capitalized).joined(separator: " ")
    }

    /// "lg" → "Large", "" or "none" → "" (one size), anything unknown is title-cased.
    public static func cleanSize(_ raw: String) -> String {
        let key = splitWords(raw).joined(separator: " ").lowercased()
        switch key {
        case "", "none", "regular", "standard", "one size": return ""
        case "mini", "tiny": return "Mini"
        case "small", "sm", "s": return "Small"
        case "medium", "med", "m": return "Medium"
        case "large", "lg", "l", "big": return "Large"
        case "extra large", "xl", "x large", "x-large": return "Extra Large"
        default: return splitWords(raw).map(capitalized).joined(separator: " ")
        }
    }

    /// "Daisy", ["Black", "White"], "Large" → "Daisy, Black / White, Large".
    public static func description(design: String, colors: [String], size: String) -> String {
        var parts = [design]
        if !colors.isEmpty { parts.append(colors.joined(separator: " / ")) }
        if !size.isEmpty { parts.append(size) }
        return parts.joined(separator: ", ")
    }

    /// The reverse of `description`, for the names in the Excel template.
    /// "Star, Navy, Mini" → ("Star", ["Navy"], "Mini").
    public static func parse(description: String) -> (design: String, colors: [String], size: String) {
        let parts = description.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let design = parts.first else { return ("", [], "") }
        var rest = Array(parts.dropFirst())
        var size = ""
        if let last = rest.last, rest.count >= 2 || sizes.contains(last) {
            size = last
            rest.removeLast()
        }
        let colors = rest.flatMap { $0.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { !$0.isEmpty }
        return (design, colors, size)
    }

    /// Plural nouns she may type, made singular: "hearts" → "heart", "daisies" → "daisy",
    /// "peaches" → "peach". Words that end in "s" in the singular are left alone.
    public static func singular(_ word: String) -> String {
        let lower = word.lowercased()
        if pluralsToKeep.contains(lower) || lower.count <= 3 { return word }
        if lower.hasSuffix("ies") { return String(word.dropLast(3)) + (word.last!.isUppercase ? "Y" : "y") }
        for ending in ["sses", "shes", "ches", "xes", "zes"] where lower.hasSuffix(ending) {
            return String(word.dropLast(2))
        }
        if lower.hasSuffix("s") && !lower.hasSuffix("ss") && !lower.hasSuffix("us") && !lower.hasSuffix("is") {
            return String(word.dropLast())
        }
        return word
    }

    /// Words that end in "s" but name one thing.
    static let pluralsToKeep: Set<String> = [
        "lips", "glasses", "scissors", "pants", "shorts", "jeans", "overalls", "series", "species",
        "news", "bus", "gas", "plus", "yes", "this", "his", "hers", "its",
    ]

    public static func splitWords(_ s: String) -> [String] {
        s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    /// "pALE" → "Pale". Keeps the accent in "daphné". Hyphenated words get each part capitalized.
    static func capitalized(_ word: String) -> String {
        word.split(separator: "-", omittingEmptySubsequences: false)
            .map { part in part.prefix(1).uppercased() + part.dropFirst().lowercased() }
            .joined(separator: "-")
    }
}

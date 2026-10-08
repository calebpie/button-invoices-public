import Foundation

/// A saved button as the search sees it.
public struct MatchCandidate: Sendable, Hashable, Identifiable {
    public var id: String
    public var design: String
    public var colors: [String]
    public var size: String
    public var sku: String
    /// Words she has used for this button before ("olive" for Nautilus, Green).
    public var aliases: [String]

    public init(id: String, design: String, colors: [String], size: String, sku: String, aliases: [String] = []) {
        self.id = id
        self.design = design
        self.colors = colors
        self.size = size
        self.sku = sku
        self.aliases = aliases
    }
}

/// One line as she writes it in a message: "12 ladybugs @ $8 = $96".
public struct OrderRequest: Hashable, Sendable {
    public var quantity: Int?
    public var unitPrice: Money?
    /// What's left to search with: "ladybugs".
    public var query: String

    public init(quantity: Int? = nil, unitPrice: Money? = nil, query: String = "") {
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.query = query
    }

    public static let empty = OrderRequest()
}

/// Finds saved buttons from the words she uses (SPEC.md, "Finding a button"). She writes
/// "black nautilus", "blush nautilus", "navy blue mushrooms", "Off White Dogwoods", so the
/// search ignores plurals and case, knows a few color words she uses, learns new ones as
/// aliases, and ranks rather than filters: she picks from photos.
public enum Matcher {
    /// "12 ladybugs @ $8 = $96" → quantity 12, price $8.00, query "ladybugs".
    public static func parse(_ text: String) -> OrderRequest {
        var s = " " + text + " "
        var quantity: Int?
        var price: Money?
        // A trailing total ("= $96") is her arithmetic; the app does its own.
        s = s.replacingOccurrences(of: #"=\s*\$?\s*[\d,]+(\.\d+)?"#, with: " ", options: .regularExpression)
        if let r = s.range(of: #"(@|\bat\b)?\s*\$\s*[\d,]+(\.\d{1,2})?|@\s*[\d,]+(\.\d{1,2})?"#,
                           options: [.regularExpression, .caseInsensitive]) {
            price = Money(parsing: String(s[r]).replacingOccurrences(of: "@", with: "")
                .replacingOccurrences(of: "at", with: "", options: .caseInsensitive))
            s.replaceSubrange(r, with: " ")
        }
        if let r = s.range(of: #"^\s*[\d,]+\s*(x|×)?\s"#, options: [.regularExpression, .caseInsensitive]) {
            quantity = Int(s[r].filter(\.isNumber))
            s.replaceSubrange(r, with: " ")
        }
        s = s.replacingOccurrences(of: #"\b(each|ea|per|buttons?)\b"#, with: " ",
                                   options: [.regularExpression, .caseInsensitive])
        let query = Naming.splitWords(s).joined(separator: " ")
        return OrderRequest(quantity: quantity, unitPrice: price, query: query)
    }

    public struct Scored: Sendable {
        public var candidate: MatchCandidate
        public var score: Int
    }

    /// Candidates that match any word, best first. An empty query returns everything by name.
    public static func rank(_ query: String, among candidates: [MatchCandidate]) -> [Scored] {
        let words = tokens(query)
        let byName: (Scored, Scored) -> Bool = {
            if $0.score != $1.score { return $0.score > $1.score }
            return displayOrder($0.candidate) < displayOrder($1.candidate)
        }
        guard !words.isEmpty else {
            return candidates.map { Scored(candidate: $0, score: 0) }.sorted(by: byName)
        }
        return candidates.compactMap { c -> Scored? in
            let s = score(words, c)
            return s > 0 ? Scored(candidate: c, score: s) : nil
        }.sorted(by: byName)
    }

    /// Words from her search that the chosen button doesn't already answer to, worth
    /// remembering: picking Nautilus, Green after typing "olive nautilus" returns ["olive"].
    public static func newAliases(from query: String, chosen: MatchCandidate) -> [String] {
        let known = Set(tokens(chosen.design) + tokens(chosen.colors.joined(separator: " "))
                        + tokens(chosen.size) + chosen.aliases.flatMap(tokens) + [chosen.sku.lowercased()])
        var seen = Set<String>()
        return rawWords(parse(query).query).filter { word in
            let t = tokens(word)
            return word.count >= 3 && !t.isEmpty && t.allSatisfy { !known.contains($0) }
                && !stopWords.contains(word) && seen.insert(word).inserted
        }
    }

    // MARK: - Scoring

    static func score(_ words: [String], _ c: MatchCandidate) -> Int {
        let design = Set(tokens(c.design))
        let colors = Set(tokens(c.colors.joined(separator: " ")))
        let size = Set(tokens(c.size))
        let aliases = Set(c.aliases.flatMap(tokens))
        if words.contains(c.sku.lowercased()) { return 1000 }
        var total = 0
        var matchedDesign = Set<String>()
        var matchedColors = Set<String>()
        var anyHit = false
        for w in words {
            if design.contains(w) { total += 10; matchedDesign.insert(w); anyHit = true }
            else if colors.contains(w) { total += 6; matchedColors.insert(w); anyHit = true }
            else if aliases.contains(w) { total += 7; anyHit = true }
            else if size.contains(w) { total += 4; anyHit = true }
            else if let near = closeMatch(w, in: design) { total += 7; matchedDesign.insert(near); anyHit = true }
            else if w.count >= 2, (design.union(colors).union(aliases)).contains(where: { $0.hasPrefix(w) }) {
                total += 3; anyHit = true // still typing
            }
            else { total -= 2 }
        }
        guard anyHit else { return 0 }
        if !design.isEmpty && matchedDesign == design { total += 4 }
        total -= colors.subtracting(matchedColors).count // "red heart" prefers plain red to red / white
        if !size.isEmpty && size.isDisjoint(with: words) { total -= 1 } // and the one-size button to a large one
        return max(total, 1)
    }

    /// A design word within one typo of what she typed ("pineaple", "elipse").
    static func closeMatch(_ word: String, in set: Set<String>) -> String? {
        guard word.count >= 5 else { return nil }
        return set.first { abs($0.count - word.count) <= 1 && editDistance($0, word) <= 1 }
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 1...max(a.count, 1) where i <= a.count {
            var prev = row[0]
            row[0] = i
            for j in 1...max(b.count, 1) where j <= b.count {
                let cur = row[j]
                row[j] = a[i - 1] == b[j - 1] ? prev : 1 + min(prev, row[j], row[j - 1])
                prev = cur
            }
        }
        return row[b.count]
    }

    // MARK: - Words

    /// Lowercased, accents and plurals removed, her color words mapped to the catalog's.
    static func tokens(_ text: String) -> [String] {
        var s = " " + text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) + " "
        s = s.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        for (phrase, replacement) in phraseSynonyms {
            s = s.replacingOccurrences(of: " \(phrase) ", with: " \(replacement) ")
        }
        return Naming.splitWords(s).flatMap { word -> [String] in
            let single = Naming.singular(word).lowercased()
            return (wordSynonyms[single] ?? single).split(separator: " ").map(String.init)
        }
    }

    static func rawWords(_ text: String) -> [String] {
        Naming.splitWords(text.lowercased().replacingOccurrences(of: #"[^\p{L}0-9]+"#, with: " ",
                                                                options: .regularExpression))
    }

    static func displayOrder(_ c: MatchCandidate) -> String {
        Naming.description(design: c.design, colors: c.colors, size: c.size).lowercased()
    }

    /// Color words from her messages (2026) mapped to the names on the invoices.
    static let phraseSynonyms: [(String, String)] = [
        ("navy blue", "navy"), ("off white", "ivory"), ("light pink", "pale pink"),
        ("cowry shell", "cowrie shell"),
    ]
    static let wordSynonyms: [String: String] = [
        "blush": "pale pink", "olive": "green", "offwhite": "ivory", "celedon": "celadon",
        "gray": "grey", "maroon": "burgundy", "elipse": "ellipse", "pineaple": "pineapple",
    ]
    static let stopWords: Set<String> = ["the", "and", "with", "button", "buttons", "each", "for"]
}

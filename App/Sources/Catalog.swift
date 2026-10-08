import Foundation
import InvoiceKit
import SwiftData

/// Catalog lookups shared by the screens.
enum Catalog {
    static func allVariants(_ context: ModelContext) -> [ButtonVariant] {
        (try? context.fetch(FetchDescriptor<ButtonVariant>())) ?? []
    }

    static func allDesigns(_ context: ModelContext) -> [ButtonDesign] {
        let sort = SortDescriptor(\ButtonDesign.name, comparator: .localizedStandard)
        return (try? context.fetch(FetchDescriptor<ButtonDesign>(sortBy: [sort]))) ?? []
    }

    /// The standard SKU codes plus any learned from SKUs she has saved.
    static func skuRules(_ variants: [ButtonVariant]) -> SKURules {
        SKURules.standard.learning(from: variants.map(\.skuEntry))
    }

    /// Every color used so far, most used first, for suggestion chips.
    static func knownColors(_ variants: [ButtonVariant]) -> [String] {
        var counts: [String: Int] = [:]
        for v in variants { for c in v.colors { counts[c, default: 0] += 1 } }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    static var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    /// Buttons ranked against what she typed. Archived ones only in the Buttons tab.
    static func search(_ query: String, in variants: [ButtonVariant], includeArchived: Bool = false) -> [ButtonVariant] {
        let pool = includeArchived ? variants : variants.filter { !$0.isHidden }
        let byID = Dictionary(pool.map { ($0.matchCandidate.id, $0) }, uniquingKeysWith: { a, _ in a })
        var ranked = Matcher.rank(query, among: pool.map(\.matchCandidate)).compactMap { byID[$0.candidate.id] }
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Recently invoiced first, then by name.
            ranked.sort { a, b in
                switch (a.lastUsedAt, b.lastUsedAt) {
                case let (x?, y?): return x > y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.title.localizedStandardCompare(b.title) == .orderedAscending
                }
            }
        }
        return ranked
    }

    /// Splits an unmatched search ("12 green ladybugs") into a guess for a new button:
    /// an existing design if a word names one, sizes by name, the rest as colors.
    static func guessNewButton(from query: String, designs: [ButtonDesign]) -> (design: ButtonDesign?, designName: String, colors: String, size: String) {
        let words = Naming.splitWords(Matcher.parse(query).query)
        var rest: [String] = []
        var design: ButtonDesign?
        var size = ""
        for word in words {
            let singular = Naming.singular(word).lowercased()
            if design == nil, let d = designs.first(where: { $0.name.lowercased() == singular || $0.name.lowercased() == word.lowercased() }) {
                design = d
            } else if Naming.sizes.map({ $0.lowercased() }).contains(word.lowercased()) {
                size = Naming.cleanSize(word)
            } else {
                rest.append(word)
            }
        }
        if design != nil {
            return (design, design!.name, rest.joined(separator: " "), size)
        }
        let name = rest.popLast() ?? ""
        return (nil, Naming.cleanDesign(name), rest.joined(separator: " "), size)
    }
}

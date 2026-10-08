import Testing
@testable import InvoiceKit

@Suite struct SKUTests {
    /// SKUs that don't follow the rules. Crab, Shell and Ladybug were corrected in the seed
    /// (Tools/seed/extract_seed.py); this one is on a sent invoice (0260812), so it stays.
    static let irregular: Set<String> = [
        "Pineapple, Yellow / Brown", // 26PYB: Brown is BR everywhere else (26PYBR expected)
    ]

    @Test func reproducesTheTemplate() throws {
        let rules = SKURules.standard
        for v in try Repo.catalog().variants {
            let suggested = rules.suggestSKU(year: 2026, designName: v.design, designCode: SKURules.designCode(for: v.design),
                                             colors: v.colors, size: v.size, taken: [])
            if Self.irregular.contains(Naming.description(design: v.design, colors: v.colors, size: v.size)) {
                #expect(suggested != v.sku)
            } else {
                #expect(suggested == v.sku, "\(v.design) \(v.colors) \(v.size)")
            }
        }
    }

    @Test func newColorsGetInitialsOrMoreLetters() {
        let rules = SKURules.standard
        #expect(rules.colorCode(for: "Olive") == "O")
        #expect(rules.colorCode(for: "Sky Blue") == "SB")
        #expect(rules.colorCode(for: "Bronze") == "BRO") // B is Black, BR is Brown
        #expect(rules.colorCode(for: "Pink") == "P")
    }

    @Test func avoidsTakenSKUs() {
        let rules = SKURules.standard
        // A black / white star would collide with the sailboat.
        #expect(rules.suggestSKU(year: 2026, designName: "Star", designCode: "S", colors: ["Black", "White"],
                                 size: "", taken: ["26SBW"]) == "26STBW")
        #expect(rules.suggestSKU(year: 2026, designName: "S", designCode: "S", colors: ["Black"],
                                 size: "", taken: ["26SB"]) == "26SB2")
        #expect(rules.suggestSKU(year: 2027, designName: "Nautilus", designCode: "N", colors: ["Black"],
                                 size: "Small", taken: ["26NB"]) == "27NBS")
    }

    @Test func learnsCodesFromSavedSKUs() {
        let saved = [
            SKUEntry(sku: "26NO", designCode: "N", colors: ["Olive"], size: ""),          // O
            SKUEntry(sku: "26DTQW", designCode: "D", colors: ["Teal", "White"], size: ""), // TQ for Teal
            SKUEntry(sku: "zzz", designCode: "N", colors: ["Gold"], size: ""),             // hand-typed, ignored
        ]
        let rules = SKURules.standard.learning(from: saved)
        #expect(rules.colorCode(for: "olive") == "O")
        #expect(rules.colorCode(for: "Teal") == "TQ")
        #expect(rules.colorCodes["gold"] == nil)
        // Learned codes are then avoided by new colors.
        #expect(rules.colorCode(for: "Orange") == "OR")
    }
}

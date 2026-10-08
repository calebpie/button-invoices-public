import Testing
@testable import InvoiceKit

@Suite struct MatcherTests {
    static func candidates() throws -> [MatchCandidate] {
        try Repo.catalog().variants.enumerated().map { i, v in
            MatchCandidate(id: "\(i)", design: v.design, colors: v.colors, size: v.size, sku: v.sku)
        }
    }

    @Test func parsesHerLines() {
        #expect(Matcher.parse("12 ladybugs @ $8 = $96") == OrderRequest(quantity: 12, unitPrice: Money(cents: 800), query: "ladybugs"))
        #expect(Matcher.parse("410 red hearts @ $4.00 each") == OrderRequest(quantity: 410, unitPrice: Money(cents: 400), query: "red hearts"))
        #expect(Matcher.parse("315 Off White Dogwoods @ $8") == OrderRequest(quantity: 315, unitPrice: Money(cents: 800), query: "Off White Dogwoods"))
        #expect(Matcher.parse("navy mushroom") == OrderRequest(quantity: nil, unitPrice: nil, query: "navy mushroom"))
        #expect(Matcher.parse("1,000 hearts") == OrderRequest(quantity: 1000, unitPrice: nil, query: "hearts"))
        #expect(Matcher.parse("12") == OrderRequest(quantity: 12, unitPrice: nil, query: ""))
    }

    /// Lines from her iMessages (Examples/Input Request Screenshots) and the SKU Caleb invoiced.
    @Test(arguments: [
        ("12 ladybugs @ $8 = $96", "26LRW"), ("20 pineapples @ $9 = $180", "26PYB"), ("20 roses @ $8 = $160", "26RWG"),
        ("12 red hearts @ $4= $48", "26HRM"), ("12 navy hearts @ $4 = $48", "26HNM"), ("14 blush nautilus @ $9 = $126", "26NPP"),
        ("2 black nautilus @ $9= $18", "26NB"), ("7 white nautilus @ $9 = $63", "26NW"), ("13 strawberries @ $8 = $104", "26SRG"),
        ("13 sailboats @ $9 = $117", "26SBW"), ("125 burgundy mushrooms @ $8.00 each = $1000", "26MBW"),
        ("410 red hearts @ $4.00 each", "26HRM"), ("222 brown nautilus @ $9 each", "26NBR"), ("97 Olive nautilus @ $9 each", "26NG"),
        ("315 Off White Dogwoods @ $8", "26DI"), ("14 black nautilus @ $9 = $126", "26NB"), ("500 navy blue mushrooms @ $8 = $4000", "26MNW"),
        ("26DBWL", "26DBWL"), ("large black white daisy", "26DBWL"), ("pale pink cowrie", "26CSPP"), ("elipse", "26ELM"),
        ("pineapple", "26PYB"), ("celadon dogwood", "26DC"),
    ])
    func findsTheButton(_ line: String, _ sku: String) throws {
        let ranked = Matcher.rank(Matcher.parse(line).query, among: try Self.candidates())
        #expect(ranked.first?.candidate.sku == sku, "\(line) → \(ranked.prefix(3).map { "\($0.candidate.sku) \($0.score)" })")
    }

    @Test func emptySearchListsEverything() throws {
        let all = try Self.candidates()
        #expect(Matcher.rank("", among: all).count == all.count)
        #expect(Matcher.rank("zebra", among: all).isEmpty)
    }

    @Test func partialWordsMatchWhileTyping() throws {
        let ranked = Matcher.rank("mush", among: try Self.candidates())
        #expect(!ranked.isEmpty && ranked.allSatisfy { $0.candidate.design == "Mushroom" })
    }

    /// Docs/ui-nits.md, nit 5: "h" found nothing.
    @Test func oneLetterMatchesDesignNames() throws {
        let all = try Self.candidates()
        let h = Matcher.rank("h", among: all).map(\.candidate.design)
        #expect(h.count == 3 && h.allSatisfy { $0 == "Heart" })
        // Star, Shell, Sailboat, Strawberry; not Cowrie Shell, whose name starts with C.
        let s = Set(Matcher.rank("S", among: all).map(\.candidate.design))
        #expect(s == ["Star", "Shell", "Sailboat", "Strawberry"])
        #expect(Matcher.rank("s", among: all).count == 5)
        #expect(Matcher.rank("b", among: all).map(\.candidate.design) == ["Bunny"]) // not black, blue, burgundy
        #expect(Matcher.rank("z", among: all).isEmpty)
        // In a longer search a lone letter is still ignored.
        #expect(Matcher.rank("red h", among: all).map(\.candidate.design) == Matcher.rank("red", among: all).map(\.candidate.design))
    }

    @Test func learnsNewWords() throws {
        let green = try Self.candidates().first { $0.sku == "26NG" }!
        #expect(Matcher.newAliases(from: "97 olive nautilus @ $9", chosen: green) == []) // olive is already known
        #expect(Matcher.newAliases(from: "khaki nautilus", chosen: green) == ["khaki"])
        var taught = green
        taught.aliases = ["khaki"]
        let ranked = Matcher.rank("khaki nautilus", among: try Self.candidates().filter { $0.sku != "26NG" } + [taught])
        #expect(ranked.first?.candidate.sku == "26NG")
    }
}

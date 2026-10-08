import Testing
@testable import InvoiceKit

@Suite struct MoneyTests {
    @Test(arguments: [("9", 900), ("$9", 900), ("8.5", 850), ("$1,234.56", 123456), (" 16.21 ", 1621),
                      ("0.005", 1), ("$ 36.48", 3648), ("-4", -400)])
    func parses(_ text: String, _ cents: Int) {
        #expect(Money(parsing: text) == Money(cents: cents))
    }

    @Test(arguments: ["", "abc", "1.2.3", "$", "12a"])
    func rejects(_ text: String) {
        #expect(Money(parsing: text) == nil)
    }

    @Test func formats() {
        #expect(Money(cents: 417869).formatted == "$4,178.69")
        #expect(Money(cents: 900).formatted == "$9.00")
        #expect(Money(cents: 5).formatted == "$0.05")
        #expect(Money(cents: 100000000).digits == "1,000,000.00")
        #expect(Money(cents: -400).formatted == "-$4.00")
        #expect(Money(cents: 900).editingText == "9")
        #expect(Money(cents: 850).editingText == "8.50")
        #expect(Money(cents: 123456).editingText == "1234.56")
    }

    @Test func takesPercentages() {
        #expect(Money(cents: 800).percent(50) == Money(cents: 400))
        #expect(Money(cents: 900).percent(10) == Money(cents: 90))
        #expect(Money(cents: 550).percent(15) == Money(cents: 83)) // 82.5 rounds up
        #expect(Money(cents: 800).percent(0) == .zero)
    }

    @Test func sumsExactly() {
        // Excel stored 36.48 as 36.479999999999997.
        #expect(Money(cents: 3648) + Money(cents: 1621) == Money(cents: 5269))
    }
}

@Suite struct NamingTests {
    @Test(arguments: [("ladybugs", "Ladybug"), ("  cowrie   shells ", "Cowrie Shell"), ("strawberries", "Strawberry"),
                      ("DAISIES", "Daisy"), ("nautilus", "Nautilus"), ("lips", "Lips"), ("Dogwoods", "Dogwood"),
                      ("peaches", "Peach"), ("flower bursts", "Flower Burst"), ("glass", "Glass"), ("heart", "Heart")])
    func cleansDesign(_ raw: String, _ clean: String) {
        #expect(Naming.cleanDesign(raw) == clean)
    }

    @Test func cleansColors() {
        #expect(Naming.cleanColors("black/white") == ["Black", "White"])
        #expect(Naming.cleanColors("Black and white") == ["Black", "White"])
        #expect(Naming.cleanColors("pale PINK") == ["Pale Pink"])
        #expect(Naming.cleanColors("navy & white") == ["Navy", "White"])
        #expect(Naming.cleanColors(" red , green ") == ["Red", "Green"])
        #expect(Naming.cleanColors("") == [])
    }

    @Test func cleansSize() {
        #expect(Naming.cleanSize("lg") == "Large")
        #expect(Naming.cleanSize("") == "")
        #expect(Naming.cleanSize("mini") == "Mini")
        #expect(Naming.cleanSize("jumbo") == "Jumbo")
    }

    @Test func writesAndReadsDescriptions() {
        #expect(Naming.description(design: "Daisy", colors: ["Black", "White"], size: "Large") == "Daisy, Black / White, Large")
        #expect(Naming.description(design: "Nautilus", colors: ["Black"], size: "") == "Nautilus, Black")
        let parsed = Naming.parse(description: "Star, Navy, Mini")
        #expect(parsed.design == "Star" && parsed.colors == ["Navy"] && parsed.size == "Mini")
        let two = Naming.parse(description: "Mushroom, Navy / White")
        #expect(two.design == "Mushroom" && two.colors == ["Navy", "White"] && two.size == "")
    }

    /// Every name in the template survives a round trip through the app's format.
    @Test func seedNamesRoundTrip() throws {
        for v in try Repo.catalog().variants {
            let text = Naming.description(design: v.design, colors: v.colors, size: v.size)
            let back = Naming.parse(description: text)
            #expect(back.design == v.design && back.colors == v.colors && back.size == v.size, "\(text)")
        }
    }
}

@Suite struct InvoiceNumberTests {
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func usesTheDate() {
        #expect(InvoiceNumber.next(for: date(2026, 9, 3), existing: []) == "0260903")
        #expect(InvoiceNumber.next(for: date(2027, 1, 5), existing: ["0260903"]) == "0270105")
    }

    @Test func numbersSameDayInvoices() {
        #expect(InvoiceNumber.next(for: date(2026, 9, 3), existing: ["0260903"]) == "0260903-2")
        #expect(InvoiceNumber.next(for: date(2026, 9, 3), existing: ["0260903", "0260903-2"]) == "0260903-3")
        // April's batch was numbered -1 to -5 from the start.
        let april = (1...5).map { "0260426-\($0)" }
        #expect(InvoiceNumber.next(for: date(2026, 4, 26), existing: april) == "0260426-6")
    }
}

import Foundation

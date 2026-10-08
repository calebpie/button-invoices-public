import Foundation

/// A US dollar amount held as whole cents, so sums are exact ($36.48 + $16.21 is $52.69,
/// never $52.690000000000005 as in the Excel files).
public struct Money: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public var cents: Int

    public init(cents: Int) { self.cents = cents }

    public static let zero = Money(cents: 0)

    public static func + (a: Money, b: Money) -> Money { Money(cents: a.cents + b.cents) }
    public static func - (a: Money, b: Money) -> Money { Money(cents: a.cents - b.cents) }
    public static func * (a: Money, n: Int) -> Money { Money(cents: a.cents * n) }
    public static func += (a: inout Money, b: Money) { a.cents += b.cents }
    public static func < (a: Money, b: Money) -> Bool { a.cents < b.cents }

    /// `percent`% of this amount, rounded to the nearest cent: 50% of $8.00 is $4.00.
    public func percent(_ percent: Double) -> Money {
        Money(cents: Int((Double(cents) * percent / 100).rounded()))
    }

    /// Parses what people type: "9", "$9", "8.5", "$1,234.56", " 16.21 ". Rounds to the cent.
    /// Nil for empty text, letters, or more than one decimal point.
    public init?(parsing text: String) {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var negative = false
        if s.hasPrefix("-") { negative = true; s.removeFirst() }
        s = s.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              s.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        cents = (negative ? -1 : 1) * NSDecimalNumber(decimal: rounded).intValue
    }

    /// "1,234.56", with no sign or dollar sign.
    public var digits: String {
        let magnitude = cents.magnitude
        let dollars = String(magnitude / 100)
        var grouped = ""
        for (i, ch) in dollars.enumerated() {
            if i > 0 && (dollars.count - i) % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        let rest = magnitude % 100
        return grouped + "." + (rest < 10 ? "0" : "") + String(rest)
    }

    /// "$1,234.56", or "-$4.00".
    public var formatted: String { (cents < 0 ? "-$" : "$") + digits }

    /// What goes in a text field for editing: "9.00" → "9", "8.50" → "8.50".
    public var editingText: String {
        cents % 100 == 0 ? String(cents / 100) : digits.replacingOccurrences(of: ",", with: "")
    }

    public var description: String { formatted }
}

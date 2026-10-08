import CoreGraphics
import Foundation
import Vision

/// What the app could read off a shipping receipt photo. She circles the amount that's
/// for this order and a receipt can list several shipments, so these are suggestions she
/// taps, never filled in on their own (SPEC.md, "Shipping").
public struct ReceiptScan: Sendable, Equatable {
    /// Distinct non-zero dollar amounts, most often printed first (a receipt prints the
    /// charge, the subtotal, the total and the card amount, so the real charges repeat).
    public var amounts: [Money]
    /// "9/2/2026", the first date on the receipt.
    public var date: String?

    public init(amounts: [Money], date: String?) {
        self.amounts = amounts
        self.date = date
    }
}

public enum ReceiptReader {
    public static func read(_ image: CGImage) async throws -> ReceiptScan {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let observations = try await request.perform(on: image)
        return scan(lines: observations.compactMap { $0.topCandidates(1).first?.string })
    }

    public static func scan(lines: [String]) -> ReceiptScan {
        var counts: [Money: Int] = [:]
        var order: [Money] = []
        var date: String?
        for line in lines {
            let ns = line as NSString
            for match in amountPattern.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                guard let amount = Money(parsing: ns.substring(with: match.range)), amount > .zero else { continue }
                if counts[amount] == nil { order.append(amount) }
                counts[amount, default: 0] += 1
            }
            if date == nil, let match = datePattern.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                date = ns.substring(with: match.range)
            }
        }
        let amounts = order.sorted { a, b in
            counts[a]! != counts[b]! ? counts[a]! > counts[b]! : a > b
        }
        return ReceiptScan(amounts: Array(amounts.prefix(6)), date: date)
    }

    static let amountPattern = try! NSRegularExpression(pattern: #"\$\s?\d{1,3}(,\d{3})*\.\d{2}\b|\$\s?\d+\.\d{2}\b"#)
    static let datePattern = try! NSRegularExpression(pattern: #"\b\d{1,2}/\d{1,2}/\d{2,4}\b"#)
}

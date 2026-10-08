import Foundation

/// A saved button as the SKU rules see it.
public struct SKUEntry: Sendable, Hashable {
    public var sku: String
    public var designCode: String
    public var colors: [String]
    public var size: String

    public init(sku: String, designCode: String, colors: [String], size: String) {
        self.sku = sku
        self.designCode = designCode
        self.colors = colors
        self.size = size
    }
}

/// SKU format (SPEC.md, "SKUs"): two-digit year the button was first saved, the design's
/// letters, a code per color, then a size letter. "Daisy, Black / White, Large" saved in
/// 2026 → 26 + D + B + W + L = "26DBWL". Codes already in use are kept (Brown is BR because
/// Black had B); a new color gets its initials, or more letters if another color has those.
public struct SKURules: Sendable {
    /// Lowercased color → code.
    public private(set) var colorCodes: [String: String]
    /// Lowercased size → code.
    public var sizeCodes: [String: String]

    /// The codes in the Excel template as of September 2026 ("celedon" is the template's
    /// spelling, kept so older text still maps).
    public static let standard = SKURules(
        colorCodes: [
            "black": "B", "white": "W", "brown": "BR", "blue": "BL", "burgundy": "B", "navy": "N",
            "red": "R", "green": "G", "yellow": "Y", "ivory": "I", "celedon": "C", "celadon": "C",
            "lavender": "L", "pale pink": "PP", "matte pink": "MP", "matte white": "MW", "unglazed": "UG",
        ],
        sizeCodes: ["mini": "M", "small": "S", "medium": "M", "large": "L", "extra large": "XL"]
    )

    public init(colorCodes: [String: String], sizeCodes: [String: String]) {
        self.colorCodes = colorCodes
        self.sizeCodes = sizeCodes
    }

    /// These rules plus the color codes the saved SKUs imply, so a color she added last
    /// month keeps the code it was given. Reads codes off SKUs that follow the format;
    /// SKUs typed by hand that don't are skipped.
    public func learning(from entries: [SKUEntry]) -> SKURules {
        var rules = self
        var changed = true
        while changed {
            changed = false
            for entry in entries {
                guard var rest = rules.colorPart(of: entry), !entry.colors.isEmpty else { continue }
                let keys = entry.colors.map(Self.key)
                let unknown = keys.indices.filter { rules.colorCodes[keys[$0]] == nil }
                guard unknown.count == 1, let i = unknown.first else { continue }
                let before = keys[..<i].compactMap { rules.colorCodes[$0] }.joined()
                let after = keys[(i + 1)...].compactMap { rules.colorCodes[$0] }.joined()
                guard rest.hasPrefix(before), rest.hasSuffix(after),
                      rest.count > before.count + after.count else { continue }
                rest = String(rest.dropFirst(before.count).dropLast(after.count))
                rules.colorCodes[keys[i]] = rest
                changed = true
            }
        }
        return rules
    }

    /// "Cowrie Shell" → "CS".
    public static func designCode(for designName: String) -> String {
        Naming.splitWords(designName).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    /// The code for a color: the known one, else its initials, else more letters of its first
    /// word until no other color uses it ("Blue" → "BL" because Black is "B").
    public func colorCode(for color: String) -> String {
        let key = Self.key(color)
        if let code = colorCodes[key] { return code }
        let words = Naming.splitWords(color).map { $0.uppercased() }
        guard let first = words.first else { return "" }
        let tail = words.dropFirst().compactMap { $0.first.map(String.init) }.joined()
        let used = Set(colorCodes.values)
        for length in 1...first.count {
            let code = String(first.prefix(length)) + tail
            if !used.contains(code) { return code }
        }
        return first + tail
    }

    public func sizeCode(for size: String) -> String {
        let key = Self.key(size)
        if key.isEmpty { return "" }
        return sizeCodes[key] ?? String(size.prefix(1)).uppercased()
    }

    /// The SKU for a new button. `taken` holds the SKUs already in use (any case). If the
    /// natural SKU is taken, the design part grows a letter ("26SBW" taken by the sailboat →
    /// a star gets "26STBW"), then a number is added.
    public func suggestSKU(year: Int, designName: String, designCode: String, colors: [String],
                           size: String, taken: Set<String>) -> String {
        let yy = String(format: "%02d", year % 100)
        let tail = colors.map(colorCode).joined() + sizeCode(for: size)
        let used = Set(taken.map { $0.uppercased() })
        let code = designCode.isEmpty ? Self.designCode(for: designName) : designCode.uppercased()
        var designCodes = [code]
        let words = Naming.splitWords(designName).map { $0.uppercased() }
        if let first = words.first {
            let rest = words.dropFirst().compactMap { $0.first.map(String.init) }.joined()
            for length in 2...max(2, first.count) where length <= first.count {
                let longer = String(first.prefix(length)) + rest
                if !designCodes.contains(longer) { designCodes.append(longer) }
            }
        }
        for design in designCodes where !used.contains(yy + design + tail) {
            return yy + design + tail
        }
        var n = 2
        while used.contains(yy + code + tail + String(n)) { n += 1 }
        return yy + code + tail + String(n)
    }

    /// The color letters of an SKU that follows the format, e.g. "BLW" from "26MBLW".
    func colorPart(of entry: SKUEntry) -> String? {
        let sku = entry.sku.uppercased()
        guard sku.count > 2, sku.prefix(2).allSatisfy(\.isNumber) else { return nil }
        var rest = String(sku.dropFirst(2))
        let design = entry.designCode.uppercased()
        guard !design.isEmpty, rest.hasPrefix(design) else { return nil }
        rest.removeFirst(design.count)
        let size = sizeCode(for: entry.size)
        guard rest.hasSuffix(size) else { return nil }
        rest.removeLast(size.count)
        return rest
    }

    static func key(_ s: String) -> String {
        Naming.splitWords(s).joined(separator: " ").lowercased()
    }
}

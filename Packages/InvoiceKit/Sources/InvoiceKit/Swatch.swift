import Foundation

/// A dot of color for a color name, shown on the color chips. Her own glazes come first,
/// set from her photos (median of each single-color button, Oct 8, 2026, adjusted where a
/// highlight or outline pulled it off), then common color words. "Pale", "light" and the
/// like lighten the color after them; "dark" and "deep" darken it. An unknown name has no
/// swatch.
public enum Swatch {
    public struct RGB: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double

        init(hex: Int) {
            red = Double((hex >> 16) & 0xFF) / 255
            green = Double((hex >> 8) & 0xFF) / 255
            blue = Double(hex & 0xFF) / 255
        }

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        func mixed(with other: RGB, _ amount: Double) -> RGB {
            RGB(red: red + (other.red - red) * amount,
                green: green + (other.green - green) * amount,
                blue: blue + (other.blue - blue) * amount)
        }

        static let white = RGB(red: 1, green: 1, blue: 1)
        static let black = RGB(red: 0, green: 0, blue: 0)
    }

    /// Her glazes, and color words of two words that mean one color.
    static let named: [String: Int] = [
        "black": 0x1A1F26, "white": 0xF2F2EC, "red": 0xDE4A22, "burgundy": 0xA8423F,
        "navy": 0x18235A, "blue": 0x6FA8D6, "brown": 0x9A5124, "green": 0x7E8A55,
        "celadon": 0xA8B894, "ivory": 0xEDE6D3, "lavender": 0xBFAAC9, "matte pink": 0xCFA493,
        "matte white": 0xE6E4DA, "pale pink": 0xEDC7C2, "yellow": 0xE8B23A, "unglazed": 0xD8D2C4,
        "off white": 0xF0EBDD, "navy blue": 0x18235A, "olive green": 0x7E8A55,
    ]

    /// Common color words for colors she hasn't used yet.
    static let common: [String: Int] = [
        "pink": 0xE89AAE, "orange": 0xE8792F, "purple": 0x7D5A9E, "gray": 0x8E8E8E,
        "grey": 0x8E8E8E, "tan": 0xC8A882, "beige": 0xD9C8A9, "cream": 0xF3E9CF,
        "teal": 0x2E8077, "turquoise": 0x45B5B0, "coral": 0xEE7B66, "peach": 0xF2B48C,
        "mint": 0xA8D8BC, "sage": 0xA3B18A, "gold": 0xC9A23A, "silver": 0xBFC1C4,
        "rust": 0xA9502B, "terracotta": 0xC0582F, "mustard": 0xCFA133, "maroon": 0x6E1E26,
        "olive": 0x7E8A55, "blush": 0xEDC1C0, "plum": 0x6E3A5E, "cobalt": 0x1F4FA8,
        "sky": 0x8EC3E6, "forest": 0x2F5D3A, "charcoal": 0x3A3D42, "chocolate": 0x5A3A26,
        "lilac": 0xC8A9D6, "mauve": 0xB48A9C, "rose": 0xD9798A, "aqua": 0x6CC9C9,
        "emerald": 0x2E8B57, "lemon": 0xF2DA4C, "salmon": 0xF09A86, "copper": 0xB8693A,
        "bronze": 0xA07A3E, "indigo": 0x3B3F8C, "violet": 0x8A5FBF, "magenta": 0xC2408A,
        "crimson": 0xB0213A, "scarlet": 0xD63A2A, "khaki": 0xB9AE7E, "taupe": 0x9A8A7A,
        "denim": 0x4A6E9A, "cerulean": 0x3A8FC4, "jade": 0x3E9E78, "seafoam": 0x9FD8C4,
        "honey": 0xD9A441, "caramel": 0xB9773E, "sand": 0xD8C39A, "slate": 0x5E6B78,
    ]

    static let lighter: Set<String> = ["pale", "light", "soft", "pastel", "baby"]
    static let darker: Set<String> = ["dark", "deep"]

    public static func rgb(for name: String) -> RGB? {
        let words = name.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        guard !words.isEmpty else { return nil }
        if let hex = named[words.joined(separator: " ")] { return RGB(hex: hex) }
        // The first color word names the color: "Navy Blue" is navy, "Forest Green" forest.
        var lighten = 0
        var darken = 0
        for word in words {
            if lighter.contains(word) { lighten += 1; continue }
            if darker.contains(word) { darken += 1; continue }
            guard let hex = named[word] ?? common[word] else { continue }
            var rgb = RGB(hex: hex)
            if lighten > 0 { rgb = rgb.mixed(with: .white, 0.45) }
            if darken > 0 { rgb = rgb.mixed(with: .black, 0.35) }
            return rgb
        }
        return nil
    }
}

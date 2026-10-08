import Testing
@testable import InvoiceKit

@Suite struct SwatchTests {
    @Test func everySavedColorHasASwatch() throws {
        for v in try Repo.catalog().variants {
            for color in v.colors {
                #expect(Swatch.rgb(for: color) != nil, "\(color) has no swatch")
            }
        }
    }

    @Test func readsColorWords() {
        #expect(Swatch.rgb(for: "Navy Blue") == Swatch.rgb(for: "Navy"))
        #expect(Swatch.rgb(for: "Off White") != Swatch.rgb(for: "White"))
        #expect(Swatch.rgb(for: "Sage") != nil)
        #expect(Swatch.rgb(for: "Speckled Green") == Swatch.rgb(for: "Green"))
        #expect(Swatch.rgb(for: "Glow in the Dark") == nil)
        #expect(Swatch.rgb(for: "") == nil)
        let blue = Swatch.rgb(for: "Blue")!, light = Swatch.rgb(for: "Light Blue")!, dark = Swatch.rgb(for: "Dark Blue")!
        #expect(light.red > blue.red && light.blue > blue.blue)
        #expect(dark.red < blue.red && dark.blue < blue.blue)
    }
}

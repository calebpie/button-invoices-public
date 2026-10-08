// swift-tools-version:6.0
// The app's logic with no UI: naming and SKU rules, matching what she types against the
// catalog, invoice numbers and totals, the PDF layout, and the photo cutout and receipt
// reading built on Vision. Platform-neutral so `make test` runs it all on the Mac.
import PackageDescription

let package = Package(
    name: "InvoiceKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "InvoiceKit", targets: ["InvoiceKit"]),
    ],
    targets: [
        .target(name: "InvoiceKit"),
        .testTarget(name: "InvoiceKitTests", dependencies: ["InvoiceKit"]),
    ]
)

import CoreGraphics
import CoreText
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Draws an invoice as a US Letter PDF laid out like the Excel template's printout
/// (SPEC.md, "The PDF"). Positions are in points from the top-left corner and were measured
/// from "Daphné Verley Invoice - AOB 0260903.pdf": nine 63 pt columns from x = 23, 15 pt
/// rows, 58 pt per button. Microsoft's Aptos Narrow and Calibri can't ship in an app, so
/// the system font stands in (condensed where the template used Aptos Narrow).
public enum InvoicePDF {
    public static func render(_ doc: InvoiceDocument) -> Data {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: L.page)
        let info: [CFString: Any] = [
            kCGPDFContextTitle: "Invoice \(doc.number)",
            kCGPDFContextAuthor: doc.seller.name,
            kCGPDFContextCreator: "Button Invoices",
        ]
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary)
        else { return Data() }
        Page(ctx: ctx).draw(doc)
        ctx.closePDF()
        return data as Data
    }

    /// "Daphné Verley Invoice - AOB 0260903.pdf". Slashes and colons become dashes.
    public static func fileName(prefix: String, number: String) -> String {
        let name = [prefix, number].filter { !$0.isEmpty }.joined(separator: " ")
        return name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
    }

    /// Pages the invoice will take (for tests and the review screen).
    public static func pageCount(_ doc: InvoiceDocument) -> Int {
        layout(doc).pages
    }

    static func layout(_ doc: InvoiceDocument) -> (pages: Int, itemTops: [(page: Int, top: CGFloat)], totalsTop: (page: Int, top: CGFloat)) {
        var page = 0
        var y = L.tableTop + L.row
        var tops: [(Int, CGFloat)] = []
        for _ in doc.lines {
            if y + L.item > L.bottom {
                page += 1
                y = L.top + L.row
            }
            tops.append((page, y))
            y += L.item
        }
        let totalsHeight = CGFloat(L.totalsRows(doc)) * L.row
        if y + totalsHeight > L.bottom {
            page += 1
            y = L.top
        }
        return (page + 1, tops, (page, y))
    }
}

/// Layout constants (points, top-left origin).
private enum L {
    static let page = CGSize(width: 612, height: 792)
    /// Column edges A…I.
    static let x: [CGFloat] = [23, 86, 149, 212, 275, 338, 401, 464, 527, 590]
    static let top: CGFloat = 20
    static let bottom: CGFloat = 771
    static let row: CGFloat = 15
    static let item: CGFloat = 58
    static let tableTop: CGFloat = 230
    static let stroke: CGFloat = 0.75
    /// Excel's white darkened 25% (headers, TOTAL) and 15% (SUBTOTAL, SHIPPING).
    static let darkFill = CGColor(gray: 191.0 / 255, alpha: 1)
    static let lightFill = CGColor(gray: 217.0 / 255, alpha: 1)
    static let titleGray = CGColor(gray: 127.0 / 255, alpha: 1)
    static let black = CGColor(gray: 0, alpha: 1)

    static func totalsRows(_ doc: InvoiceDocument) -> Int {
        2 + max(1, doc.shipping.count)
    }
}

private enum Fonts {
    /// Stands in for Aptos Narrow.
    static func narrow(_ size: CGFloat, bold: Bool = false) -> CTFont {
        #if canImport(UIKit)
        UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular, width: .condensed) as CTFont
        #else
        NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular, width: .condensed) as CTFont
        #endif
    }

    /// Stands in for Calibri.
    static func body(_ size: CGFloat, bold: Bool = false, light: Bool = false, italic: Bool = false) -> CTFont {
        #if canImport(UIKit)
        let weight: UIFont.Weight = bold ? .semibold : light ? .light : .regular
        var font = UIFont.systemFont(ofSize: size, weight: weight) as CTFont
        #else
        let weight: NSFont.Weight = bold ? .semibold : light ? .light : .regular
        var font = NSFont.systemFont(ofSize: size, weight: weight) as CTFont
        #endif
        if italic, let slanted = CTFontCreateCopyWithSymbolicTraits(font, size, nil, .traitItalic, .traitItalic) {
            font = slanted
        }
        return font
    }

    static let bodySize: CGFloat = 11
    static let narrowSize: CGFloat = 12
}

private struct Page {
    let ctx: CGContext

    enum Align { case left, center, right }

    func draw(_ doc: InvoiceDocument) {
        let plan = InvoicePDF.layout(doc)
        var current = -1
        func turn(to page: Int) {
            while current < page {
                if current >= 0 { ctx.endPDFPage() }
                current += 1
                begin()
                if current == 0 {
                    header(doc)
                    tableHeader(at: L.tableTop)
                } else if plan.itemTops.contains(where: { $0.page == current }) {
                    tableHeader(at: L.top)
                }
            }
        }
        turn(to: 0)
        for (line, spot) in zip(doc.lines, plan.itemTops) {
            turn(to: spot.page)
            item(line, top: spot.top)
        }
        turn(to: plan.totalsTop.page)
        totals(doc, top: plan.totalsTop.top)
        ctx.endPDFPage()
    }

    func begin() {
        ctx.beginPDFPage(nil)
        // Work top-down like the spreadsheet.
        ctx.translateBy(x: 0, y: L.page.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.setLineWidth(L.stroke)
        ctx.setStrokeColor(L.black)
    }

    // MARK: Sections

    func header(_ doc: InvoiceDocument) {
        if let logo = doc.logo {
            let height: CGFloat = 46
            let width = height * CGFloat(logo.width) / CGFloat(max(logo.height, 1))
            image(logo, in: CGRect(x: 306.5 - width / 2, y: 22, width: width, height: height))
        }
        party(doc.seller, firstCenter: 73.5)
        text("INVOICE", Fonts.narrow(24, bold: true), color: L.titleGray,
             in: CGRect(x: L.x[5], y: 70, width: L.x[9] - L.x[5], height: 21), align: .center)

        let invoiceHeader = [CGRect(x: L.x[5], y: 110, width: 126, height: L.row),
                             CGRect(x: L.x[7], y: 110, width: 126, height: L.row)]
        for (cell, label) in zip(invoiceHeader, ["INVOICE #", "DATE"]) {
            box(cell, fill: L.darkFill)
            text(label, Fonts.narrow(Fonts.narrowSize), in: cell, align: .center)
        }
        for (cell, value) in zip(invoiceHeader.map { $0.offsetBy(dx: 0, dy: L.row) },
                                 [doc.number, InvoiceDocument.formatDate(doc.date)]) {
            box(cell)
            text(value, Fonts.narrow(Fonts.narrowSize), in: cell, align: .center)
        }

        let billTo = CGRect(x: L.x[0], y: 140, width: L.x[4] - L.x[0], height: L.row)
        box(billTo, fill: L.darkFill)
        text("BILL TO", Fonts.narrow(Fonts.narrowSize), in: billTo, align: .center)
        party(doc.billTo, firstCenter: 163.5)
    }

    func party(_ party: InvoiceDocument.Party, firstCenter: CGFloat) {
        let width = L.x[4] - L.x[0]
        for (i, line) in ([party.name] + party.lines).enumerated() {
            let center = firstCenter + CGFloat(i) * L.row
            text(line, Fonts.narrow(Fonts.narrowSize, bold: i == 0),
                 in: CGRect(x: L.x[0], y: center - L.row / 2, width: width, height: L.row), align: .left, inset: 3)
        }
    }

    func tableHeader(at top: CGFloat) {
        let cells: [(String, Int, Int)] = [("SKU", 0, 1), ("IMAGE", 1, 2), ("DESCRIPTION", 2, 5), ("QTY", 5, 6),
                                           ("PRICE", 6, 7), ("DISCOUNT", 7, 8), ("SUBTOT", 8, 9)]
        for (label, from, to) in cells {
            let cell = CGRect(x: L.x[from], y: top, width: L.x[to] - L.x[from], height: L.row)
            box(cell, fill: L.darkFill)
            text(label, Fonts.narrow(Fonts.narrowSize, bold: true), in: cell, align: .center)
        }
    }

    func item(_ line: InvoiceDocument.Line, top: CGFloat) {
        let height = L.item
        func cell(_ from: Int, _ to: Int) -> CGRect {
            CGRect(x: L.x[from], y: top, width: L.x[to] - L.x[from], height: height)
        }
        for edge in [0, 1, 2, 5, 6, 7, 8, 9] {
            ctx.move(to: CGPoint(x: L.x[edge], y: top))
            ctx.addLine(to: CGPoint(x: L.x[edge], y: top + height))
        }
        ctx.move(to: CGPoint(x: L.x[0], y: top + height))
        ctx.addLine(to: CGPoint(x: L.x[9], y: top + height))
        ctx.strokePath()

        text(line.sku, Fonts.body(Fonts.bodySize, italic: true), in: cell(0, 1), align: .center)
        if let img = line.image {
            image(img, in: cell(1, 2).insetBy(dx: 4, dy: 4), fit: true)
        }
        let description = cell(2, 5)
        let rows: [(String, CTFont, CGFloat)] = [
            (line.productLabel, Fonts.body(Fonts.bodySize, bold: true), 16),
            (line.description, Fonts.body(Fonts.bodySize), 31),
            (line.makerLine, Fonts.body(Fonts.bodySize, light: true), 46),
        ]
        for (value, font, center) in rows {
            text(value, font, in: CGRect(x: description.minX, y: top + center - L.row / 2,
                                         width: description.width, height: L.row), align: .left, inset: 9.5)
        }
        text(String(line.quantity), Fonts.body(Fonts.bodySize), in: cell(5, 6), align: .center)
        money(line.unitPrice, in: cell(6, 7), font: Fonts.body(Fonts.bodySize))
        money(line.discount, in: cell(7, 8), font: Fonts.body(Fonts.bodySize))
        money(line.subtotal, in: cell(8, 9), font: Fonts.body(Fonts.bodySize, bold: true))
    }

    func totals(_ doc: InvoiceDocument, top: CGFloat) {
        var rows: [(String, Money, Bool)] = [("SUBTOTAL:", doc.buttonsSubtotal, false)]
        let shipping = doc.shipping.isEmpty ? [Money.zero] : doc.shipping
        rows += shipping.map { ("SHIPPING:", $0, false) }
        rows.append(("TOTAL:", doc.total, true))
        for (i, (label, amount, isTotal)) in rows.enumerated() {
            let y = top + CGFloat(i) * L.row
            let labelCell = CGRect(x: L.x[6], y: y, width: L.x[8] - L.x[6], height: L.row)
            let valueCell = CGRect(x: L.x[8], y: y, width: L.x[9] - L.x[8], height: L.row)
            box(labelCell, fill: isTotal ? L.darkFill : L.lightFill)
            box(valueCell)
            text(label, Fonts.body(Fonts.bodySize, bold: isTotal), in: labelCell, align: .right, inset: 3)
            money(amount, in: valueCell, font: Fonts.body(Fonts.bodySize, bold: isTotal))
        }
        // Routing and account sit beside the last rows of the totals, as in the template.
        let firstPaymentRow = max(0, rows.count - doc.payment.count)
        for (i, detail) in doc.payment.enumerated() {
            let y = top + CGFloat(firstPaymentRow + i) * L.row
            text(detail.label, Fonts.narrow(Fonts.narrowSize, bold: true),
                 in: CGRect(x: L.x[1], y: y, width: L.x[3] - L.x[1], height: L.row), align: .right, inset: 7)
            text(detail.value, Fonts.narrow(Fonts.narrowSize),
                 in: CGRect(x: L.x[3], y: y, width: L.x[5] - L.x[3], height: L.row), align: .left, inset: 4)
        }
    }

    // MARK: Drawing

    func box(_ rect: CGRect, fill: CGColor? = nil) {
        if let fill {
            ctx.setFillColor(fill)
            ctx.fill(rect)
        }
        ctx.stroke(rect)
    }

    /// Accounting format, as Excel prints it: "$" at the left of the cell, the amount at the
    /// right, and "-" for zero.
    func money(_ amount: Money, in cell: CGRect, font: CTFont) {
        let leftInset: CGFloat = 7, rightInset: CGFloat = 5.5
        if amount == .zero {
            draw(line("$", font), x: cell.minX + leftInset, centerY: cell.midY)
            let dash = line("-", font)
            draw(dash, x: cell.maxX - rightInset - 12 - dash.width, centerY: cell.midY)
            return
        }
        let digits = amount.cents < 0 ? "(\(amount.digits))" : amount.digits
        var font = font
        var number = line(digits, font)
        var dollar = line("$", font)
        // Large amounts are set smaller rather than touching the cell's left edge.
        while number.width + dollar.width + 2.5 > cell.width - rightInset - 2 && CTFontGetSize(font) > 7 {
            font = CTFontCreateCopyWithAttributes(font, CTFontGetSize(font) - 0.25, nil, nil)
            number = line(digits, font)
            dollar = line("$", font)
        }
        let numberX = cell.maxX - rightInset - number.width
        let dollarX = min(cell.minX + leftInset, numberX - dollar.width - 1)
        draw(dollar, x: dollarX, centerY: cell.midY)
        draw(number, x: numberX, centerY: cell.midY)
    }

    /// Single-line text, vertically centered in `rect`. Text too wide for the cell is set
    /// smaller rather than overflowing into the next one.
    func text(_ string: String, _ font: CTFont, color: CGColor = L.black, in rect: CGRect,
              align: Align, inset: CGFloat = 0) {
        guard !string.isEmpty else { return }
        let room = rect.width - 2 * inset
        var font = font
        var ln = line(string, font, color: color)
        while ln.width > room && CTFontGetSize(font) > 7 {
            font = CTFontCreateCopyWithAttributes(font, CTFontGetSize(font) - 0.5, nil, nil)
            ln = line(string, font, color: color)
        }
        let w = ln.width
        let x: CGFloat
        switch align {
        case .left: x = rect.minX + inset
        case .center: x = rect.midX - w / 2
        case .right: x = rect.maxX - inset - w
        }
        draw(ln, x: x, centerY: rect.midY)
    }

    /// A line of text with the font it was set in (needed to center it).
    struct Text {
        let line: CTLine
        let font: CTFont
        var width: CGFloat { CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) }
    }

    func line(_ string: String, _ font: CTFont, color: CGColor = L.black) -> Text {
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        return Text(line: CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attrs)),
                    font: font)
    }

    /// Centers capitals on `centerY`, which reads as centered for numbers and labels.
    func draw(_ text: Text, x: CGFloat, centerY: CGFloat) {
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: x, y: centerY + CTFontGetCapHeight(text.font) / 2)
        CTLineDraw(text.line, ctx)
        ctx.restoreGState()
    }

    func image(_ image: CGImage, in rect: CGRect, fit: Bool = false) {
        var small = ImageTools.downscaled(image, maxSide: fit ? 400 : 300)
        if fit, let bounds = Cutout.opaqueBounds(small), let trimmed = small.cropping(to: bounds) {
            small = trimmed // photos are square with a margin; the cell should hold the button itself
        }
        if fit {
            // Button photos go in as small JPEGs on white, which PDF stores as they are:
            // about 15 KB each instead of 100 KB as transparent PNGs. 200 px is over three
            // pixels per point in a 58 pt cell.
            small = ImageTools.jpegOnWhite(ImageTools.downscaled(small, maxSide: 200)) ?? small
        }
        var target = rect
        if fit {
            let scale = min(rect.width / CGFloat(small.width), rect.height / CGFloat(small.height))
            let w = CGFloat(small.width) * scale, h = CGFloat(small.height) * scale
            target = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        }
        ctx.saveGState()
        ctx.translateBy(x: target.minX, y: target.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.interpolationQuality = .high
        ctx.draw(small, in: CGRect(origin: .zero, size: target.size))
        ctx.restoreGState()
    }
}

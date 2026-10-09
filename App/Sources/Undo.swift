import Foundation
import InvoiceKit
import SwiftData

/// Shake to undo, and the three-finger swipe, for removing, archiving and deleting (SPEC.md,
/// "Undo"). The app records these itself instead of letting SwiftData record every change:
/// SwiftData's undo of a change that has already been saved isn't saved again, so an invoice
/// brought back by Undo was gone at the next launch (Docs/progress.md, "Undo doesn't survive
/// a restart").
@MainActor enum Undo {
    /// The window's undo manager, the one a shake asks (RootView sets it).
    static weak var manager: UndoManager?

    /// A change, made when applied, that gives back the change reversing it.
    struct Step {
        let apply: @MainActor (ModelContext) -> Step
    }

    /// Makes the change now, saves it, and records its reverse under `name` ("Remove Button").
    static func perform(_ name: String, _ context: ModelContext, _ step: Step) {
        record(name, context, step.apply(context))
        try? context.save()
    }

    private static func record(_ name: String, _ context: ModelContext, _ reverse: Step) {
        guard let manager else { return }
        manager.registerUndo(withTarget: context) { context in
            MainActor.assumeIsolated {
                // Recorded while undoing, this is the redo, and the other way round.
                record(name, context, reverse.apply(context))
                try? context.save()
            }
        }
        manager.setActionName(name)
    }
}

// MARK: - Steps

extension Undo.Step {
    static var nothing: Undo.Step { Undo.Step { _ in .nothing } }

    /// Deletes the invoice, its lines and its shipping; the reverse puts back a copy of all three.
    static func delete(_ invoice: Invoice) -> Undo.Step {
        Undo.Step { context in
            guard !invoice.isDeleted else { return .nothing }
            let saved = SavedInvoice(invoice)
            context.delete(invoice)
            return .restore(saved)
        }
    }

    private static func restore(_ saved: SavedInvoice) -> Undo.Step {
        Undo.Step { context in .delete(saved.insert(into: context)) }
    }

    /// Takes lines off their invoice and closes the gap in the numbering.
    static func remove(_ lines: [InvoiceLine], from invoice: Invoice) -> Undo.Step {
        Undo.Step { context in
            let lines = lines.filter { !$0.isDeleted }
            guard !lines.isEmpty else { return .nothing }
            let saved = lines.map(SavedLine.init).sorted { $0.position < $1.position }
            let number = invoice.number
            for line in lines { context.delete(line) }
            for (i, line) in invoice.sortedLines.filter({ l in !lines.contains { $0 === l } }).enumerated() {
                line.position = i
            }
            return .restore(saved, to: invoice, number: number)
        }
    }

    private static func restore(_ saved: [SavedLine], to invoice: Invoice, number: String) -> Undo.Step {
        Undo.Step { context in
            guard let invoice = Self.live(invoice, number: number, context) else { return .nothing }
            var restored: [InvoiceLine] = []
            for line in saved {
                for other in invoice.sortedLines where other.position >= line.position { other.position += 1 }
                restored.append(line.insert(into: invoice, context))
            }
            return .remove(restored, from: invoice)
        }
    }

    static func remove(_ charges: [ShippingCharge], from invoice: Invoice) -> Undo.Step {
        Undo.Step { context in
            let charges = charges.filter { !$0.isDeleted }
            guard !charges.isEmpty else { return .nothing }
            let saved = charges.map(SavedCharge.init)
            let number = invoice.number
            for charge in charges { context.delete(charge) }
            return .restore(saved, to: invoice, number: number)
        }
    }

    private static func restore(_ saved: [SavedCharge], to invoice: Invoice, number: String) -> Undo.Step {
        Undo.Step { context in
            guard let invoice = Self.live(invoice, number: number, context) else { return .nothing }
            return .remove(saved.map { $0.insert(into: invoice, context) }, from: invoice)
        }
    }

    /// Archives (true) or unarchives buttons; the reverse sets each one back as it was.
    static func setHidden(_ variants: [ButtonVariant], _ hidden: Bool) -> Undo.Step {
        setHidden(variants, Array(repeating: hidden, count: variants.count))
    }

    private static func setHidden(_ variants: [ButtonVariant], _ values: [Bool]) -> Undo.Step {
        Undo.Step { _ in
            let before = variants.map(\.isHidden)
            for (variant, value) in zip(variants, values) where !variant.isDeleted { variant.isHidden = value }
            return .setHidden(variants, before)
        }
    }

    /// The invoice a line was removed from. If it was deleted and brought back by Undo since,
    /// it's a new copy: found by its number.
    private static func live(_ invoice: Invoice, number: String, _ context: ModelContext) -> Invoice? {
        if !invoice.isDeleted, invoice.modelContext != nil { return invoice }
        return try? context.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.number == number })).first
    }
}

// MARK: - Copies kept for undo

/// Everything stored on an invoice, its lines and its shipping, to put it back as it was.
private struct SavedInvoice {
    var number: String
    var numberIsCustom: Bool
    var date: Date
    var statusRaw: String
    var createdAt: Date
    var finalizedAt: Date?
    var noShipping: Bool
    var businessSnapshot: Data?
    var finishedPDF: Data?
    var lines: [SavedLine]
    var shipping: [SavedCharge]

    @MainActor init(_ invoice: Invoice) {
        number = invoice.number
        numberIsCustom = invoice.numberIsCustom
        date = invoice.date
        statusRaw = invoice.statusRaw
        createdAt = invoice.createdAt
        finalizedAt = invoice.finalizedAt
        noShipping = invoice.noShipping
        businessSnapshot = invoice.businessSnapshot
        finishedPDF = invoice.finishedPDF
        lines = (invoice.lines ?? []).map(SavedLine.init)
        shipping = (invoice.shipping ?? []).map(SavedCharge.init)
    }

    @MainActor func insert(into context: ModelContext) -> Invoice {
        let invoice = Invoice(number: number, date: date)
        invoice.numberIsCustom = numberIsCustom
        invoice.statusRaw = statusRaw
        invoice.createdAt = createdAt
        invoice.finalizedAt = finalizedAt
        invoice.noShipping = noShipping
        invoice.businessSnapshot = businessSnapshot
        invoice.finishedPDF = finishedPDF
        context.insert(invoice)
        for line in lines { _ = line.insert(into: invoice, context) }
        for charge in shipping { _ = charge.insert(into: invoice, context) }
        return invoice
    }
}

private struct SavedLine {
    var position: Int
    var sku: String
    var itemDescription: String
    var quantity: Int
    var unitPriceCents: Int
    var discountCents: Int
    var discountIsPercent: Bool
    var discountPercent: Double
    var photo: Data?
    var variant: PersistentIdentifier?

    @MainActor init(_ line: InvoiceLine) {
        position = line.position
        sku = line.sku
        itemDescription = line.itemDescription
        quantity = line.quantity
        unitPriceCents = line.unitPriceCents
        discountCents = line.discountCents
        discountIsPercent = line.discountIsPercent
        discountPercent = line.discountPercent
        photo = line.photo
        variant = line.variant?.persistentModelID
    }

    @MainActor func insert(into invoice: Invoice, _ context: ModelContext) -> InvoiceLine {
        let line = InvoiceLine(position: position, sku: sku, description: itemDescription, quantity: quantity,
                               unitPrice: Money(cents: unitPriceCents))
        line.discountCents = discountCents
        line.discountIsPercent = discountIsPercent
        line.discountPercent = discountPercent
        line.photo = photo
        context.insert(line)
        line.invoice = invoice
        if let id = variant {
            line.variant = try? context.fetch(FetchDescriptor<ButtonVariant>(predicate: #Predicate { $0.persistentModelID == id })).first
        }
        return line
    }
}

private struct SavedCharge {
    var position: Int
    var amountCents: Int
    var note: String
    var receiptPhoto: Data?

    @MainActor init(_ charge: ShippingCharge) {
        position = charge.position
        amountCents = charge.amountCents
        note = charge.note
        receiptPhoto = charge.receiptPhoto
    }

    @MainActor func insert(into invoice: Invoice, _ context: ModelContext) -> ShippingCharge {
        let charge = ShippingCharge(position: position, amount: Money(cents: amountCents), note: note)
        charge.receiptPhoto = receiptPhoto
        context.insert(charge)
        charge.invoice = invoice
        return charge
    }
}

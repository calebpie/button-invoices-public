import Foundation

/// Invoice numbers are "0" + the invoice date as yyMMdd: 3 Sep 2026 → "0260903"
/// (SPEC.md, "Invoice numbers"). A second invoice dated the same day gets "-2", a third "-3".
public enum InvoiceNumber {
    public static func base(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "0%02d%02d%02d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }

    public static func next(for date: Date, existing: some Collection<String>,
                            calendar: Calendar = .current) -> String {
        let base = base(for: date, calendar: calendar)
        let used = Set(existing)
        if !used.contains(base) && !used.contains(base + "-1") { return base }
        var n = 2
        while used.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

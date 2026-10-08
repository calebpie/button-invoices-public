import InvoiceKit
import SwiftUI
import TipKit
import UIKit

// Shared pieces that follow Apple's Human Interface Guidelines (SPEC.md, "Design
// guidelines"), with fallbacks for iOS 18 where the iOS 26 version doesn't exist.

// MARK: - Navigation state

enum AppTab: String, Hashable {
    case invoices, buttons, settings
}

/// Where the app is, so Home Screen quick actions, App Shortcuts and state restoration can
/// take her to the right place.
@MainActor @Observable final class AppRouter {
    static let shared = AppRouter()

    enum Request: Equatable {
        case newInvoice
        case newButton
    }

    var tab: AppTab = .invoices
    var invoicePath: [Invoice] = []
    /// Set by a quick action or App Shortcut; the tab that handles it clears it.
    var request: Request?

    func handle(_ request: Request) {
        switch request {
        case .newInvoice: tab = .invoices
        case .newButton: tab = .buttons
        }
        self.request = request
    }
}

// MARK: - Bars

extension View {
    /// A bar of controls pinned to an edge above scrolling content. On iOS 26 this is a safe
    /// area bar, which gives the content beneath it the system scroll edge effect instead of
    /// a solid background ("Differentiate controls from content", Layout).
    @ViewBuilder func controlBar<Content: View>(edge: VerticalEdge, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: edge) { content() }
        } else {
            safeAreaInset(edge: edge, spacing: 0) { content().background(.bar) }
        }
    }

    /// The filled accent button. Inside a list row SwiftUI colors a Label's icon with the
    /// accent color, the same color as this button's fill, so the icon vanished; the label
    /// style puts the icon back in the button's own white, like its title.
    func prominentButton() -> some View {
        buttonStyle(.borderedProminent).labelStyle(.titleAndIcon)
    }

    /// Liquid Glass on iOS 26 and later; a filled capsule before that. Its icon is kept in
    /// the title's color for the same reason as `prominentButton()`.
    @ViewBuilder func glassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent).labelStyle(.titleAndIcon)
        } else {
            prominentButton().buttonBorderShape(.capsule)
        }
    }

    /// On iPad, keeps forms and lists to a comfortable reading width instead of the full screen.
    func readableWidth() -> some View {
        frame(maxWidth: 760).frame(maxWidth: .infinity).background(Color(.systemGroupedBackground))
    }

    func card() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    /// A heading for VoiceOver's rotor ("Use titles and headings", VoiceOver).
    func heading() -> some View {
        accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Search

extension View {
    /// The system search field, shown only while she searches: a search circle in the bar
    /// opens it focused, and its Cancel takes it away again (Search fields, "Search in a
    /// toolbar"). iOS 26's own minimized search does the same, but in this tab layout it
    /// stuck half open the second time it was used, with or without the custom title and
    /// keyboard handling (iOS 27.0 Simulator, Oct 8, 2026).
    func searchOnRequest(text: Binding<String>, isSearching: Binding<Bool>, prompt: String) -> some View {
        modifier(SearchOnRequest(text: text, isSearching: isSearching, prompt: prompt))
    }
}

private struct SearchOnRequest: ViewModifier {
    @Binding var text: String
    @Binding var isSearching: Bool
    let prompt: String
    @State private var focused = false

    func body(content: Content) -> some View {
        if isSearching {
            content
                .searchable(text: $text, isPresented: $focused,
                            placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
                .task {
                    // Focus once the field exists.
                    focused = true
                }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused {
                        text = ""
                        isSearching = false
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Destructive rows

/// A destructive list row's label with its icon in the same red as its text. A list colors a
/// row's icon with the accent, and neither the role nor `.tint` reaches it.
struct DestructiveLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(.red)
        }
        .foregroundStyle(.red)
    }
}

// MARK: - Title

extension View {
    /// The screen's title on the bar's own row, level with its buttons: large at the top of
    /// the list, shrinking to the standard size as she scrolls, with the system's scroll edge
    /// effect under the bar (Caleb's design, Oct 8, 2026). The size follows the scroll
    /// position, so it moves with her finger rather than jumping.
    func shrinkingTitle(_ title: String) -> some View {
        modifier(ShrinkingTitle(title: title))
    }
}

private struct ShrinkingTitle: ViewModifier {
    let title: String
    @State private var progress: CGFloat = 0
    @ScaledMetric(relativeTo: .largeTitle) private var large: CGFloat = 34
    @ScaledMetric(relativeTo: .headline) private var small: CGFloat = 17

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                progress = min(max(offset / 52, 0), 1)
            }
            // Kept for VoiceOver and the app switcher; drawn by the item below instead.
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Capped so the largest text sizes still fit the bar.
                    let size = min(large, 44) + (min(small, 24) - min(large, 44)) * progress
                    Text(title)
                        .font(.system(size: size, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                .hidingSharedBackground()
            }
    }
}

extension ToolbarContent {
    /// Text in the bar without the glass capsule iOS 26 puts behind toolbar items.
    @ToolbarContentBuilder func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Toolbar buttons

/// The standard Cancel for sheets: an xmark on iOS 26, the word Cancel before that
/// (Toolbars, "Use the standard Back and Close buttons"; Sheets).
struct CancelButton: View {
    var title = "Cancel"
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(title, systemImage: "xmark", role: .cancel, action: action)
                .labelStyle(.iconOnly)
        } else {
            Button(title, role: .cancel, action: action)
        }
    }
}

/// The one prominent action of a sheet, on the trailing side: a tinted checkmark on iOS 26
/// (Toolbars, "Use the .prominent style for key actions").
struct ConfirmButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(title, systemImage: "checkmark", role: .confirm, action: action)
                .labelStyle(.iconOnly)
        } else {
            Button(title, action: action).fontWeight(.semibold)
        }
    }
}

// MARK: - Unsaved changes

extension View {
    /// Asks before throwing away edits when she swipes a sheet down (Sheets, "If people have
    /// unsaved changes … use an action sheet"). The ✕ asks with `discardQuestion` on the
    /// button itself, so on iOS 26 that question points at the ✕.
    func confirmsDiscard(_ isDirty: Bool, onDiscard: @escaping () -> Void) -> some View {
        modifier(DiscardOnSwipe(isDirty: isDirty, onDiscard: onDiscard))
    }

    /// "Discard your changes?" with Discard Changes and Keep Editing. Attach it to the button
    /// that asks.
    func discardQuestion(_ title: String = "Discard your changes?", isAsking: Binding<Bool>,
                         onDiscard: @escaping () -> Void) -> some View {
        confirmationDialog(title, isPresented: isAsking, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive, action: onDiscard)
            Button("Keep Editing", role: .cancel) {}
        }
    }
}

private struct DiscardOnSwipe: ViewModifier {
    let isDirty: Bool
    let onDiscard: () -> Void
    @State private var asking = false

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(isDirty)
            .background(DismissAttemptDetector { if isDirty { asking = true } })
            .discardQuestion(isAsking: $asking, onDiscard: onDiscard)
    }
}

/// Learns when someone tries to swipe down a sheet that can't close, by sitting in front of
/// SwiftUI's own presentation delegate and passing every call on to it.
private struct DismissAttemptDetector: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Detector { Detector(onAttempt: onAttempt) }

    func updateUIViewController(_ controller: Detector, context: Context) {
        controller.onAttempt = onAttempt
    }

    final class Detector: UIViewController, UIAdaptivePresentationControllerDelegate {
        var onAttempt: () -> Void
        private weak var original: UIAdaptivePresentationControllerDelegate?

        init(onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            var top: UIViewController = self
            while let parent = top.parent { top = parent }
            guard let presentation = top.presentationController, presentation.delegate !== self else { return }
            original = presentation.delegate
            presentation.delegate = self
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidAttemptToDismiss?(presentationController)
            onAttempt()
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            original?.presentationControllerShouldDismiss?(presentationController) ?? true
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerWillDismiss?(presentationController)
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidDismiss?(presentationController)
        }
    }
}

// MARK: - Keyboard

/// What a number field accepts. The number pads only type digits (and a decimal point), but
/// a hardware keyboard or a paste can put anything in, so the text is cleaned as it changes.
enum NumericInput {
    /// Whole numbers: digits only.
    case whole
    /// Dollars or a percent: digits and one decimal point, at most two digits after it.
    case decimal

    func clean(_ text: String) -> String {
        switch self {
        case .whole:
            return String(text.filter { $0.isASCII && $0.isNumber })
        case .decimal:
            var result = ""
            var seenPoint = false
            var decimals = 0
            for c in text {
                if c.isASCII && c.isNumber {
                    if seenPoint {
                        guard decimals < 2 else { continue }
                        decimals += 1
                    }
                    result.append(c)
                } else if c == ".", !seenPoint {
                    seenPoint = true
                    result.append(c)
                }
            }
            return result
        }
    }
}

extension View {
    func numericInput(_ text: Binding<String>, _ kind: NumericInput) -> some View {
        onChange(of: text.wrappedValue, initial: true) { _, new in
            let clean = kind.clean(new)
            if clean != new { text.wrappedValue = clean }
        }
    }

    /// Tapping outside a text field puts the keyboard away, and a field that gets the keyboard
    /// is scrolled clear of it. Installed once, on the app's window.
    func keyboardHandling() -> some View {
        background(KeyboardAssistant.Installer())
    }
}

/// The number pads have no Return or Done key; she puts the keyboard away by tapping
/// anywhere else, as in Apple's own apps. When a field gets the keyboard, its whole row (not
/// just the text) is scrolled above it with a little room to spare.
@MainActor final class KeyboardAssistant: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardAssistant()

    private weak var window: UIWindow?
    private weak var field: UIView?
    /// In screen coordinates, while the keyboard is showing.
    private var keyboardFrame: CGRect?
    /// Space left between the row and the top of the keyboard.
    private let margin: CGFloat = 16

    struct Installer: UIViewRepresentable {
        func makeUIView(context: Context) -> Probe {
            let probe = Probe()
            probe.isUserInteractionEnabled = false
            return probe
        }
        func updateUIView(_ view: Probe, context: Context) {}

        final class Probe: UIView {
            override func didMoveToWindow() {
                super.didMoveToWindow()
                if let window { KeyboardAssistant.shared.install(in: window) }
            }
        }
    }

    private func install(in window: UIWindow) {
        guard self.window !== window else { return }
        self.window = window
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        window.addGestureRecognizer(tap)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardDidChange(_:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        center.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        center.addObserver(self, selector: #selector(editingBegan(_:)), name: UITextField.textDidBeginEditingNotification, object: nil)
        center.addObserver(self, selector: #selector(editingBegan(_:)), name: UITextView.textDidBeginEditingNotification, object: nil)
    }

    // MARK: Taps

    private enum TapAction {
        case focus(UITextField)
        case dismiss(UIView)
    }

    private var pending: TapAction?

    @objc private func tapped() {
        switch pending {
        case .focus(let target):
            target.becomeFirstResponder()
        case .dismiss(let editing):
            // Wait for the tap to land: if it moved her into another field, keep the keyboard.
            // Putting it away at once would undo the move.
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                if editing === field, editing.isFirstResponder { window?.endEditing(true) }
            }
        case nil:
            break
        }
        pending = nil
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        pending = nil
        // The bars run their own controls, search included; putting the keyboard away under
        // the search field's ✕ left search half closed (Oct 8, 2026).
        var bar = touch.view
        while let v = bar {
            if v is UINavigationBar || v is UIToolbar || v is UITabBar || v is UISearchBar { return false }
            bar = v.superview
        }
        if let target = missedField(touch) {
            pending = .focus(target)
            return true
        }
        guard keyboardFrame != nil, let field, field.isFirstResponder else { return false }
        // A tap in the field's own row moves the cursor; a tap in any other field moves to it.
        if let cell = cell(of: touch.view), field.isDescendant(of: cell) { return false }
        if field.bounds.insetBy(dx: -8, dy: -8).contains(touch.location(in: field)) { return false }
        var view = touch.view
        while let v = view {
            if v is UITextField || v is UITextView { return false }
            view = v.superview
        }
        pending = .dismiss(field)
        return true
    }

    /// A tap in a form row with one text field that misses the field itself. SwiftUI sizes a
    /// field to its text, so in a 56-point row only the middle 26 points took the tap; the
    /// rest of the row, and its label, now do too. Taps beside the field, where a row keeps
    /// its own buttons (the stepper, Reset), are left alone.
    private func missedField(_ touch: UITouch) -> UITextField? {
        var view = touch.view
        while let v = view, !(v is UICollectionViewCell || v is UITableViewCell) {
            if v is UITextField || v is UITextView || v is UIControl { return nil }
            view = v.superview
        }
        guard let cell = view else { return nil }
        let fields = textFields(in: cell)
        guard fields.count == 1, let target = fields.first, target.isEnabled, !target.isFirstResponder else { return nil }
        let point = touch.location(in: target)
        guard point.x <= target.bounds.maxX, !target.bounds.contains(point) else { return nil }
        return target
    }

    private func textFields(in view: UIView) -> [UITextField] {
        (view as? UITextField).map { [$0] } ?? view.subviews.flatMap(textFields)
    }

    private func cell(of view: UIView?) -> UIView? {
        var view = view
        while let v = view {
            if v is UICollectionViewCell || v is UITableViewCell { return v }
            view = v.superview
        }
        return nil
    }

    func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // MARK: Keep the field clear of the keyboard

    @objc private func keyboardDidShow(_ note: Notification) {
        keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        reveal()
    }

    /// The number pad and the full keyboard differ in height; only tracked while showing.
    @objc private func keyboardDidChange(_ note: Notification) {
        guard keyboardFrame != nil else { return }
        keyboardFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
    }

    @objc private func keyboardWillHide() {
        keyboardFrame = nil
    }

    @objc private func editingBegan(_ note: Notification) {
        field = note.object as? UIView
        // Moving between fields with the keyboard already up: let the system scroll first.
        guard keyboardFrame != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            reveal()
        }
    }

    private func reveal() {
        guard let field, let window = field.window, let keyboardFrame else { return }
        // The row the field sits in, so the whole row clears the keyboard.
        var row: UIView = field
        var scrollView: UIScrollView?
        var view = field.superview
        while let v = view {
            if row === field, v is UICollectionViewCell || v is UITableViewCell { row = v }
            if let s = v as? UIScrollView, !(s is UITextView), s.contentSize.height > s.bounds.height || s is UICollectionView {
                scrollView = s
                break
            }
            view = v.superview
        }
        guard let scrollView else { return }
        let keyboardTop = window.convert(keyboardFrame, from: window.screen.coordinateSpace).minY
        let rowBottom = row.convert(row.bounds, to: window).maxY
        let overlap = rowBottom + margin - keyboardTop
        guard overlap > 0 else { return }
        let maxOffset = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
        let target = min(scrollView.contentOffset.y + overlap, maxOffset)
        guard target > scrollView.contentOffset.y else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: target), animated: true)
    }
}

// MARK: - Large text

/// Rows that put their parts side by side at normal text sizes and stack them at the
/// accessibility sizes, so nothing is cut off (Typography, "Consider adjusting your layout
/// at large font sizes").
struct AdaptiveRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    var spacing: CGFloat = 12
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                leading()
                trailing()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: spacing) {
                leading()
                Spacer(minLength: 4)
                trailing()
            }
        }
    }
}

/// A photo or icon beside its text that moves above it at the accessibility sizes, so the
/// text keeps the full width and long numbers don't break mid-word.
struct IconTextStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    var spacing: CGFloat = 12
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = size.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout(content)
    }
}

// MARK: - Tips

/// Typing an order line is faster than tapping through shapes (Offering help, "Creating tips").
struct TypeOrderTip: Tip {
    var title: Text { Text("Type the Order Line") }
    var message: Text? { Text("Type something like “12 red hearts @ $4” to find the button and fill in the quantity and price.") }
    var image: Image? { Image(systemName: "keyboard") }
}

/// Repeat orders start from a past invoice.
struct RepeatOrderTip: Tip {
    var title: Text { Text("Repeat an Order") }
    var message: Text? { Text("Touch and hold an invoice, then choose Duplicate to start a new one with the same buttons.") }
    var image: Image? { Image(systemName: "plus.square.on.square") }
}

// MARK: - Haptics

extension View {
    /// The success haptic when an invoice is finished; used nowhere else so it keeps its
    /// meaning (Playing haptics, "Use haptics consistently").
    func finishHaptic(_ trigger: Bool) -> some View {
        sensoryFeedback(.success, trigger: trigger) { old, new in !old && new }
    }
}

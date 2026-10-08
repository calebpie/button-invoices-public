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

    /// Liquid Glass on iOS 26 and later; a filled capsule before that.
    @ViewBuilder func glassProminentButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
    }

    /// A Done button above every keyboard. The number pads have no Return key, so without it
    /// the keyboard covers the rest of the form.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
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
    /// Asks before throwing away edits in a sheet, whether she taps Cancel or swipes the
    /// sheet down (Sheets, "If people have unsaved changes … use an action sheet").
    /// Call `requestDismiss` from the Cancel button.
    func confirmsDiscard(_ isDirty: Bool, isAsking: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        self
            .interactiveDismissDisabled(isDirty)
            .background(DismissAttemptDetector { if isDirty { isAsking.wrappedValue = true } })
            .confirmationDialog("Discard your changes?", isPresented: isAsking, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive, action: onDiscard)
                Button("Keep Editing", role: .cancel) {}
            }
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

import SwiftUI

#if os(macOS)
import AppKit

// NSTextView-backed chat input for macOS.
//
// Why this exists: SwiftUI's `TextField(axis: .vertical)` on macOS routes
// the Return key through AppKit before SwiftUI's `.onSubmit` / `.onKeyPress`
// can reliably distinguish plain Return from Shift+Return, so chat-style
// "Enter to send, Shift+Enter for newline" cannot be implemented from pure
// SwiftUI. Wrapping NSTextView gives us:
//   * Plain Return  → invoke `onSubmit` (no newline inserted)
//   * Shift+Return / Option+Return → insert a newline
//   * The standard AppKit right-click text services menu (Copy / Cut /
//     Paste / Select All / Look Up / Speech / ...) for free.
//   * Auto-growing height reported back to SwiftUI via `contentHeight`.
struct ChatTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var contentHeight: CGFloat
    var font: NSFont
    var textColor: NSColor
    var isEditable: Bool = true
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, contentHeight: $contentHeight, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Canonical NSTextView-in-NSScrollView setup. All configuration is
        // done BEFORE the text view is attached as documentView so AppKit
        // has valid sizes for its first layout pass.
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        // Explicit non-zero initial size; AppKit is unhappy resizing an
        // NSTextView from a genuinely zero frame under autoresizing.
        let initialSize = NSSize(width: 100, height: 22)

        let textView = SubmitOnReturnTextView(
            frame: NSRect(origin: .zero, size: initialSize)
        )
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        if let container = textView.textContainer {
            container.containerSize = NSSize(
                width: initialSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            container.widthTracksTextView = true
            container.lineFragmentPadding = 0
        }

        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesFindPanel = false
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.string = text
        textView.delegate = context.coordinator
        textView.onSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.onSubmit()
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitOnReturnTextView else { return }

        context.coordinator.onSubmit = onSubmit
        textView.onSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.onSubmit()
        }

        if textView.font != font { textView.font = font }
        if textView.textColor != textColor { textView.textColor = textColor }
        if textView.insertionPointColor != textColor {
            textView.insertionPointColor = textColor
        }
        if textView.isEditable != isEditable { textView.isEditable = isEditable }

        if textView.string != text {
            textView.string = text
            // Reset selection so the previous cursor position — which may
            // now be past the end of the (possibly cleared) string — cannot
            // trigger an out-of-range access inside NSTextView layout.
            let end = (text as NSString).length
            textView.setSelectedRange(NSRange(location: end, length: 0))
        }

        // Defer height recalculation to the next runloop so we never mutate
        // the height binding during SwiftUI's current view-update pass.
        DispatchQueue.main.async { context.coordinator.recalcHeight() }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var contentHeight: Binding<CGFloat>
        var onSubmit: () -> Void
        weak var textView: NSTextView?

        init(text: Binding<String>,
             contentHeight: Binding<CGFloat>,
             onSubmit: @escaping () -> Void) {
            self.text = text
            self.contentHeight = contentHeight
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if text.wrappedValue != tv.string {
                text.wrappedValue = tv.string
            }
            recalcHeight()
        }

        // Reports laid-out content height back to SwiftUI so the composer
        // can size its frame between min and max line counts.
        func recalcHeight() {
            guard let tv = textView,
                  let container = tv.textContainer,
                  let layoutManager = tv.layoutManager else { return }
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container)
            let newHeight = ceil(used.height) + tv.textContainerInset.height * 2
            if abs(contentHeight.wrappedValue - newHeight) > 0.5 {
                contentHeight.wrappedValue = newHeight
            }
        }
    }
}

// NSTextView subclass that gives us chat-app Return semantics.
final class SubmitOnReturnTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // keyCode 36 = Return, 76 = keypad Enter
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn {
            let mods = event.modifierFlags
            if mods.contains(.shift) || mods.contains(.option) {
                super.keyDown(with: event) // insert newline
                return
            }
            // Defer to the next runloop tick so any binding writes triggered
            // by the send handler (e.g. clearing `messageText`) don't reach
            // AppKit while we're still unwinding this key event.
            let submit = onSubmit
            DispatchQueue.main.async { submit?() }
            return
        }
        super.keyDown(with: event)
    }
}

#endif

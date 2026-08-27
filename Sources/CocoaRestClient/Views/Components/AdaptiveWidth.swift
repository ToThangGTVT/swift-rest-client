//
//  AdaptiveWidth.swift
//  CocoaRestClient
//

import SwiftUI
import AppKit

/// Reports its own width whenever AppKit resizes it.
///
/// Used as a zero-size `.background` probe to drive a layout breakpoint. The
/// callback is dispatched asynchronously so the SwiftUI state it feeds is never
/// mutated in the middle of a layout pass — doing that from a `GeometryReader`
/// raises an exception inside `NSView` layout and kills the process.
private struct ViewSizeReporter: NSViewRepresentable {
    let onSizeChange: (CGSize) -> Void

    func makeNSView(context: Context) -> NSView {
        ReporterView(onSizeChange: onSizeChange)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ReporterView)?.onSizeChange = onSizeChange
    }

    final class ReporterView: NSView {
        var onSizeChange: (CGSize) -> Void
        private var reported: CGSize = .zero

        init(onSizeChange: @escaping (CGSize) -> Void) {
            self.onSizeChange = onSizeChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("unavailable") }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            report(newSize)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            report(bounds.size)
        }

        private func report(_ size: CGSize) {
            guard size.width > 0, size != reported else { return }
            reported = size
            let callback = onSizeChange
            DispatchQueue.main.async { callback(size) }
        }
    }
}

/// Switches a row to its compact presentation once the row is narrower than
/// `threshold`.
///
/// Deliberately not `ViewThatFits`: that measures every candidate on each layout
/// pass, and a `Menu` candidate means allocating an `NSPopUpButton` and rendering
/// its SF Symbol each time. Profiling a window resize showed the three
/// `ViewThatFits` rows in this app costing ~59 ms of CPU per frame. Here the
/// compact control is built only while it is actually shown, and the flag flips
/// once at the breakpoint instead of on every frame.
struct WidthBreakpoint: ViewModifier {
    let threshold: CGFloat
    let hysteresis: CGFloat
    @Binding var isCompact: Bool

    func body(content: Content) -> some View {
        content.background(
            ViewSizeReporter { size in
                let width = size.width
                // Dead band, not a bare comparison: swapping the segmented picker for
                // the dropdown changes this row's minimum width, and
                // NavigationSplitView feeds that back into the pane width. Measured
                // without hysteresis the row flip-flopped between 845 pt and 902 pt
                // forever, so the layout never settled.
                let limit = isCompact ? threshold + hysteresis : threshold
                let compact = width < limit
                if isCompact != compact { isCompact = compact }
            }
            // The representable would otherwise size itself to its (zero) intrinsic
            // width and report that instead of the row's width.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
    }
}

extension View {
    /// Drives `isCompact` from this view's own width.
    func widthBreakpoint(
        _ threshold: CGFloat,
        hysteresis: CGFloat = 120,
        isCompact: Binding<Bool>
    ) -> some View {
        modifier(WidthBreakpoint(threshold: threshold, hysteresis: hysteresis, isCompact: isCompact))
    }
}

/// Dropdown stand-in for a segmented picker on narrow rows.
struct CompactOptionMenu<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack {
                        Text(title(option))
                        if selection == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title(selection))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

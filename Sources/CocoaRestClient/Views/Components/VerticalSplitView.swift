//
//  VerticalSplitView.swift
//  CocoaRestClient
//

import SwiftUI
import AppKit

/// Two vertically stacked panes with a draggable divider.
///
/// Replaces SwiftUI's `VSplitView`, which does not lay itself out to the width it is
/// offered: measured at a 920 pt window it came out 838 pt wide — an 82 pt gap at the
/// right edge that grew as the window narrowed — and adding `maxWidth: .infinity`
/// flipped it to 1002 pt, overflowing by the same amount. It never matched the
/// container.
///
/// The split is done with a `Layout` rather than by measuring the container into
/// `@State`: the layout already receives the container's bounds, so there is no
/// size-report-then-relayout cycle to oscillate. The drag reads the pointer position
/// in the container's own coordinate space, so it needs no height of its own.
struct VerticalSplitView<Top: View, Bottom: View>: View {
    let minTopHeight: CGFloat
    let minBottomHeight: CGFloat
    let initialTopFraction: CGFloat
    @ViewBuilder let top: () -> Top
    @ViewBuilder let bottom: () -> Bottom

    private static var dividerHeight: CGFloat { 7 }
    private static var coordinateSpace: String { "VerticalSplitView" }

    @State private var requestedTopHeight: CGFloat?

    init(
        minTopHeight: CGFloat,
        minBottomHeight: CGFloat,
        initialTopFraction: CGFloat = 0.5,
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.minTopHeight = minTopHeight
        self.minBottomHeight = minBottomHeight
        self.initialTopFraction = initialTopFraction
        self.top = top
        self.bottom = bottom
    }

    var body: some View {
        SplitLayout(
            requestedTopHeight: requestedTopHeight,
            minTopHeight: minTopHeight,
            minBottomHeight: minBottomHeight,
            dividerHeight: Self.dividerHeight,
            initialTopFraction: initialTopFraction
        ) {
            top()
            divider
            bottom()
        }
        .coordinateSpace(name: Self.coordinateSpace)
    }

    private var divider: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(Color(NSColor.separatorColor))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                .onChanged { value in
                    // Pointer position within the split, so no container height needed.
                    requestedTopHeight = value.location.y - Self.dividerHeight / 2
                }
        )
    }
}

private struct SplitLayout: Layout {
    let requestedTopHeight: CGFloat?
    let minTopHeight: CGFloat
    let minBottomHeight: CGFloat
    let dividerHeight: CGFloat
    let initialTopFraction: CGFloat

    /// Height for the top pane, clamped so neither pane drops below its minimum.
    static func topHeight(
        requested: CGFloat?,
        containerHeight: CGFloat,
        dividerHeight: CGFloat,
        minTop: CGFloat,
        minBottom: CGFloat,
        initialTopFraction: CGFloat
    ) -> CGFloat {
        let usable = containerHeight - dividerHeight
        guard usable > 0 else { return 0 }
        // Too short for both minimums: keep the top pane at its minimum (bounded by
        // what exists) and let the bottom take the remainder.
        guard usable > minTop + minBottom else { return min(minTop, usable) }
        let target = requested ?? usable * initialTopFraction
        return min(max(target, minTop), usable - minBottom)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 600, height: 400))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let topH = Self.topHeight(
            requested: requestedTopHeight,
            containerHeight: bounds.height,
            dividerHeight: dividerHeight,
            minTop: minTopHeight,
            minBottom: minBottomHeight,
            initialTopFraction: initialTopFraction
        )
        let bottomH = max(0, bounds.height - dividerHeight - topH)

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: bounds.width, height: topH))
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + topH),
            proposal: ProposedViewSize(width: bounds.width, height: dividerHeight))
        subviews[2].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + topH + dividerHeight),
            proposal: ProposedViewSize(width: bounds.width, height: bottomH))
    }
}

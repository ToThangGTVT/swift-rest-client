//
//  SyntaxTextEditorView.swift
//  CocoaRestClient
//

import SwiftUI
import AppKit
import CocoaRestClientCore

public struct SyntaxTextEditorView: NSViewRepresentable {
    @Binding public var text: String
    public var isEditable: Bool
    public var fontSize: CGFloat
    public var showLineNumbers: Bool

    public init(
        text: Binding<String>,
        isEditable: Bool = true,
        fontSize: CGFloat = 13.0,
        showLineNumbers: Bool = true
    ) {
        self._text = text
        self.isEditable = isEditable
        self.fontSize = fontSize
        self.showLineNumbers = showLineNumbers
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Enforce word wrapping always
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.delegate = context.coordinator

        if let container = textView.textContainer {
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
            container.lineFragmentPadding = 4
        }
        textView.textContainerInset = NSSize(width: 12, height: 8)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        if showLineNumbers {
            let rulerView = LineNumberRulerView(textView: textView, fontSize: fontSize)
            scrollView.verticalRulerView = rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            context.coordinator.rulerView = rulerView
        }

        let attributed = SyntaxHighlighter.highlight(
            text: text,
            fontSize: fontSize,
            appearance: textView.effectiveAppearance
        )
        textView.textStorage?.setAttributedString(attributed)
        context.coordinator.appliedText = text
        context.coordinator.rulerView?.rebuildLineCache()
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        let currentFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fontChanged = currentFont.pointSize != fontSize

        // Compare against the last string we applied, not against textView.string:
        // when the value comes from a cached source the two share storage and the
        // check is O(1) instead of a full character comparison on every layout pass.
        if context.coordinator.appliedText != text || fontChanged {
            let attributed = SyntaxHighlighter.highlight(
                text: text,
                fontSize: fontSize,
                appearance: textView.effectiveAppearance
            )
            textView.textStorage?.setAttributedString(attributed)
            context.coordinator.appliedText = text
            if fontChanged {
                context.coordinator.rulerView?.updateFont(size: max(9.0, fontSize - 2.0))
            }
            context.coordinator.rulerView?.rebuildLineCache()
        }
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditorView
        weak var textView: NSTextView?
        weak var rulerView: LineNumberRulerView?
        /// Last string handed to the text storage; used to skip redundant re-highlighting.
        var appliedText: String = ""

        init(_ parent: SyntaxTextEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newValue = textView.string
            appliedText = newValue
            parent.text = newValue
            rulerView?.rebuildLineCache()
        }
    }
}

public final class LineNumberRulerView: NSRulerView {
    private var rulerFont: NSFont

    /// UTF-16 offset of the first character of every logical line.
    /// Rebuilt only when the text changes, never while drawing.
    private var lineStarts: [Int] = [0]
    private var cachedTextLength: Int = 0

    public init(textView: NSTextView, fontSize: CGFloat = 13.0) {
        self.rulerFont = NSFont.monospacedDigitSystemFont(ofSize: max(9.0, fontSize - 2.0), weight: .regular)
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 42.0

        NotificationCenter.default.addObserver(self, selector: #selector(textChanged), name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(redrawRuler), name: NSView.frameDidChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(redrawRuler), name: NSView.boundsDidChangeNotification, object: textView.enclosingScrollView?.contentView)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func updateFont(size: CGFloat) {
        self.rulerFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        needsDisplay = true
    }

    @objc private func textChanged() {
        rebuildLineCache()
    }

    @objc private func redrawRuler() {
        needsDisplay = true
    }

    /// Scans the document once for line breaks and resizes the gutter accordingly.
    /// Called on text changes only — the draw path never does O(document) work.
    public func rebuildLineCache() {
        guard let textView = clientView as? NSTextView else { return }
        let nsString = textView.string as NSString
        let length = nsString.length
        cachedTextLength = length

        var starts: [Int] = [0]
        starts.reserveCapacity(max(16, length / 40))
        if length > 0 {
            let chunkSize = 8192
            var buffer = [unichar](repeating: 0, count: min(length, chunkSize))
            var offset = 0
            while offset < length {
                let count = min(chunkSize, length - offset)
                nsString.getCharacters(&buffer, range: NSRange(location: offset, length: count))
                for i in 0..<count where buffer[i] == 10 {
                    starts.append(offset + i + 1)
                }
                offset += count
            }
        }
        lineStarts = starts

        // Gutter width depends on the total line count only, so it settles once
        // instead of being re-derived (and re-triggering layout) from the scroll
        // position on every draw.
        let requiredWidth = max(42.0, CGFloat("\(starts.count)".count) * 8.5 + 18.0)
        if abs(ruleThickness - requiredWidth) > 2.0 {
            ruleThickness = requiredWidth
        }
        needsDisplay = true
    }

    /// Index of the line containing `charIndex` (binary search over `lineStarts`).
    private func lineIndex(containing charIndex: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= charIndex {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    public override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Background
        let bgColor = ColorSchemeHelper.rulerBackgroundColor
        bgColor.setFill()
        bounds.fill()

        // Right divider line (very soft and subtle)
        let separatorColor = NSColor.separatorColor.withAlphaComponent(0.12)
        separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.lineWidth = 0.5
        path.stroke()

        let textString = textView.string as NSString
        let textLength = textString.length

        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: rulerFont,
            .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.5)
        ]

        let inset = textView.textContainerInset.height

        guard textLength > 0 else {
            let str = "1" as NSString
            let strSize = str.size(withAttributes: numAttrs)
            str.draw(at: NSPoint(x: bounds.width - strSize.width - 8, y: inset), withAttributes: numAttrs)
            return
        }

        // Safety net: the cache should already be current, but never draw stale numbers.
        if cachedTextLength != textLength {
            rebuildLineCache()
        }

        let visibleRect = scrollView?.contentView.bounds ?? textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        let endCharIndex = NSMaxRange(visibleCharRange)

        var index = lineIndex(containing: visibleCharRange.location)
        while index < lineStarts.count {
            let lineStart = lineStarts[index]
            if lineStart > endCharIndex { break }
            // A trailing newline produces a final entry at `textLength`; that line is
            // drawn from the extra line fragment below.
            if lineStart >= textLength { break }

            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineStart)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let lineStr = "\(index + 1)" as NSString
            let strSize = lineStr.size(withAttributes: numAttrs)
            lineStr.draw(
                at: NSPoint(x: bounds.width - strSize.width - 8, y: lineRect.origin.y + inset),
                withAttributes: numAttrs
            )
            index += 1
        }

        if textString.character(at: textLength - 1) == 10 {
            let lineRect = layoutManager.extraLineFragmentRect
            let lineStr = "\(lineStarts.count)" as NSString
            let strSize = lineStr.size(withAttributes: numAttrs)
            lineStr.draw(
                at: NSPoint(x: bounds.width - strSize.width - 8, y: lineRect.origin.y + inset),
                withAttributes: numAttrs
            )
        }
    }
}

private struct ColorSchemeHelper {
    static var rulerBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)
            } else {
                return NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
            }
        }
    }
}

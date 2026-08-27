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
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        let currentFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fontChanged = currentFont.pointSize != fontSize

        if textView.string != text || fontChanged {
            let attributed = SyntaxHighlighter.highlight(
                text: text,
                fontSize: fontSize,
                appearance: textView.effectiveAppearance
            )
            textView.textStorage?.setAttributedString(attributed)
            context.coordinator.rulerView?.needsDisplay = true
            if fontChanged {
                context.coordinator.rulerView?.updateFont(size: max(9.0, fontSize - 2.0))
            }
        }
        textView.isEditable = isEditable
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditorView
        weak var textView: NSTextView?
        weak var rulerView: LineNumberRulerView?

        init(_ parent: SyntaxTextEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            rulerView?.needsDisplay = true
        }
    }
}

public final class LineNumberRulerView: NSRulerView {
    private var rulerFont: NSFont

    public init(textView: NSTextView, fontSize: CGFloat = 13.0) {
        self.rulerFont = NSFont.monospacedDigitSystemFont(ofSize: max(9.0, fontSize - 2.0), weight: .regular)
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 42.0
        
        NotificationCenter.default.addObserver(self, selector: #selector(redrawRuler), name: NSText.didChangeNotification, object: textView)
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

    @objc private func redrawRuler() {
        needsDisplay = true
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

        let visibleRect = scrollView?.contentView.bounds ?? textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)

        let textString = textView.string as NSString
        let textLength = textString.length

        let numAttrs: [NSAttributedString.Key: Any] = [
            .font: rulerFont,
            .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.5)
        ]

        guard textLength > 0 else {
            let str = "1" as NSString
            let strSize = str.size(withAttributes: numAttrs)
            let y = textView.textContainerInset.height
            str.draw(at: NSPoint(x: bounds.width - strSize.width - 8, y: y), withAttributes: numAttrs)
            return
        }

        // Count lines up to start of visible range
        var lineNumber = 1
        var index = 0
        let startCharIndex = visibleCharRange.location

        while index < startCharIndex && index < textLength {
            index = NSMaxRange(textString.lineRange(for: NSRange(location: index, length: 0)))
            lineNumber += 1
        }

        // Estimate total lines to size thickness
        let totalLinesEstimate = max(lineNumber + 50, (textString.components(separatedBy: "\n").count))
        let requiredWidth = max(42.0, CGFloat("\(totalLinesEstimate)".count) * 8.5 + 18.0)
        if abs(self.ruleThickness - requiredWidth) > 2.0 {
            DispatchQueue.main.async {
                self.ruleThickness = requiredWidth
            }
        }

        var charIndex = startCharIndex
        let endCharIndex = NSMaxRange(visibleCharRange)

        while charIndex <= endCharIndex && charIndex < textLength {
            let lineRange = textString.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let yPos = lineRect.origin.y + textView.textContainerInset.height

            let lineStr = "\(lineNumber)" as NSString
            let strSize = lineStr.size(withAttributes: numAttrs)
            let xPos = bounds.width - strSize.width - 8
            
            lineStr.draw(at: NSPoint(x: xPos, y: yPos), withAttributes: numAttrs)

            lineNumber += 1
            charIndex = NSMaxRange(lineRange)
        }

        if textLength > 0 && textString.character(at: textLength - 1) == 10 {
            let lineRect = layoutManager.extraLineFragmentRect
            let yPos = lineRect.origin.y + textView.textContainerInset.height
            let lineStr = "\(lineNumber)" as NSString
            let strSize = lineStr.size(withAttributes: numAttrs)
            let xPos = bounds.width - strSize.width - 8
            lineStr.draw(at: NSPoint(x: xPos, y: yPos), withAttributes: numAttrs)
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

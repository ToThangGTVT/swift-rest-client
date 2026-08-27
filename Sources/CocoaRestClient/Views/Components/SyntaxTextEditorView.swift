//
//  SyntaxTextEditorView.swift
//  CocoaRestClientApp
//

import SwiftUI
import AppKit

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
        scrollView.hasHorizontalScroller = true
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
        
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        textView.delegate = context.coordinator
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        
        textView.string = text
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = isEditable
        let currentFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if currentFont.pointSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxTextEditorView
        weak var textView: NSTextView?

        init(_ parent: SyntaxTextEditorView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

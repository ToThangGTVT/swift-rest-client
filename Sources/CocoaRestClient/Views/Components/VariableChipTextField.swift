//
//  VariableChipTextField.swift
//  CocoaRestClient
//

import SwiftUI
import AppKit

extension NSAttributedString.Key {
    /// Fill colour of the rounded chip drawn behind an environment-variable token.
    static let variableChipFill = NSAttributedString.Key("CRCVariableChipFill")
}

/// Styles `{{name}}` and `${name}` tokens so they read as chips.
///
/// Tokens that the active environment can resolve get the accent colour; unknown
/// ones get red, which is the whole point of showing them inline -- a typo in a
/// variable name is otherwise invisible until the request fails.
enum VariableChipStyler {
    private static let tokenPattern = try! NSRegularExpression(
        pattern: #"\{\{[^{}]*\}\}|\$\{[^{}]*\}"#
    )

    /// Variable name inside a `{{...}}` / `${...}` token.
    static func name(in token: String) -> String {
        let body = token.hasPrefix("{{")
            ? token.dropFirst(2).dropLast(2)
            : token.dropFirst(2).dropLast(1)
        return body.trimmingCharacters(in: .whitespaces)
    }

    static func apply(to storage: NSTextStorage, font: NSFont, environment: [String: String]) {
        let full = NSRange(location: 0, length: storage.length)
        let text = storage.string as NSString

        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: full)

        for match in tokenPattern.matches(in: storage.string, range: full) {
            let resolved = environment[name(in: text.substring(with: match.range))] != nil
            let tint: NSColor = resolved ? .controlAccentColor : .systemRed
            storage.addAttributes(
                [
                    .variableChipFill: tint.withAlphaComponent(0.16),
                    .foregroundColor: tint
                ],
                range: match.range
            )
        }
        storage.endEditing()
    }
}

/// Draws the chip backgrounds. A plain `.backgroundColor` attribute would do the
/// job but paints hard square edges; chips need a rounded rect, and only the
/// layout manager knows where the glyphs landed.
private final class ChipLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        if let storage = textStorage, let container = textContainers.first {
            let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
            storage.enumerateAttribute(.variableChipFill, in: charRange) { value, range, _ in
                guard let fill = value as? NSColor else { return }
                let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                self.enumerateEnclosingRects(
                    forGlyphRange: glyphRange,
                    withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                    in: container
                ) { rect, _ in
                    let chip = rect.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -2, dy: -1)
                    fill.setFill()
                    NSBezierPath(roundedRect: chip, xRadius: 4, yRadius: 4).fill()
                }
            }
        }
        // After ours, so the selection highlight stays on top of the chips.
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    }
}

private final class ChipTextView: NSTextView {
    var onSubmit: () -> Void = {}

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            onSubmit()
        case #selector(NSResponder.insertTab(_:)):
            window?.selectNextKeyView(nil)
        case #selector(NSResponder.insertBacktab(_:)):
            window?.selectPreviousKeyView(nil)
        default:
            super.doCommand(by: selector)
        }
    }
}

/// Keeps the text view filling the clip view.
///
/// A horizontally resizable NSTextView sizes itself to its text, so in a short URL
/// it only covers the first few characters: clicks anywhere else in the box land on
/// the clip view and never reach the editor. Growing it to the clip view's size
/// makes the whole field clickable while long URLs still overflow and scroll.
private final class ChipScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let available = contentSize
        guard available.width > 0, available.height > 0 else { return }

        // Centre the single line vertically in the field.
        let font = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let lineHeight = textView.layoutManager?.defaultLineHeight(for: font) ?? available.height
        let inset = max(0, (available.height - lineHeight) / 2)
        if abs(textView.textContainerInset.height - inset) > 0.5 {
            textView.textContainerInset = NSSize(width: 0, height: inset)
        }

        textView.minSize = available
        let target = NSSize(
            width: max(textView.frame.width, available.width),
            height: max(textView.frame.height, available.height)
        )
        if textView.frame.size != target {
            textView.setFrameSize(target)
        }
    }
}

/// Single-line field that renders environment variables as chips while you type.
struct VariableChipTextField: NSViewRepresentable {
    @Binding var text: String
    var environment: [String: String]
    var fontSize: CGFloat = 13.0
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        // Built by hand rather than with NSTextView(): passing an explicit container
        // keeps the view on TextKit 1, which is what ChipLayoutManager hooks into.
        let storage = NSTextStorage()
        let layoutManager = ChipLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let textView = ChipTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = .zero
        textView.font = Self.font(size: fontSize)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        let scrollView = ChipScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .none

        storage.setAttributedString(NSAttributedString(string: text))
        context.coordinator.restyle(textView, environment: environment, fontSize: fontSize)
        context.coordinator.appliedText = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ChipTextView else { return }
        context.coordinator.parent = self
        textView.onSubmit = onSubmit

        if context.coordinator.appliedText != text {
            let selection = textView.selectedRange()
            textView.textStorage?.setAttributedString(NSAttributedString(string: text))
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
            context.coordinator.appliedText = text
            context.coordinator.restyle(textView, environment: environment, fontSize: fontSize)
        } else if context.coordinator.appliedEnvironment != environment {
            // Switching environments turns unknown variables into known ones and back.
            context.coordinator.restyle(textView, environment: environment, fontSize: fontSize)
        }
    }

    static func font(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VariableChipTextField
        var appliedText: String = ""
        var appliedEnvironment: [String: String] = [:]

        init(_ parent: VariableChipTextField) {
            self.parent = parent
        }

        func restyle(_ textView: NSTextView, environment: [String: String], fontSize: CGFloat) {
            guard let storage = textView.textStorage else { return }
            let font = VariableChipTextField.font(size: fontSize)
            VariableChipStyler.apply(to: storage, font: font, environment: environment)
            // Otherwise a character typed right after a chip inherits its colour.
            textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
            appliedEnvironment = environment
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? ChipTextView else { return }

            // The field is single-line; a pasted cURL command arrives with newlines.
            let flattened = textView.string
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            if flattened != textView.string {
                let caret = textView.selectedRange().location
                textView.string = flattened
                textView.setSelectedRange(
                    NSRange(location: min(caret, (flattened as NSString).length), length: 0)
                )
            }

            restyle(textView, environment: parent.environment, fontSize: parent.fontSize)

            guard flattened != appliedText else { return }
            appliedText = flattened
            parent.text = flattened
        }
    }
}

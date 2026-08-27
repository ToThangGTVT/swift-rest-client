//
//  SyntaxHighlighter.swift
//  CocoaRestClientCore
//

#if canImport(AppKit)
import AppKit

public struct SyntaxHighlighter: Sendable {
    public init() {}

    public static func highlight(
        text: String,
        fontSize: CGFloat = 13.0,
        appearance: NSAppearance? = nil
    ) -> NSAttributedString {
        guard !text.isEmpty else {
            return NSAttributedString(string: "")
        }

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        
        let isDark = (appearance ?? NSApp?.effectiveAppearance)?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        // Colors
        let defaultColor = isDark ? NSColor(white: 0.9, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
        let keyColor = isDark ? NSColor(calibratedRed: 0.45, green: 0.75, blue: 1.0, alpha: 1.0) : NSColor(calibratedRed: 0.12, green: 0.40, blue: 0.78, alpha: 1.0)
        let stringColor = isDark ? NSColor(calibratedRed: 0.58, green: 0.88, blue: 0.55, alpha: 1.0) : NSColor(calibratedRed: 0.18, green: 0.58, blue: 0.28, alpha: 1.0)
        let numberColor = isDark ? NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.40, alpha: 1.0) : NSColor(calibratedRed: 0.82, green: 0.42, blue: 0.08, alpha: 1.0)
        let boolColor = isDark ? NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.92, alpha: 1.0) : NSColor(calibratedRed: 0.70, green: 0.18, blue: 0.70, alpha: 1.0)
        let punctuationColor = isDark ? NSColor(white: 0.65, alpha: 1.0) : NSColor(white: 0.45, alpha: 1.0)

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: defaultColor
            ]
        )

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // Check if JSON
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isJson = (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))

        if isJson {
            highlightJson(
                attributed: attributed,
                nsString: nsString,
                fullRange: fullRange,
                font: font,
                boldFont: boldFont,
                keyColor: keyColor,
                stringColor: stringColor,
                numberColor: numberColor,
                boolColor: boolColor,
                punctuationColor: punctuationColor
            )
        } else if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
            highlightXml(
                attributed: attributed,
                nsString: nsString,
                fullRange: fullRange,
                font: font,
                boldFont: boldFont,
                tagColor: keyColor,
                attrColor: numberColor,
                stringColor: stringColor,
                commentColor: punctuationColor
            )
        }

        return attributed
    }

    private static func highlightJson(
        attributed: NSMutableAttributedString,
        nsString: NSString,
        fullRange: NSRange,
        font: NSFont,
        boldFont: NSFont,
        keyColor: NSColor,
        stringColor: NSColor,
        numberColor: NSColor,
        boolColor: NSColor,
        punctuationColor: NSColor
    ) {
        // 1. Strings (Keys and String Values)
        let stringPattern = #"\"([^\"\\]|\\.)*\""#
        if let stringRegex = try? NSRegularExpression(pattern: stringPattern, options: []) {
            let matches = stringRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                let range = match.range
                // Check if followed by colon ':' (with optional whitespace)
                let afterLocation = NSMaxRange(range)
                var isKey = false
                if afterLocation < nsString.length {
                    var checkIdx = afterLocation
                    while checkIdx < nsString.length {
                        let ch = nsString.character(at: checkIdx)
                        if ch == 58 /* ':' */ {
                            isKey = true
                            break
                        } else if ch == 32 || ch == 9 || ch == 10 || ch == 13 /* whitespace */ {
                            checkIdx += 1
                        } else {
                            break
                        }
                    }
                }

                if isKey {
                    attributed.addAttribute(.foregroundColor, value: keyColor, range: range)
                    attributed.addAttribute(.font, value: boldFont, range: range)
                } else {
                    attributed.addAttribute(.foregroundColor, value: stringColor, range: range)
                }
            }
        }

        // 2. Numbers
        let numberPattern = #"(?<=[\s:\[,])-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?(?=[\s,\}\]]|$)"#
        if let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let matches = numberRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: numberColor, range: match.range)
            }
        }

        // 3. Booleans & Null
        let boolPattern = #"\b(true|false|null)\b"#
        if let boolRegex = try? NSRegularExpression(pattern: boolPattern, options: []) {
            let matches = boolRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: boolColor, range: match.range)
                attributed.addAttribute(.font, value: boldFont, range: match.range)
            }
        }

        // 4. Punctuation brackets and colons
        let punctPattern = #"[\{\}\[\]\:,]"#
        if let punctRegex = try? NSRegularExpression(pattern: punctPattern, options: []) {
            let matches = punctRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: punctuationColor, range: match.range)
            }
        }
    }

    private static func highlightXml(
        attributed: NSMutableAttributedString,
        nsString: NSString,
        fullRange: NSRange,
        font: NSFont,
        boldFont: NSFont,
        tagColor: NSColor,
        attrColor: NSColor,
        stringColor: NSColor,
        commentColor: NSColor
    ) {
        // XML Tags
        let tagPattern = #"</?([a-zA-Z0-9_\-:]+)(?:\s+[^>]*)?/?>"#
        if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let matches = tagRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: tagColor, range: match.range)
            }
        }

        // XML Attribute values
        let attrValPattern = #"\"([^\"\\]|\\.)*\""#
        if let attrValRegex = try? NSRegularExpression(pattern: attrValPattern, options: []) {
            let matches = attrValRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: stringColor, range: match.range)
            }
        }

        // Comments
        let commentPattern = #"<!--[\s\S]*?-->"#
        if let commentRegex = try? NSRegularExpression(pattern: commentPattern, options: []) {
            let matches = commentRegex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(.foregroundColor, value: commentColor, range: match.range)
            }
        }
    }
}
#endif

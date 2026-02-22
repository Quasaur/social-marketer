//
//  QuoteGraphicGenerator+TextDrawing.swift
//  SocialMarketer
//
//  Text drawing and formatting methods with font caching for performance
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - Font Cache
    
    /// Pre-computed font cache to avoid creating fonts in the loop
    private static let contentFontCache: [CGFloat: [NSAttributedString.Key: Any]] = {
        var cache: [CGFloat: [NSAttributedString.Key: Any]] = [:]
        for size in stride(from: CGFloat(48), through: CGFloat(16), by: -1) {
            let font = NSFont.systemFont(ofSize: size, weight: .regular)
            cache[size] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
        }
        return cache
    }()
    
    // MARK: - Title Drawing
    
    func drawTitle(_ title: String) {
        let cleanTitle = title.replacingOccurrences(
            of: "^Today[''']s Wisdom:\\s*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        let font = NSFont.systemFont(ofSize: 48, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let titleRect = NSRect(x: 80, y: imageSize.height - 200, width: imageSize.width - 160, height: 120)
        cleanTitle.uppercased().draw(in: titleRect, withAttributes: attributes)
    }
    
    // MARK: - Content Drawing (Optimized)
    
    func drawContent(_ content: String) {
        let contentRect = NSRect(x: 80, y: 160, width: imageSize.width - 160, height: imageSize.height - 340)
        
        let maxFont: CGFloat = 48
        let minFont: CGFloat = 16
        
        // Binary search for optimal font size (faster than linear)
        var bestSize = minFont
        var low = Int(minFont)
        var high = Int(maxFont)
        
        while low <= high {
            let mid = (low + high) / 2
            let fontSize = CGFloat(mid)
            
            if fitsInRect(content, rect: contentRect, fontSize: fontSize) {
                bestSize = fontSize
                low = mid + 1  // Try larger
            } else {
                high = mid - 1  // Try smaller
            }
        }
        
        // Draw with best fitting size
        drawFormattedContent(content, in: contentRect, fontSize: bestSize)
    }
    
    /// Check if content fits in rectangle at given font size
    private func fitsInRect(_ content: String, rect: NSRect, fontSize: CGFloat) -> Bool {
        let formatted = formatContentForDisplay(content, targetWidth: rect.width, fontSize: fontSize)
        
        guard let attrs = Self.contentFontCache[fontSize] else { return false }
        
        let lineSpace = max(4, fontSize * 0.3)
        let style = centeredParagraphStyle(lineSpacing: lineSpace)
        var finalAttrs = attrs
        finalAttrs[.paragraphStyle] = style
        
        let boundingRect = (formatted as NSString).boundingRect(
            with: NSSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: finalAttrs
        )
        
        return boundingRect.height <= rect.height
    }
    
    /// Draw formatted content with specified font size
    private func drawFormattedContent(_ content: String, in rect: NSRect, fontSize: CGFloat) {
        let formatted = formatContentForDisplay(content, targetWidth: rect.width, fontSize: fontSize)
        
        guard let attrs = Self.contentFontCache[fontSize] else { return }
        
        let lineSpace = max(4, fontSize * 0.3)
        let style = centeredParagraphStyle(lineSpacing: lineSpace)
        var finalAttrs = attrs
        finalAttrs[.paragraphStyle] = style
        
        let boundingRect = (formatted as NSString).boundingRect(
            with: NSSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: finalAttrs
        )
        
        let yOffset = (rect.height - boundingRect.height) / 2
        let drawRect = NSRect(
            x: rect.minX,
            y: rect.minY + yOffset,
            width: rect.width,
            height: boundingRect.height + 10
        )
        formatted.draw(in: drawRect, withAttributes: finalAttrs)
    }
    
    // MARK: - Reference & Watermark
    
    func drawReference(_ reference: String) {
        let font = NSFont.systemFont(ofSize: 40, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let refRect = NSRect(x: 80, y: 135, width: imageSize.width - 160, height: 60)
        ("— " + reference).draw(in: refRect, withAttributes: attributes)
    }
    
    func drawWatermark() {
        let font = NSFont.systemFont(ofSize: 36, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let watermarkRect = NSRect(x: 100, y: 80, width: imageSize.width - 200, height: 60)
        watermarkText.draw(in: watermarkRect, withAttributes: attributes)
    }
    
    // MARK: - Text Formatting (Optimized)
    
    /// Smart text formatter that breaks content into readable lines.
    /// Uses NSMutableString for better performance with multiple replacements.
    private func formatContentForDisplay(_ text: String, targetWidth: CGFloat, fontSize: CGFloat) -> String {
        let result = NSMutableString(string: text)
        
        // Batch replacements
        result.replaceOccurrences(of: ". ", with: ".\n", options: [], range: NSRange(location: 0, length: result.length))
        result.replaceOccurrences(of: "; ", with: ";\n", options: [], range: NSRange(location: 0, length: result.length))
        result.replaceOccurrences(of: "? ", with: "?\n", options: [], range: NSRange(location: 0, length: result.length))
        result.replaceOccurrences(of: "! ", with: "!\n", options: [], range: NSRange(location: 0, length: result.length))
        
        // Regex replacement for colon followed by capital letter
        if let regex = try? NSRegularExpression(pattern: ":\\s+([A-Z])") {
            regex.replaceMatches(in: result, options: [], range: NSRange(location: 0, length: result.length), withTemplate: ":\n$1")
        }
        
        if fontSize >= 32 {
            result.replaceOccurrences(of: ", ", with: ",\n", options: [], range: NSRange(location: 0, length: result.length))
        }
        
        if fontSize >= 38 {
            let phraseBreaks = [" and ", " but ", " or ", " for ", " nor ", " yet ", " so ",
                               " that ", " which ", " who ", " when ", " where ", " while ",
                               " because ", " although ", " though ", " unless ", " until ",
                               " before ", " after ", " since ", " through ", " with ", " without ",
                               " upon ", " into ", " onto ", " within ", " between ", " among "]
            for phrase in phraseBreaks {
                let trimmed = phrase.trimmingCharacters(in: .whitespaces)
                result.replaceOccurrences(of: phrase, with: "\n" + trimmed + " ", options: [], range: NSRange(location: 0, length: result.length))
            }
        }
        
        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result.replaceOccurrences(of: "\n\n\n", with: "\n\n", options: [], range: NSRange(location: 0, length: result.length))
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Paragraph Styles
    
    func centeredParagraphStyle(lineSpacing: CGFloat = 4) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = lineSpacing
        return style
    }
    
    func leftAlignedParagraphStyle(lineSpacing: CGFloat = 4) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineSpacing = lineSpacing
        return style
    }
}

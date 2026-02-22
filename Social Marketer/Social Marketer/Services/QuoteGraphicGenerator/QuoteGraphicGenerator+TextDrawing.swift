//
//  QuoteGraphicGenerator+TextDrawing.swift
//  SocialMarketer
//
//  Text drawing and formatting methods for QuoteGraphicGenerator
//

import AppKit

extension QuoteGraphicGenerator {
    
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
    
    func drawContent(_ content: String) {
        let contentRect = NSRect(x: 80, y: 160, width: imageSize.width - 160, height: imageSize.height - 340)
        
        let maxFont: CGFloat = 48
        let minFont: CGFloat = 16
        var fontSize = maxFont
        
        while fontSize >= minFont {
            let formatted = formatContentForDisplay(content, targetWidth: contentRect.width, fontSize: fontSize)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let lineSpace = max(4, fontSize * 0.3)
            let style = centeredParagraphStyle(lineSpacing: lineSpace)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: style
            ]
            let boundingRect = (formatted as NSString).boundingRect(
                with: NSSize(width: contentRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            if boundingRect.height <= contentRect.height {
                let yOffset = (contentRect.height - boundingRect.height) / 2
                let drawRect = NSRect(x: contentRect.minX,
                                      y: contentRect.minY + yOffset,
                                      width: contentRect.width,
                                      height: boundingRect.height + 10)
                formatted.draw(in: drawRect, withAttributes: attrs)
                return
            }
            fontSize -= 1
        }
        
        let formatted = formatContentForDisplay(content, targetWidth: contentRect.width, fontSize: minFont)
        let font = NSFont.systemFont(ofSize: minFont, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        formatted.draw(in: contentRect, withAttributes: attrs)
    }
    
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
    
    /// Smart text formatter that breaks content into readable lines.
    private func formatContentForDisplay(_ text: String, targetWidth: CGFloat, fontSize: CGFloat) -> String {
        var result = text
        
        result = result.replacingOccurrences(of: ". ", with: ".\n")
        result = result.replacingOccurrences(of: "; ", with: ";\n")
        result = result.replacingOccurrences(of: ":\\s+([A-Z])", with: ":\n$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "? ", with: "?\n")
        result = result.replacingOccurrences(of: "! ", with: "!\n")
        
        if fontSize >= 32 {
            result = result.replacingOccurrences(of: ", ", with: ",\n")
        }
        
        if fontSize >= 38 {
            let phraseBreaks = [" and ", " but ", " or ", " for ", " nor ", " yet ", " so ",
                                " that ", " which ", " who ", " when ", " where ", " while ",
                                " because ", " although ", " though ", " unless ", " until ",
                                " before ", " after ", " since ", " through ", " with ", " without ",
                                " upon ", " into ", " onto ", " within ", " between ", " among "]
            for phrase in phraseBreaks {
                result = result.replacingOccurrences(of: phrase, with: "\n" + phrase.trimmingCharacters(in: .whitespaces) + " ")
            }
        }
        
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
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

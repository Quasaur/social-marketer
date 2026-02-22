//
//  QuoteGraphicGenerator+BordersModern.swift
//  SocialMarketer
//
//  Stained Glass and Modern Glow border styles
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 9. Stained Glass — Cathedral arch + radial mullions
    
    func drawStainedGlassBorder() {
        let w = imageSize.width, h = imageSize.height
        let archR = (w - 60) / 2
        let archCY = h - 60 - archR
        
        let outer = NSBezierPath()
        outer.move(to: NSPoint(x: 30, y: 60))
        outer.line(to: NSPoint(x: 30, y: archCY))
        outer.appendArc(withCenter: NSPoint(x: w/2, y: archCY), radius: archR, startAngle: 180, endAngle: 0)
        outer.line(to: NSPoint(x: w-30, y: 60))
        outer.close()
        outer.lineWidth = 4; outer.stroke()
        
        let innerR = archR - 22
        let innerFrame = NSBezierPath()
        innerFrame.move(to: NSPoint(x: 52, y: 72))
        innerFrame.line(to: NSPoint(x: 52, y: archCY))
        innerFrame.appendArc(withCenter: NSPoint(x: w/2, y: archCY), radius: innerR, startAngle: 180, endAngle: 0)
        innerFrame.line(to: NSPoint(x: w-52, y: 72))
        innerFrame.close()
        innerFrame.lineWidth = 2; innerFrame.stroke()
        
        goldColor.withAlphaComponent(0.4).setStroke()
        let ac = NSPoint(x: w/2, y: archCY)
        for i in 1..<8 {
            let angle = CGFloat(i) * .pi / 8
            let line = NSBezierPath()
            line.move(to: NSPoint(x: ac.x + innerR*cos(angle), y: ac.y + innerR*sin(angle)))
            line.line(to: NSPoint(x: ac.x + archR*cos(angle), y: ac.y + archR*sin(angle)))
            line.lineWidth = 1.5; line.stroke()
        }
        for r in stride(from: innerR + 30, to: archR, by: 30) {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: ac, radius: r, startAngle: 15, endAngle: 165)
            arc.lineWidth = 1; arc.stroke()
        }
        goldColor.setStroke()
        goldColor.setFill()
        NSBezierPath(rect: NSRect(x: 30, y: 52, width: w-60, height: 5)).fill()
    }
    
    // MARK: - 10. Modern Glow — Layered luminous aura
    
    func drawModernGlowBorder() {
        let w = imageSize.width, h = imageSize.height
        
        for i in (0..<8).reversed() {
            let inset = CGFloat(12 + i * 6)
            let alpha = 0.08 + (1.0 - Double(i) / 7.0) * 0.92
            let lw = CGFloat(1 + (7 - i))
            NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: CGFloat(alpha)).setStroke()
            let path = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: w-inset*2, height: h-inset*2),
                                     xRadius: 8, yRadius: 8)
            path.lineWidth = lw; path.stroke()
        }
        
        goldColor.setStroke()
        let inner = NSRect(x: 58, y: 58, width: w-116, height: h-116)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: 4, yRadius: 4)
        innerPath.lineWidth = 2; innerPath.stroke()
        
        for (cx, cy) in [(inner.minX, inner.minY), (inner.maxX, inner.minY),
                          (inner.minX, inner.maxY), (inner.maxX, inner.maxY)] {
            for (r, a) in [(CGFloat(14), CGFloat(0.1)), (CGFloat(9), CGFloat(0.3)),
                           (CGFloat(5), CGFloat(0.7)), (CGFloat(2.5), CGFloat(1.0))] {
                NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: a).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2)).fill()
            }
        }
    }
}

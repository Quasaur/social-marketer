//
//  QuoteGraphicGenerator+BordersHeraldic.swift
//  SocialMarketer
//
//  Fleur-de-lis and Baroque border styles
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 5. Fleur-de-lis — Classic heraldic lily motifs
    
    func drawFleurDeLisBorder() {
        let w = imageSize.width, h = imageSize.height
        
        let outer = NSBezierPath(roundedRect: NSRect(x: 25, y: 25, width: w-50, height: h-50), xRadius: 18, yRadius: 18)
        outer.lineWidth = 3; outer.stroke()
        let inner = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: w-100, height: h-100), xRadius: 10, yRadius: 10)
        inner.lineWidth = 1.5; inner.stroke()
        
        drawFleurDeLis(at: NSPoint(x: 38, y: 38), size: 28, angle: .pi/4)
        drawFleurDeLis(at: NSPoint(x: w-38, y: 38), size: 28, angle: 3 * .pi/4)
        drawFleurDeLis(at: NSPoint(x: 38, y: h-38), size: 28, angle: -.pi/4)
        drawFleurDeLis(at: NSPoint(x: w-38, y: h-38), size: 28, angle: -3 * .pi/4)
        
        drawFleurDeLis(at: NSPoint(x: w/2, y: 32), size: 22, angle: 0)
        drawFleurDeLis(at: NSPoint(x: w/2, y: h-32), size: 22, angle: .pi)
        drawFleurDeLis(at: NSPoint(x: 32, y: h/2), size: 22, angle: -.pi/2)
        drawFleurDeLis(at: NSPoint(x: w-32, y: h/2), size: 22, angle: .pi/2)
        
        let step: CGFloat = 100
        for x in stride(from: CGFloat(120), to: w/2 - 40, by: step) {
            drawFleurDeLis(at: NSPoint(x: x, y: 37), size: 14, angle: 0)
            drawFleurDeLis(at: NSPoint(x: w-x, y: 37), size: 14, angle: 0)
            drawFleurDeLis(at: NSPoint(x: x, y: h-37), size: 14, angle: .pi)
            drawFleurDeLis(at: NSPoint(x: w-x, y: h-37), size: 14, angle: .pi)
        }
        for y in stride(from: CGFloat(120), to: h/2 - 40, by: step) {
            drawFleurDeLis(at: NSPoint(x: 37, y: y), size: 14, angle: -.pi/2)
            drawFleurDeLis(at: NSPoint(x: 37, y: h-y), size: 14, angle: -.pi/2)
            drawFleurDeLis(at: NSPoint(x: w-37, y: y), size: 14, angle: .pi/2)
            drawFleurDeLis(at: NSPoint(x: w-37, y: h-y), size: 14, angle: .pi/2)
        }
    }
    
    private func drawFleurDeLis(at center: NSPoint, size: CGFloat, angle: CGFloat) {
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        
        goldColor.setStroke()
        goldColor.setFill()
        
        let cp = NSBezierPath()
        cp.move(to: NSPoint(x: 0, y: -size * 0.15))
        cp.curve(to: NSPoint(x: 0, y: size * 0.9),
                 controlPoint1: NSPoint(x: -size * 0.25, y: size * 0.3),
                 controlPoint2: NSPoint(x: -size * 0.1, y: size * 0.7))
        cp.curve(to: NSPoint(x: 0, y: -size * 0.15),
                 controlPoint1: NSPoint(x: size * 0.1, y: size * 0.7),
                 controlPoint2: NSPoint(x: size * 0.25, y: size * 0.3))
        cp.fill()
        
        let lp = NSBezierPath()
        lp.move(to: NSPoint(x: 0, y: size * 0.1))
        lp.curve(to: NSPoint(x: -size * 0.55, y: size * 0.7),
                 controlPoint1: NSPoint(x: -size * 0.15, y: size * 0.4),
                 controlPoint2: NSPoint(x: -size * 0.6, y: size * 0.45))
        lp.curve(to: NSPoint(x: -size * 0.1, y: size * 0.35),
                 controlPoint1: NSPoint(x: -size * 0.45, y: size * 0.75),
                 controlPoint2: NSPoint(x: -size * 0.2, y: size * 0.55))
        lp.fill()
        
        let rp = NSBezierPath()
        rp.move(to: NSPoint(x: 0, y: size * 0.1))
        rp.curve(to: NSPoint(x: size * 0.55, y: size * 0.7),
                 controlPoint1: NSPoint(x: size * 0.15, y: size * 0.4),
                 controlPoint2: NSPoint(x: size * 0.6, y: size * 0.45))
        rp.curve(to: NSPoint(x: size * 0.1, y: size * 0.35),
                 controlPoint1: NSPoint(x: size * 0.45, y: size * 0.75),
                 controlPoint2: NSPoint(x: size * 0.2, y: size * 0.55))
        rp.fill()
        
        let band = NSBezierPath(rect: NSRect(x: -size * 0.28, y: -size * 0.05, width: size * 0.56, height: size * 0.12))
        band.fill()
        
        let stem = NSBezierPath(rect: NSRect(x: -size * 0.06, y: -size * 0.35, width: size * 0.12, height: size * 0.32))
        stem.fill()
        
        let base = NSBezierPath()
        base.move(to: NSPoint(x: -size * 0.2, y: -size * 0.35))
        base.line(to: NSPoint(x: size * 0.2, y: -size * 0.35))
        base.line(to: NSPoint(x: size * 0.15, y: -size * 0.42))
        base.line(to: NSPoint(x: -size * 0.15, y: -size * 0.42))
        base.close()
        base.fill()
        
        ctx.restoreGState()
    }
    
    // MARK: - 6. Baroque — Scrollwork filigree
    
    func drawBaroqueBorder() {
        let w = imageSize.width, h = imageSize.height
        
        let outer = NSBezierPath(roundedRect: NSRect(x: 18, y: 18, width: w-36, height: h-36), xRadius: 24, yRadius: 24)
        outer.lineWidth = 5
        outer.stroke()
        let inner = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: w-104, height: h-104), xRadius: 12, yRadius: 12)
        inner.lineWidth = 1.5
        inner.stroke()
        
        for (cx, cy, flipX, flipY) in [(CGFloat(18), CGFloat(18), false, false),
                                         (w-18, CGFloat(18), true, false),
                                         (CGFloat(18), h-18, false, true),
                                         (w-18, h-18, true, true)] {
            drawFiligreeScroll(at: NSPoint(x: cx, y: cy), flipX: flipX, flipY: flipY)
        }
        
        let step: CGFloat = 45
        let outerR = NSRect(x: 18, y: 18, width: w-36, height: h-36)
        for x in stride(from: outerR.minX + 80, to: outerR.maxX - 60, by: step) {
            drawOrnamentDot(at: NSPoint(x: x, y: outerR.minY))
            drawOrnamentDot(at: NSPoint(x: x, y: outerR.maxY))
        }
        for y in stride(from: outerR.minY + 80, to: outerR.maxY - 60, by: step) {
            drawOrnamentDot(at: NSPoint(x: outerR.minX, y: y))
            drawOrnamentDot(at: NSPoint(x: outerR.maxX, y: y))
        }
    }
    
    private func drawFiligreeScroll(at origin: NSPoint, flipX: Bool, flipY: Bool) {
        let dx: CGFloat = flipX ? -1 : 1
        let dy: CGFloat = flipY ? -1 : 1
        
        let s1 = NSBezierPath()
        s1.move(to: NSPoint(x: origin.x, y: origin.y + dy * 30))
        s1.curve(to: NSPoint(x: origin.x + dx * 55, y: origin.y + dy * 65),
                 controlPoint1: NSPoint(x: origin.x + dx * 40, y: origin.y + dy * 10),
                 controlPoint2: NSPoint(x: origin.x + dx * 18, y: origin.y + dy * 60))
        s1.lineWidth = 2.5; s1.stroke()
        
        let s2 = NSBezierPath()
        s2.move(to: NSPoint(x: origin.x + dx * 30, y: origin.y))
        s2.curve(to: NSPoint(x: origin.x + dx * 65, y: origin.y + dy * 55),
                 controlPoint1: NSPoint(x: origin.x + dx * 10, y: origin.y + dy * 40),
                 controlPoint2: NSPoint(x: origin.x + dx * 60, y: origin.y + dy * 18))
        s2.lineWidth = 2; s2.stroke()
        
        let curl = NSBezierPath()
        let ce = NSPoint(x: origin.x + dx * 55, y: origin.y + dy * 65)
        curl.move(to: ce)
        curl.curve(to: NSPoint(x: ce.x + dx*15, y: ce.y - dy*8),
                   controlPoint1: NSPoint(x: ce.x + dx*12, y: ce.y + dy*10),
                   controlPoint2: NSPoint(x: ce.x + dx*18, y: ce.y + dy*2))
        curl.lineWidth = 2; curl.stroke()
        
        let curl2 = NSBezierPath()
        let ce2 = NSPoint(x: origin.x + dx * 65, y: origin.y + dy * 55)
        curl2.move(to: ce2)
        curl2.curve(to: NSPoint(x: ce2.x - dx*8, y: ce2.y + dy*15),
                    controlPoint1: NSPoint(x: ce2.x + dx*10, y: ce2.y + dy*12),
                    controlPoint2: NSPoint(x: ce2.x + dx*2, y: ce2.y + dy*18))
        curl2.lineWidth = 1.5; curl2.stroke()
        
        goldColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: origin.x + dx*24-4, y: origin.y + dy*24-5, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: origin.x + dx*40-3, y: origin.y + dy*40-4, width: 6, height: 8)).fill()
    }
    
    private func drawOrnamentDot(at p: NSPoint) {
        goldColor.setFill()
        fillCircle(at: p, diameter: 6)
        let ring = NSBezierPath(ovalIn: NSRect(x: p.x-8, y: p.y-8, width: 16, height: 16))
        ring.lineWidth = 1; ring.stroke()
    }
}

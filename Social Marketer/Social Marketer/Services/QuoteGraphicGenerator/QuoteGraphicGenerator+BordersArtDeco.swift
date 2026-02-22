//
//  QuoteGraphicGenerator+BordersArtDeco.swift
//  SocialMarketer
//
//  Art Deco border style with vine scrollwork corners
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 1. Art Deco — INTRO POST STYLE: vine scrollwork corners
    
    func drawArtDecoBorder() {
        let w = imageSize.width, h = imageSize.height
        
        strokeRect(NSRect(x: 30, y: 30, width: w-60, height: h-60), lineWidth: 2)
        strokeRect(NSRect(x: 50, y: 50, width: w-100, height: h-100), lineWidth: 1)
        
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (30, 30, 1, 1),
            (w-30, 30, -1, 1),
            (30, h-30, 1, -1),
            (w-30, h-30, -1, -1)
        ]
        for (ox, oy, dx, dy) in corners {
            drawVineCorner(at: NSPoint(x: ox, y: oy), dx: dx, dy: dy)
        }
        
        let midX = w / 2, midY = h / 2
        for (mx, my, horizontal) in [(midX, CGFloat(30), true), (midX, h-30, true),
                                      (CGFloat(30), midY, false), (w-30, midY, false)] {
            drawEdgeFlourish(at: NSPoint(x: mx, y: my), horizontal: horizontal)
        }
    }
    
    /// Organic vine scrollwork for a single corner (Intro Post style)
    private func drawVineCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        
        let vine1 = NSBezierPath()
        vine1.move(to: NSPoint(x: o.x, y: o.y + dy * 10))
        vine1.curve(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 90),
                    controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 20),
                    controlPoint2: NSPoint(x: o.x - dx * 10, y: o.y + dy * 70))
        vine1.lineWidth = 2.5
        vine1.lineCapStyle = .round
        vine1.stroke()
        
        let vine2 = NSBezierPath()
        vine2.move(to: NSPoint(x: o.x + dx * 10, y: o.y))
        vine2.curve(to: NSPoint(x: o.x + dx * 90, y: o.y + dy * 20),
                    controlPoint1: NSPoint(x: o.x + dx * 20, y: o.y + dy * 50),
                    controlPoint2: NSPoint(x: o.x + dx * 70, y: o.y - dy * 10))
        vine2.lineWidth = 2.5
        vine2.lineCapStyle = .round
        vine2.stroke()
        
        let tendril1 = NSBezierPath()
        tendril1.move(to: NSPoint(x: o.x + dx * 15, y: o.y + dy * 50))
        tendril1.curve(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 65),
                       controlPoint1: NSPoint(x: o.x + dx * 40, y: o.y + dy * 35),
                       controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 55))
        tendril1.lineWidth = 1.8
        tendril1.stroke()
        
        let curl1 = NSBezierPath()
        let cEnd = NSPoint(x: o.x + dx * 50, y: o.y + dy * 65)
        curl1.move(to: cEnd)
        curl1.curve(to: NSPoint(x: cEnd.x + dx * 10, y: cEnd.y - dy * 6),
                    controlPoint1: NSPoint(x: cEnd.x + dx * 8, y: cEnd.y + dy * 8),
                    controlPoint2: NSPoint(x: cEnd.x + dx * 13, y: cEnd.y + dy * 2))
        curl1.lineWidth = 1.5
        curl1.stroke()
        
        let tendril2 = NSBezierPath()
        tendril2.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 15))
        tendril2.curve(to: NSPoint(x: o.x + dx * 65, y: o.y + dy * 50),
                       controlPoint1: NSPoint(x: o.x + dx * 35, y: o.y + dy * 40),
                       controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 55))
        tendril2.lineWidth = 1.8
        tendril2.stroke()
        
        let curl2 = NSBezierPath()
        let cEnd2 = NSPoint(x: o.x + dx * 65, y: o.y + dy * 50)
        curl2.move(to: cEnd2)
        curl2.curve(to: NSPoint(x: cEnd2.x - dx * 6, y: cEnd2.y + dy * 10),
                    controlPoint1: NSPoint(x: cEnd2.x + dx * 8, y: cEnd2.y + dy * 8),
                    controlPoint2: NSPoint(x: cEnd2.x + dx * 2, y: cEnd2.y + dy * 13))
        curl2.lineWidth = 1.5
        curl2.stroke()
        
        goldColor.setFill()
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 40), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 8), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 45), angle: atan2(dy, dx), size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 45, y: o.y + dy * 30), angle: atan2(dy, dx) + .pi/2, size: 6)
        
        for (px, py) in [(o.x + dx*5, o.y + dy*25), (o.x + dx*25, o.y + dy*5),
                          (o.x + dx*35, o.y + dy*35)] {
            fillCircle(at: NSPoint(x: px, y: py), diameter: 4)
        }
    }
    
    /// Small flourish at edge midpoints
    private func drawEdgeFlourish(at p: NSPoint, horizontal: Bool) {
        let s: CGFloat = 15
        goldColor.setFill()
        fillDiamond(at: p, size: 5)
        goldColor.setStroke()
        if horizontal {
            let left = NSBezierPath()
            left.move(to: NSPoint(x: p.x - s, y: p.y))
            left.curve(to: NSPoint(x: p.x - s*2.5, y: p.y), controlPoint1: NSPoint(x: p.x - s*1.5, y: p.y + 8), controlPoint2: NSPoint(x: p.x - s*2, y: p.y + 5))
            left.lineWidth = 1.5
            left.stroke()
            let right = NSBezierPath()
            right.move(to: NSPoint(x: p.x + s, y: p.y))
            right.curve(to: NSPoint(x: p.x + s*2.5, y: p.y), controlPoint1: NSPoint(x: p.x + s*1.5, y: p.y - 8), controlPoint2: NSPoint(x: p.x + s*2, y: p.y - 5))
            right.lineWidth = 1.5
            right.stroke()
        } else {
            let up = NSBezierPath()
            up.move(to: NSPoint(x: p.x, y: p.y + s))
            up.curve(to: NSPoint(x: p.x, y: p.y + s*2.5), controlPoint1: NSPoint(x: p.x + 8, y: p.y + s*1.5), controlPoint2: NSPoint(x: p.x + 5, y: p.y + s*2))
            up.lineWidth = 1.5
            up.stroke()
            let down = NSBezierPath()
            down.move(to: NSPoint(x: p.x, y: p.y - s))
            down.curve(to: NSPoint(x: p.x, y: p.y - s*2.5), controlPoint1: NSPoint(x: p.x - 8, y: p.y - s*1.5), controlPoint2: NSPoint(x: p.x - 5, y: p.y - s*2))
            down.lineWidth = 1.5
            down.stroke()
        }
    }
}

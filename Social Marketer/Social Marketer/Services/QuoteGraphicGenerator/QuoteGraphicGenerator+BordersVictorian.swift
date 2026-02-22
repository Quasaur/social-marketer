//
//  QuoteGraphicGenerator+BordersVictorian.swift
//  SocialMarketer
//
//  Victorian and Golden Vine border styles
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 7. Victorian — Corner flourishes + flower ornaments
    
    func drawVictorianBorder() {
        let w = imageSize.width, h = imageSize.height
        
        let outer = NSRect(x: 22, y: 22, width: w-44, height: h-44)
        NSBezierPath(roundedRect: outer, xRadius: 20, yRadius: 20).apply { $0.lineWidth = 4; $0.stroke() }
        let inner = NSRect(x: 50, y: 50, width: w-100, height: h-100)
        NSBezierPath(roundedRect: inner, xRadius: 14, yRadius: 14).apply { $0.lineWidth = 2; $0.stroke() }
        
        let ci: CGFloat = 36
        let fR: CGFloat = 50
        for (cx, cy, sa, ea) in [(ci, ci, CGFloat(0), CGFloat(90)),
                                   (w-ci, ci, CGFloat(90), CGFloat(180)),
                                   (w-ci, h-ci, CGFloat(180), CGFloat(270)),
                                   (ci, h-ci, CGFloat(270), CGFloat(360))] {
            for (r, lw) in [(fR, CGFloat(2.5)), (fR*0.55, CGFloat(1.5)), (fR*0.3, CGFloat(1))] {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: sa, endAngle: ea)
                arc.lineWidth = lw; arc.stroke()
            }
            let midAngle = (sa + ea) / 2 * .pi / 180
            goldColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx + fR*0.7*cos(midAngle) - 5,
                                        y: cy + fR*0.7*sin(midAngle) - 5, width: 10, height: 10)).fill()
        }
        
        let step: CGFloat = 65
        for x in stride(from: outer.minX + 60, to: outer.maxX - 40, by: step) {
            drawSmallFlower(at: NSPoint(x: x, y: outer.minY + 14))
            drawSmallFlower(at: NSPoint(x: x, y: outer.maxY - 14))
        }
    }
    
    private func drawSmallFlower(at p: NSPoint) {
        for i in 0..<4 {
            let a = CGFloat(i) * .pi / 2
            let petal = NSBezierPath(ovalIn: NSRect(x: p.x + 5*cos(a) - 3, y: p.y + 5*sin(a) - 3, width: 6, height: 6))
            petal.lineWidth = 1; petal.stroke()
        }
        goldColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x-2.5, y: p.y-2.5, width: 5, height: 5)).fill()
    }
    
    // MARK: - 8. Golden Vine — Intro Post style: lush corner scrollwork
    
    func drawGoldenVineBorder() {
        let w = imageSize.width, h = imageSize.height
        
        strokeRect(NSRect(x: 28, y: 28, width: w-56, height: h-56), lineWidth: 2)
        strokeRect(NSRect(x: 42, y: 42, width: w-84, height: h-84), lineWidth: 1)
        
        drawLushVineCorner(at: NSPoint(x: 28, y: 28), dx: 1, dy: 1)
        drawLushVineCorner(at: NSPoint(x: w-28, y: 28), dx: -1, dy: 1)
        drawLushVineCorner(at: NSPoint(x: 28, y: h-28), dx: 1, dy: -1)
        drawLushVineCorner(at: NSPoint(x: w-28, y: h-28), dx: -1, dy: -1)
    }
    
    private func drawLushVineCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        goldColor.setFill()
        
        let v1 = NSBezierPath()
        v1.move(to: NSPoint(x: o.x, y: o.y + dy * 8))
        v1.curve(to: NSPoint(x: o.x + dx * 15, y: o.y + dy * 140),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x - dx * 20, y: o.y + dy * 110))
        v1.lineWidth = 2.5; v1.lineCapStyle = .round; v1.stroke()
        
        let v2 = NSBezierPath()
        v2.move(to: NSPoint(x: o.x + dx * 8, y: o.y))
        v2.curve(to: NSPoint(x: o.x + dx * 140, y: o.y + dy * 15),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 110, y: o.y - dy * 20))
        v2.lineWidth = 2.5; v2.lineCapStyle = .round; v2.stroke()
        
        let vd = NSBezierPath()
        vd.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 5))
        vd.curve(to: NSPoint(x: o.x + dx * 80, y: o.y + dy * 80),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 15),
                 controlPoint2: NSPoint(x: o.x + dx * 15, y: o.y + dy * 50))
        vd.lineWidth = 2; vd.lineCapStyle = .round; vd.stroke()
        
        let t1 = NSBezierPath()
        t1.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 60))
        t1.curve(to: NSPoint(x: o.x + dx * 65, y: o.y + dy * 85),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 45),
                 controlPoint2: NSPoint(x: o.x + dx * 60, y: o.y + dy * 70))
        t1.lineWidth = 1.8; t1.stroke()
        
        let c1 = NSBezierPath()
        let ce1 = NSPoint(x: o.x + dx * 65, y: o.y + dy * 85)
        c1.move(to: ce1)
        c1.curve(to: NSPoint(x: ce1.x + dx * 12, y: ce1.y - dy * 8),
                 controlPoint1: NSPoint(x: ce1.x + dx * 10, y: ce1.y + dy * 10),
                 controlPoint2: NSPoint(x: ce1.x + dx * 15, y: ce1.y + dy * 2))
        c1.lineWidth = 1.5; c1.stroke()
        
        let t2 = NSBezierPath()
        t2.move(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 20))
        t2.curve(to: NSPoint(x: o.x + dx * 85, y: o.y + dy * 65),
                 controlPoint1: NSPoint(x: o.x + dx * 45, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x + dx * 70, y: o.y + dy * 60))
        t2.lineWidth = 1.8; t2.stroke()
        
        let c2 = NSBezierPath()
        let ce2 = NSPoint(x: o.x + dx * 85, y: o.y + dy * 65)
        c2.move(to: ce2)
        c2.curve(to: NSPoint(x: ce2.x - dx * 8, y: ce2.y + dy * 12),
                 controlPoint1: NSPoint(x: ce2.x + dx * 10, y: ce2.y + dy * 10),
                 controlPoint2: NSPoint(x: ce2.x + dx * 2, y: ce2.y + dy * 15))
        c2.lineWidth = 1.5; c2.stroke()
        
        let t3 = NSBezierPath()
        t3.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 100))
        t3.curve(to: NSPoint(x: o.x + dx * 45, y: o.y + dy * 120),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 90),
                 controlPoint2: NSPoint(x: o.x + dx * 40, y: o.y + dy * 105))
        t3.lineWidth = 1.5; t3.stroke()
        let c3 = NSBezierPath()
        let ce3 = NSPoint(x: o.x + dx * 45, y: o.y + dy * 120)
        c3.move(to: ce3)
        c3.curve(to: NSPoint(x: ce3.x + dx * 8, y: ce3.y - dy * 5),
                 controlPoint1: NSPoint(x: ce3.x + dx * 6, y: ce3.y + dy * 6),
                 controlPoint2: NSPoint(x: ce3.x + dx * 10, y: ce3.y + dy * 1))
        c3.lineWidth = 1.2; c3.stroke()
        
        let t4 = NSBezierPath()
        t4.move(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 5))
        t4.curve(to: NSPoint(x: o.x + dx * 120, y: o.y + dy * 45),
                 controlPoint1: NSPoint(x: o.x + dx * 90, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x + dx * 105, y: o.y + dy * 40))
        t4.lineWidth = 1.5; t4.stroke()
        let c4 = NSBezierPath()
        let ce4 = NSPoint(x: o.x + dx * 120, y: o.y + dy * 45)
        c4.move(to: ce4)
        c4.curve(to: NSPoint(x: ce4.x - dx * 5, y: ce4.y + dy * 8),
                 controlPoint1: NSPoint(x: ce4.x + dx * 6, y: ce4.y + dy * 6),
                 controlPoint2: NSPoint(x: ce4.x + dx * 1, y: ce4.y + dy * 10))
        c4.lineWidth = 1.2; c4.stroke()
        
        let ti = NSBezierPath()
        ti.move(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 40))
        ti.curve(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 30),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 48),
                 controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 35))
        ti.lineWidth = 1.3; ti.stroke()
        
        let ti2 = NSBezierPath()
        ti2.move(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 40))
        ti2.curve(to: NSPoint(x: o.x + dx * 30, y: o.y + dy * 60),
                  controlPoint1: NSPoint(x: o.x + dx * 48, y: o.y + dy * 50),
                  controlPoint2: NSPoint(x: o.x + dx * 35, y: o.y + dy * 55))
        ti2.lineWidth = 1.3; ti2.stroke()
        
        drawLeaf(at: NSPoint(x: o.x + dx * 12, y: o.y + dy * 35), angle: atan2(dy, dx) + .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 5, y: o.y + dy * 55), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 10, y: o.y + dy * 80), angle: atan2(dy, dx) + .pi/5, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 12, y: o.y + dy * 115), angle: atan2(dy, dx) - .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 130), angle: atan2(dy, dx) + .pi/6, size: 6)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 35, y: o.y + dy * 12), angle: atan2(dy, dx) - .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 55, y: o.y + dy * 5), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 80, y: o.y + dy * 10), angle: atan2(dy, dx) - .pi/5, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 115, y: o.y + dy * 12), angle: atan2(dy, dx) + .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 130, y: o.y + dy * 8), angle: atan2(dy, dx) - .pi/6, size: 6)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 25, y: o.y + dy * 22), angle: atan2(dy, dx), size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 50, y: o.y + dy * 48), angle: atan2(dy, dx) + .pi/2, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 68, y: o.y + dy * 72), angle: atan2(dy, dx) - .pi/4, size: 6)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 70), angle: .pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 70, y: o.y + dy * 40), angle: -.pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 108), angle: .pi/4, size: 5)
        drawLeaf(at: NSPoint(x: o.x + dx * 108, y: o.y + dy * 30), angle: -.pi/4, size: 5)
        
        let dotPositions: [(CGFloat, CGFloat)] = [
            (5, 20), (20, 5), (15, 45), (45, 15),
            (30, 30), (55, 55), (70, 70),
            (10, 70), (70, 10), (5, 95), (95, 5),
            (10, 125), (125, 10), (50, 80), (80, 50)
        ]
        for (px, py) in dotPositions {
            NSBezierPath(ovalIn: NSRect(x: o.x + dx*px - 2, y: o.y + dy*py - 2, width: 4, height: 4)).fill()
        }
    }
}

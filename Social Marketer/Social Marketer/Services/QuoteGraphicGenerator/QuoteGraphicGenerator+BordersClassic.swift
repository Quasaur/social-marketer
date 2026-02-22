//
//  QuoteGraphicGenerator+BordersClassic.swift
//  SocialMarketer
//
//  Classic Scroll border style with far-reaching scrollwork
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 2. Classic Scroll — INTRO POST MATCH
    
    func drawClassicScrollBorder() {
        let w = imageSize.width, h = imageSize.height
        
        strokeRect(NSRect(x: 35, y: 35, width: w-70, height: h-70), lineWidth: 1.5)
        
        drawIntroCorner(at: NSPoint(x: 35, y: 35), dx: 1, dy: 1)
        drawIntroCorner(at: NSPoint(x: w-35, y: 35), dx: -1, dy: 1)
        drawIntroCorner(at: NSPoint(x: 35, y: h-35), dx: 1, dy: -1)
        drawIntroCorner(at: NSPoint(x: w-35, y: h-35), dx: -1, dy: -1)
    }
    
    /// Far-reaching scrollwork ornament (Intro Post style)
    private func drawIntroCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        goldColor.setFill()
        
        let pv = NSBezierPath()
        pv.move(to: NSPoint(x: o.x, y: o.y + dy * 5))
        pv.curve(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 280),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 60),
                 controlPoint2: NSPoint(x: o.x - dx * 25, y: o.y + dy * 200))
        pv.lineWidth = 2.5; pv.lineCapStyle = .round; pv.stroke()
        
        let ph = NSBezierPath()
        ph.move(to: NSPoint(x: o.x + dx * 5, y: o.y))
        ph.curve(to: NSPoint(x: o.x + dx * 280, y: o.y + dy * 20),
                 controlPoint1: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 200, y: o.y - dy * 25))
        ph.lineWidth = 2.5; ph.lineCapStyle = .round; ph.stroke()
        
        let dv = NSBezierPath()
        dv.move(to: NSPoint(x: o.x + dx * 3, y: o.y + dy * 3))
        dv.curve(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 100),
                 controlPoint1: NSPoint(x: o.x + dx * 65, y: o.y + dy * 10),
                 controlPoint2: NSPoint(x: o.x + dx * 10, y: o.y + dy * 65))
        dv.lineWidth = 2.5; dv.lineCapStyle = .round; dv.stroke()
        
        let ds = NSBezierPath()
        let dTip = NSPoint(x: o.x + dx * 100, y: o.y + dy * 100)
        ds.move(to: dTip)
        ds.curve(to: NSPoint(x: dTip.x - dx * 15, y: dTip.y - dy * 5),
                 controlPoint1: NSPoint(x: dTip.x + dx * 10, y: dTip.y - dy * 12),
                 controlPoint2: NSPoint(x: dTip.x - dx * 5, y: dTip.y - dy * 15))
        ds.lineWidth = 2; ds.stroke()
        
        let sv = NSBezierPath()
        sv.move(to: NSPoint(x: o.x + dx * 10, y: o.y + dy * 20))
        sv.curve(to: NSPoint(x: o.x + dx * 35, y: o.y + dy * 200),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x - dx * 10, y: o.y + dy * 150))
        sv.lineWidth = 2; sv.lineCapStyle = .round; sv.stroke()
        let svc = NSBezierPath()
        let svEnd = NSPoint(x: o.x + dx * 35, y: o.y + dy * 200)
        svc.move(to: svEnd)
        svc.curve(to: NSPoint(x: svEnd.x + dx * 12, y: svEnd.y - dy * 10),
                  controlPoint1: NSPoint(x: svEnd.x + dx * 15, y: svEnd.y + dy * 8),
                  controlPoint2: NSPoint(x: svEnd.x + dx * 16, y: svEnd.y - dy * 2))
        svc.lineWidth = 1.8; svc.stroke()
        
        let sh = NSBezierPath()
        sh.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 10))
        sh.curve(to: NSPoint(x: o.x + dx * 200, y: o.y + dy * 35),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x + dx * 150, y: o.y - dy * 10))
        sh.lineWidth = 2; sh.lineCapStyle = .round; sh.stroke()
        let shc = NSBezierPath()
        let shEnd = NSPoint(x: o.x + dx * 200, y: o.y + dy * 35)
        shc.move(to: shEnd)
        shc.curve(to: NSPoint(x: shEnd.x - dx * 10, y: shEnd.y + dy * 12),
                  controlPoint1: NSPoint(x: shEnd.x + dx * 8, y: shEnd.y + dy * 15),
                  controlPoint2: NSPoint(x: shEnd.x - dx * 2, y: shEnd.y + dy * 16))
        shc.lineWidth = 1.8; shc.stroke()
        
        let tv = NSBezierPath()
        tv.move(to: NSPoint(x: o.x + dx * 25, y: o.y + dy * 100))
        tv.curve(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 160),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 95),
                 controlPoint2: NSPoint(x: o.x + dx * 40, y: o.y + dy * 140))
        tv.lineWidth = 1.8; tv.stroke()
        let tvc = NSBezierPath()
        let tvEnd = NSPoint(x: o.x + dx * 60, y: o.y + dy * 160)
        tvc.move(to: tvEnd)
        tvc.curve(to: NSPoint(x: tvEnd.x + dx * 8, y: tvEnd.y - dy * 8),
                  controlPoint1: NSPoint(x: tvEnd.x + dx * 10, y: tvEnd.y + dy * 6),
                  controlPoint2: NSPoint(x: tvEnd.x + dx * 12, y: tvEnd.y - dy * 2))
        tvc.lineWidth = 1.5; tvc.stroke()
        
        let th = NSBezierPath()
        th.move(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 25))
        th.curve(to: NSPoint(x: o.x + dx * 160, y: o.y + dy * 60),
                 controlPoint1: NSPoint(x: o.x + dx * 95, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 140, y: o.y + dy * 40))
        th.lineWidth = 1.8; th.stroke()
        let thc = NSBezierPath()
        let thEnd = NSPoint(x: o.x + dx * 160, y: o.y + dy * 60)
        thc.move(to: thEnd)
        thc.curve(to: NSPoint(x: thEnd.x - dx * 8, y: thEnd.y + dy * 8),
                  controlPoint1: NSPoint(x: thEnd.x + dx * 6, y: thEnd.y + dy * 10),
                  controlPoint2: NSPoint(x: thEnd.x - dx * 2, y: thEnd.y + dy * 12))
        thc.lineWidth = 1.5; thc.stroke()
        
        let ov = NSBezierPath()
        ov.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 180))
        ov.curve(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 240),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 175),
                 controlPoint2: NSPoint(x: o.x + dx * 25, y: o.y + dy * 220))
        ov.lineWidth = 1.5; ov.stroke()
        let ovc = NSBezierPath()
        let ovEnd = NSPoint(x: o.x + dx * 40, y: o.y + dy * 240)
        ovc.move(to: ovEnd)
        ovc.curve(to: NSPoint(x: ovEnd.x + dx * 6, y: ovEnd.y - dy * 6),
                  controlPoint1: NSPoint(x: ovEnd.x + dx * 8, y: ovEnd.y + dy * 4),
                  controlPoint2: NSPoint(x: ovEnd.x + dx * 9, y: ovEnd.y - dy * 1))
        ovc.lineWidth = 1.3; ovc.stroke()
        
        let oh = NSBezierPath()
        oh.move(to: NSPoint(x: o.x + dx * 180, y: o.y + dy * 5))
        oh.curve(to: NSPoint(x: o.x + dx * 240, y: o.y + dy * 40),
                 controlPoint1: NSPoint(x: o.x + dx * 175, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x + dx * 220, y: o.y + dy * 25))
        oh.lineWidth = 1.5; oh.stroke()
        let ohc = NSBezierPath()
        let ohEnd = NSPoint(x: o.x + dx * 240, y: o.y + dy * 40)
        ohc.move(to: ohEnd)
        ohc.curve(to: NSPoint(x: ohEnd.x - dx * 6, y: ohEnd.y + dy * 6),
                  controlPoint1: NSPoint(x: ohEnd.x + dx * 4, y: ohEnd.y + dy * 8),
                  controlPoint2: NSPoint(x: ohEnd.x - dx * 1, y: ohEnd.y + dy * 9))
        ohc.lineWidth = 1.3; ohc.stroke()
        
        let ic1 = NSBezierPath()
        ic1.move(to: NSPoint(x: o.x + dx * 30, y: o.y + dy * 20))
        ic1.curve(to: NSPoint(x: o.x + dx * 55, y: o.y + dy * 50),
                  controlPoint1: NSPoint(x: o.x + dx * 48, y: o.y + dy * 18),
                  controlPoint2: NSPoint(x: o.x + dx * 52, y: o.y + dy * 38))
        ic1.lineWidth = 2; ic1.stroke()
        
        let ic2 = NSBezierPath()
        ic2.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 30))
        ic2.curve(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 55),
                  controlPoint1: NSPoint(x: o.x + dx * 18, y: o.y + dy * 48),
                  controlPoint2: NSPoint(x: o.x + dx * 38, y: o.y + dy * 52))
        ic2.lineWidth = 2; ic2.stroke()
        
        let id1 = NSBezierPath()
        id1.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50))
        id1.curve(to: NSPoint(x: o.x + dx * 70, y: o.y + dy * 40),
                  controlPoint1: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55),
                  controlPoint2: NSPoint(x: o.x + dx * 65, y: o.y + dy * 42))
        id1.lineWidth = 1.5; id1.stroke()
        let id2 = NSBezierPath()
        id2.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50))
        id2.curve(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 70),
                  controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 60),
                  controlPoint2: NSPoint(x: o.x + dx * 42, y: o.y + dy * 65))
        id2.lineWidth = 1.5; id2.stroke()
        
        drawLeaf(at: NSPoint(x: o.x + dx * 15, y: o.y + dy * 40), angle: atan2(dy, dx) + .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 70), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 20, y: o.y + dy * 110), angle: atan2(dy, dx) + .pi/5, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 10, y: o.y + dy * 150), angle: atan2(dy, dx) - .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 18, y: o.y + dy * 195), angle: atan2(dy, dx) + .pi/6, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 15, y: o.y + dy * 240), angle: atan2(dy, dx) - .pi/4, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 20, y: o.y + dy * 265), angle: atan2(dy, dx) + .pi/3, size: 5)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 15), angle: atan2(dy, dx) - .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 70, y: o.y + dy * 8), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 110, y: o.y + dy * 20), angle: atan2(dy, dx) - .pi/5, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 150, y: o.y + dy * 10), angle: atan2(dy, dx) + .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 195, y: o.y + dy * 18), angle: atan2(dy, dx) - .pi/6, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 240, y: o.y + dy * 15), angle: atan2(dy, dx) + .pi/4, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 265, y: o.y + dy * 20), angle: atan2(dy, dx) - .pi/3, size: 5)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 28), angle: atan2(dy, dx), size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55), angle: atan2(dy, dx) + .pi/2, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 85, y: o.y + dy * 88), angle: atan2(dy, dx) - .pi/4, size: 7)
        
        drawLeaf(at: NSPoint(x: o.x + dx * 45, y: o.y + dy * 130), angle: .pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 130, y: o.y + dy * 45), angle: -.pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 215), angle: .pi/4, size: 5)
        drawLeaf(at: NSPoint(x: o.x + dx * 215, y: o.y + dy * 30), angle: -.pi/4, size: 5)
        
        let dotPositions: [(CGFloat, CGFloat)] = [
            (8, 25), (25, 8), (15, 15), (40, 40),
            (60, 60), (80, 80), (35, 55), (55, 35),
            (10, 90), (90, 10), (5, 130), (130, 5),
            (15, 170), (170, 15), (10, 210), (210, 10),
            (18, 250), (250, 18), (45, 100), (100, 45)
        ]
        for (px, py) in dotPositions {
            NSBezierPath(ovalIn: NSRect(x: o.x + dx*px - 2, y: o.y + dy*py - 2, width: 4, height: 4)).fill()
        }
    }
}

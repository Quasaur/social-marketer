//
//  QuoteGraphicGenerator+BordersSacredCeltic.swift
//  SocialMarketer
//
//  Sacred Geometry and Celtic Knot border styles
//

import AppKit

extension QuoteGraphicGenerator {
    
    // MARK: - 3. Sacred Geometry — Flower of Life
    
    func drawSacredGeometryBorder() {
        let w = imageSize.width, h = imageSize.height
        
        let circR: CGFloat = 16
        let positions: [(CGFloat, CGFloat)] = [
            (w/2, 35), (w/2, h-35), (35, h/2), (w-35, h/2),
            (80, 80), (w-80, 80), (80, h-80), (w-80, h-80)
        ]
        goldColor.setStroke()
        for (cx, cy) in positions {
            strokeOval(center: NSPoint(x: cx, y: cy), radius: circR, lineWidth: 1.2)
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                strokeOval(center: NSPoint(x: cx + circR * cos(a), y: cy + circR * sin(a)),
                          radius: circR, lineWidth: 0.8)
            }
        }
    }
    
    // MARK: - 4. Celtic Knot — Woven interlace with knot corners
    
    func drawCelticKnotBorder() {
        let w = imageSize.width, h = imageSize.height
        
        for (inset, lw, radius): (CGFloat, CGFloat, CGFloat) in [(25, 3, 20), (40, 1.5, 14), (55, 3, 8)] {
            let rect = NSRect(x: inset, y: inset, width: w-inset*2, height: h-inset*2)
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.lineWidth = lw
            path.stroke()
        }
        
        let ki: CGFloat = 40
        for (cx, cy) in [(ki, ki), (w-ki, ki), (ki, h-ki), (w-ki, h-ki)] {
            let knotR: CGFloat = 18
            let o1 = NSBezierPath(ovalIn: NSRect(x: cx-knotR, y: cy-knotR/2, width: knotR*2, height: knotR))
            o1.lineWidth = 2.5; o1.stroke()
            let o2 = NSBezierPath(ovalIn: NSRect(x: cx-knotR/2, y: cy-knotR, width: knotR, height: knotR*2))
            o2.lineWidth = 2.5; o2.stroke()
            goldColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx-4, y: cy-4, width: 8, height: 8)).fill()
        }
        
        let step: CGFloat = 55
        for x in stride(from: ki + step, to: w - ki, by: step) {
            drawKnotCross(at: NSPoint(x: x, y: 40))
            drawKnotCross(at: NSPoint(x: x, y: h - 40))
        }
        for y in stride(from: ki + step, to: h - ki, by: step) {
            drawKnotCross(at: NSPoint(x: 40, y: y))
            drawKnotCross(at: NSPoint(x: w - 40, y: y))
        }
    }
    
    private func drawKnotCross(at p: NSPoint) {
        let s: CGFloat = 10
        let path = NSBezierPath()
        path.move(to: NSPoint(x: p.x-s, y: p.y)); path.line(to: NSPoint(x: p.x+s, y: p.y))
        path.move(to: NSPoint(x: p.x, y: p.y-s)); path.line(to: NSPoint(x: p.x, y: p.y+s))
        path.lineWidth = 2; path.stroke()
        for (dx, dy) in [(-s, CGFloat(0)), (s, CGFloat(0)), (CGFloat(0), -s), (CGFloat(0), s)] {
            let oval = NSBezierPath(ovalIn: NSRect(x: p.x+dx-3, y: p.y+dy-3, width: 6, height: 6))
            oval.lineWidth = 1; oval.stroke()
        }
    }
}

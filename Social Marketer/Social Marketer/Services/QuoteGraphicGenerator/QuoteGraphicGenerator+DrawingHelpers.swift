//
//  QuoteGraphicGenerator+DrawingHelpers.swift
//  SocialMarketer
//
//  Drawing helper methods for QuoteGraphicGenerator
//

import AppKit

extension QuoteGraphicGenerator {
    
    func strokeRect(_ rect: NSRect, lineWidth: CGFloat) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }
    
    func strokeOval(center: NSPoint, radius: CGFloat, lineWidth: CGFloat) {
        let oval = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                width: radius*2, height: radius*2))
        oval.lineWidth = lineWidth
        oval.stroke()
    }
    
    func fillDiamond(at p: NSPoint, size: CGFloat) {
        let d = NSBezierPath()
        d.move(to: NSPoint(x: p.x, y: p.y - size))
        d.line(to: NSPoint(x: p.x + size, y: p.y))
        d.line(to: NSPoint(x: p.x, y: p.y + size))
        d.line(to: NSPoint(x: p.x - size, y: p.y))
        d.close()
        d.fill()
    }
    
    /// Draw a small teardrop/leaf shape
    func drawLeaf(at center: NSPoint, angle: CGFloat, size: CGFloat) {
        let path = NSBezierPath()
        let tip = NSPoint(x: center.x + size * cos(angle), y: center.y + size * sin(angle))
        let base = NSPoint(x: center.x - size * 0.3 * cos(angle), y: center.y - size * 0.3 * sin(angle))
        let perpAngle = angle + .pi / 2
        let cp1 = NSPoint(x: center.x + size * 0.6 * cos(perpAngle), y: center.y + size * 0.6 * sin(perpAngle))
        let cp2 = NSPoint(x: center.x - size * 0.6 * cos(perpAngle), y: center.y - size * 0.6 * sin(perpAngle))
        path.move(to: base)
        path.curve(to: tip, controlPoint1: cp1, controlPoint2: NSPoint(x: tip.x + size*0.2*cos(perpAngle), y: tip.y + size*0.2*sin(perpAngle)))
        path.curve(to: base, controlPoint1: NSPoint(x: tip.x - size*0.2*cos(perpAngle), y: tip.y - size*0.2*sin(perpAngle)), controlPoint2: cp2)
        path.fill()
    }
}

// MARK: - NSBezierPath convenience
extension NSBezierPath {
    @discardableResult
    func apply(_ block: (NSBezierPath) -> Void) -> NSBezierPath {
        block(self)
        return self
    }
}

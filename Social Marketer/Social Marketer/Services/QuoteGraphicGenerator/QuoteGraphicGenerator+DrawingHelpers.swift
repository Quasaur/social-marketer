//
//  QuoteGraphicGenerator+DrawingHelpers.swift
//  SocialMarketer
//
//  Drawing helper methods for QuoteGraphicGenerator
//

import AppKit

// MARK: - Corner Configuration

/// Configuration for drawing corners consistently across border styles
struct CornerConfig {
    let position: (x: CGFloat, y: CGFloat)
    let direction: (dx: CGFloat, dy: CGFloat)
    
    /// Generate corner configurations for a rectangle
    /// - Parameters:
    ///   - rect: The rectangle to generate corners for
    ///   - inset: Distance from edges
    /// - Returns: Array of corner configs (top-left, top-right, bottom-left, bottom-right)
    static func corners(in rect: NSRect, inset: CGFloat) -> [CornerConfig] {
        let w = rect.width
        let h = rect.height
        return [
            CornerConfig(position: (inset, inset), direction: (1, 1)),
            CornerConfig(position: (w - inset, inset), direction: (-1, 1)),
            CornerConfig(position: (inset, h - inset), direction: (1, -1)),
            CornerConfig(position: (w - inset, h - inset), direction: (-1, -1))
        ]
    }
    
    /// Convert to NSPoint for the corner origin
    var origin: NSPoint {
        NSPoint(x: position.x, y: position.y)
    }
}

// MARK: - Cached Colors

/// Pre-computed gold colors with varying alpha for Modern Glow effect
struct CachedGoldColors {
    /// Gold color RGB values
    private static let red: CGFloat = 212/255
    private static let green: CGFloat = 175/255
    private static let blue: CGFloat = 55/255
    
    /// Pre-computed colors for Modern Glow border (8 layers)
    static let modernGlow: [NSColor] = (0..<8).map { i in
        let alpha = CGFloat(0.08 + (1.0 - Double(i) / 7.0) * 0.92)
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// Pre-computed corner glow colors (4 sizes with decreasing alpha)
    static let cornerGlow: [(radius: CGFloat, alpha: CGFloat)] = [
        (14, 0.1), (9, 0.3), (5, 0.7), (2.5, 1.0)
    ]
}

// MARK: - Drawing Helpers Extension

extension QuoteGraphicGenerator {
    
    // MARK: - Basic Shape Drawing
    
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
    
    /// Fill a circle at the given center point with the given diameter
    func fillCircle(at center: NSPoint, diameter: CGFloat) {
        let radius = diameter / 2
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                     width: diameter, height: diameter)).fill()
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
    
    // MARK: - Corner Drawing
    
    /// Draw corners using a configuration array
    /// - Parameters:
    ///   - rect: The rectangle to draw corners in
    ///   - inset: Distance from edges
    ///   - cornerDrawer: Closure that draws each corner
    func drawCorners(
        in rect: NSRect,
        inset: CGFloat = 30,
        cornerDrawer: (NSPoint, CGFloat, CGFloat) -> Void
    ) {
        for corner in CornerConfig.corners(in: rect, inset: inset) {
            cornerDrawer(
                NSPoint(x: corner.position.x, y: corner.position.y),
                corner.direction.dx,
                corner.direction.dy
            )
        }
    }
    
    /// Draw leaf sequences at corner positions
    /// - Parameters:
    ///   - leaves: Array of (px, py) offsets from corner origin
    ///   - corner: The corner configuration
    ///   - baseAngle: Base angle for leaf orientation (computed from dx, dy)
    ///   - size: Leaf size
    func drawCornerLeaves(
        leaves: [(CGFloat, CGFloat)],
        at corner: CornerConfig,
        baseAngle: CGFloat,
        size: CGFloat
    ) {
        let (dx, dy) = (corner.direction.dx, corner.direction.dy)
        for (px, py) in leaves {
            drawLeaf(
                at: NSPoint(x: corner.position.x + dx*px, y: corner.position.y + dy*py),
                angle: baseAngle,
                size: size
            )
        }
    }
    
    /// Draw dot patterns at corner positions
    /// - Parameters:
    ///   - dots: Array of (px, py) offsets from corner origin
    ///   - corner: The corner configuration
    ///   - diameter: Dot diameter
    func drawCornerDots(
        dots: [(CGFloat, CGFloat)],
        at corner: CornerConfig,
        diameter: CGFloat
    ) {
        let (dx, dy) = (corner.direction.dx, corner.direction.dy)
        for (px, py) in dots {
            fillCircle(
                at: NSPoint(x: corner.position.x + dx*px, y: corner.position.y + dy*py),
                diameter: diameter
            )
        }
    }
    
    // MARK: - Line Width Constants
    
    /// Standard line widths used across border styles
    enum LineWidth: CGFloat {
        case hairline = 0.5
        case thin = 1.0
        case light = 1.5
        case medium = 2.0
        case thick = 2.5
        case heavy = 3.0
        case extraThick = 4.0
    }
}

// MARK: - NSBezierPath convenience

extension NSBezierPath {
    @discardableResult
    func apply(_ block: (NSBezierPath) -> Void) -> NSBezierPath {
        block(self)
        return self
    }
    
    /// Stroke with specified line width
    func stroke(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        stroke()
    }
}

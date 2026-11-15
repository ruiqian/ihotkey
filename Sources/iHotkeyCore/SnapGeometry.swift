import Foundation
import CoreGraphics

/// Pure layout math. All rects here use Cocoa screen coordinates
/// (origin bottom-left, y grows upward) unless stated otherwise.
public enum SnapGeometry {

    /// Fractions a "half" action cycles through when pressed repeatedly.
    public static let cycleFractions: [CGFloat] = [1.0 / 2, 2.0 / 3, 1.0 / 3]

    /// Convert a top-left based unit rect into an absolute rect inside `visible`,
    /// applying `gap` points between windows and around the screen edge.
    public static func rect(forUnit unit: CGRect, in visible: CGRect, gap: CGFloat = 0) -> CGRect {
        let area = visible.insetBy(dx: gap / 2, dy: gap / 2)
        let x = area.minX + unit.minX * area.width
        let w = unit.width * area.width
        let h = unit.height * area.height
        // unit.y is measured from the top; flip into Cocoa's bottom-left space.
        let y = area.maxY - (unit.minY + unit.height) * area.height
        let raw = CGRect(x: x, y: y, width: w, height: h)
        return raw.insetBy(dx: gap / 2, dy: gap / 2).integral
    }

    /// Unit rect for a half action at a given cycle fraction.
    public static func halfUnit(_ action: SnapAction, fraction f: CGFloat) -> CGRect? {
        switch action {
        case .leftHalf: return CGRect(x: 0, y: 0, width: f, height: 1)
        case .rightHalf: return CGRect(x: 1 - f, y: 0, width: f, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: f)
        case .bottomHalf: return CGRect(x: 0, y: 1 - f, width: 1, height: f)
        default: return nil
        }
    }

    /// Target rect for a region action. When `cycle` is on and the window already
    /// sits at the current step of a half action, advance to the next fraction.
    public static func target(
        for action: SnapAction,
        current: CGRect,
        visible: CGRect,
        gap: CGFloat = 0,
        cycle: Bool = true
    ) -> CGRect? {
        if action.supportsCycling {
            var nextIndex = 0
            if cycle {
                for (i, f) in cycleFractions.enumerated() {
                    if let u = halfUnit(action, fraction: f),
                       approximatelyEqual(rect(forUnit: u, in: visible, gap: gap), current) {
                        nextIndex = (i + 1) % cycleFractions.count
                        break
                    }
                }
            }
            guard let unit = halfUnit(action, fraction: cycleFractions[nextIndex]) else { return nil }
            return rect(forUnit: unit, in: visible, gap: gap)
        }

        switch action {
        case .center:
            return centered(current, in: visible)
        case .maximizeHeight:
            let area = visible.insetBy(dx: gap, dy: gap)
            return CGRect(x: current.minX.rounded(), y: area.minY.rounded(),
                          width: current.width, height: area.height.rounded())
        default:
            guard let unit = action.unitRect else { return nil }
            return rect(forUnit: unit, in: visible, gap: gap)
        }
    }

    /// Keep size (clamped to the screen), center it.
    public static func centered(_ frame: CGRect, in visible: CGRect) -> CGRect {
        let w = min(frame.width, visible.width)
        let h = min(frame.height, visible.height)
        // Round the origin only: `.integral` would grow the size by a pixel when
        // the origin falls on a half point, making the window creep larger.
        return CGRect(
            x: (visible.midX - w / 2).rounded(),
            y: (visible.midY - h / 2).rounded(),
            width: w, height: h
        )
    }

    /// Move a window to another screen preserving its relative position and size.
    public static func move(_ frame: CGRect, from source: CGRect, to dest: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return centered(frame, in: dest) }
        let rx = (frame.minX - source.minX) / source.width
        let ry = (frame.minY - source.minY) / source.height
        let rw = frame.width / source.width
        let rh = frame.height / source.height
        var r = CGRect(
            x: dest.minX + rx * dest.width,
            y: dest.minY + ry * dest.height,
            width: min(rw * dest.width, dest.width),
            height: min(rh * dest.height, dest.height)
        )
        // Clamp inside destination.
        r.origin.x = max(dest.minX, min(r.minX, dest.maxX - r.width))
        r.origin.y = max(dest.minY, min(r.minY, dest.maxY - r.height))
        return CGRect(x: r.minX.rounded(), y: r.minY.rounded(), width: r.width.rounded(), height: r.height.rounded())
    }

    /// Index of the screen that contains most of `frame`.
    public static func bestScreenIndex(for frame: CGRect, screens: [CGRect]) -> Int? {
        var best: (Int, CGFloat)? = nil
        for (i, s) in screens.enumerated() {
            let inter = s.intersection(frame)
            let area = inter.isNull ? 0 : inter.width * inter.height
            if best == nil || area > best!.1 { best = (i, area) }
        }
        if let b = best, b.1 > 0 { return b.0 }
        // Fallback: nearest screen center.
        let c = CGPoint(x: frame.midX, y: frame.midY)
        return screens.indices.min(by: { distance(screens[$0], c) < distance(screens[$1], c) })
    }

    private static func distance(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = r.midX - p.x, dy = r.midY - p.y
        return dx * dx + dy * dy
    }

    // MARK: - Coordinate conversion

    /// Cocoa (bottom-left origin) ⇄ Accessibility/Quartz (top-left origin of the
    /// primary screen). The conversion is its own inverse.
    public static func flip(_ rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}

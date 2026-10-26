import Foundation
import CoreGraphics

struct MoverPolicy {
    var interval: TimeInterval = 60
    private(set) var enabled = true
    private var armedAt: TimeInterval = 0
    private var lastMove: TimeInterval = 0

    mutating func setEnabled(_ value: Bool, now: TimeInterval) {
        enabled = value
        reset(now: now)
    }
    mutating func reset(now: TimeInterval) { armedAt = now; lastMove = now }
    mutating func didMove(now: TimeInterval) { lastMove = now }
    func shouldMove(now: TimeInterval, idle: TimeInterval, available: Bool, buttonDown: Bool) -> Bool {
        enabled && available && !buttonDown && idle.isFinite && idle >= interval
            && now - armedAt >= interval && now - lastMove >= interval
    }
}

func movementTarget(_ point: CGPoint, bounds: CGRect, direction: CGFloat) -> CGPoint {
    guard bounds.width > 2, bounds.height > 2 else { return point }
    let step = direction >= 0 ? CGFloat(2) : CGFloat(-2)
    let candidate = point.x + step
    let x = candidate < bounds.minX || candidate >= bounds.maxX ? point.x - step : candidate
    return CGPoint(x: min(max(x, bounds.minX), bounds.maxX - 1), y: point.y)
}

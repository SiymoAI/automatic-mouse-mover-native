import Foundation
import CoreGraphics
@main struct PolicyTests {
    static func main() {
        var p = MoverPolicy(); p.reset(now: 100)
        func eligible(_ now: Double, _ idle: Double, _ available: Bool = true, _ down: Bool = false) -> Bool { p.shouldMove(now: now, idle: idle, available: available, buttonDown: down) }
        precondition(!eligible(159, 500), "wait a full interval after start")
        precondition(!eligible(160, 59), "recent input suppresses motion")
        precondition(eligible(160, 60), "idle boundary")
        precondition(!eligible(160, 100, false), "locked/sleeping/permission denied")
        precondition(!eligible(160, 100, true, true), "drag/modifier suppression")
        precondition(!eligible(160, .infinity), "invalid idle")
        p.didMove(now: 160); precondition(!eligible(219, 500)); precondition(eligible(220,60))
        p.setEnabled(false, now: 220); precondition(!eligible(500,500))
        p.setEnabled(true, now: 500); precondition(!eligible(559,500)); precondition(eligible(560,60))
        p.reset(now: 600); precondition(!eligible(601,500), "no immediate move on wake")
        p.interval = 120; precondition(!eligible(719,500)); precondition(eligible(720,120))
        for bounds in [CGRect(x:0,y:0,width:1920,height:1080), CGRect(x:-1920,y:-1080,width:1920,height:1080)] {
            for point in [CGPoint(x:bounds.minX,y:bounds.minY), CGPoint(x:bounds.maxX-1,y:bounds.maxY-1), CGPoint(x:bounds.midX,y:bounds.midY)] {
                for direction: CGFloat in [-1,1] {
                    let target = movementTarget(point,bounds:bounds,direction:direction)
                    precondition(bounds.contains(target)); precondition(target != point); precondition(target.y == point.y)
                }
            }
        }
        print("PASS: idle boundaries, input suppression, stop/start, wake cooldown, invalid idle, interval, screen edges and negative monitor coordinates")
    }
}

// Optional real OS integration test. Run with the app's About window focused.
// Posts only a Shift press/release (no characters) through the HID event tap.
import AppKit
import ApplicationServices
@main struct MacInputIntegration {
    static func main() {
        guard AXIsProcessTrusted() else { print("SKIP: this test host needs Accessibility permission"); exit(77) }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        guard flags.intersection([.maskShift,.maskControl,.maskAlternate,.maskCommand]).isEmpty else { print("SKIP: a modifier is already held"); exit(77) }
        let anyInput = CGEventType(rawValue: UInt32.max)!
        let before = CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:anyInput)
        let source = CGEventSource(stateID:.hidSystemState)!
        let down = CGEvent(keyboardEventSource:source,virtualKey:56,keyDown:true)!
        let up = CGEvent(keyboardEventSource:source,virtualKey:56,keyDown:false)!
        down.type = .flagsChanged; down.flags = flags.union(.maskShift)
        up.type = .flagsChanged; up.flags = flags
        down.post(tap:.cghidEventTap)
        Thread.sleep(forTimeInterval:0.05)
        up.post(tap:.cghidEventTap)
        Thread.sleep(forTimeInterval:0.1)
        let after = CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:anyInput)
        precondition(after < 1, "keyboard activity must reset the system idle counter")
        print("PASS: keyboard input reset idle from \(before) seconds to \(after) seconds; no characters typed")
    }
}

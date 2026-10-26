import AppKit
import ApplicationServices
import ServiceManagement

let repository = "https://github.com/SiymoAI/automatic-mouse-mover-native"
let appVersion = "1.0.0"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var timer: Timer?
    var policy = MoverPolicy()
    var sleeping = false
    var sessionActive = true
    var window: NSWindow?
    var lastMessage = "Waiting for inactivity"
    var moves = 0
    var diagnostics: URL?
    let defaults = UserDefaults.standard
    let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let detailItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var startItem: NSMenuItem!
    var stopItem: NSMenuItem!
    var permissionItem: NSMenuItem!
    var loginItem: NSMenuItem!
    var intervalItems: [NSMenuItem] = []
    var observers: [NSObjectProtocol] = []
    var testing: Bool { CommandLine.arguments.contains("--self-test") }
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    // kCGAnyInputEventType includes keyboard, mouse, and tablet input. .null does not.
    var idleSeconds: TimeInterval { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "ai.siymo.mousemover").filter({ $0.processIdentifier != getpid() }).count > 0 {
            NSApp.terminate(nil); return
        }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--diagnostics"), args.count > i + 1 { diagnostics = URL(fileURLWithPath: args[i+1]) }
        let saved = defaults.integer(forKey: "interval")
        policy.interval = [30,60,120,300].contains(saved) ? Double(saved) : 60
        policy.setEnabled(defaults.object(forKey: "enabled") as? Bool ?? true, now: now)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Automatic Mouse Mover")
        statusItem.button?.setAccessibilityLabel("Automatic Mouse Mover")
        menu.delegate = self
        menu.autoenablesItems = false
        stateItem.isEnabled = false; detailItem.isEnabled = false
        menu.addItem(NSMenuItem(title: "Automatic Mouse Mover", action: nil, keyEquivalent: ""))
        menu.addItem(stateItem); menu.addItem(detailItem); menu.addItem(.separator())
        startItem = add("Start", #selector(start)); stopItem = add("Stop", #selector(stop))
        let interval = NSMenuItem(title: "Move after inactivity", action: nil, keyEquivalent: "")
        let submenu = NSMenu(); submenu.autoenablesItems = false
        for seconds in [30,60,120,300] {
            let item = NSMenuItem(title: seconds < 60 ? "30 seconds" : "\(seconds / 60) minute\(seconds == 60 ? "" : "s")", action: #selector(changeInterval(_:)), keyEquivalent: "")
            item.tag = seconds; item.target = self; submenu.addItem(item); intervalItems.append(item)
        }
        interval.submenu = submenu; menu.addItem(interval)
        loginItem = add("Launch at login", #selector(toggleLogin))
        menu.addItem(.separator())
        permissionItem = add("Allow mouse movement…", #selector(showPermissions))
        _ = add("About Automatic Mouse Mover…", #selector(showAbout))
        menu.addItem(.separator()); _ = add("Quit", #selector(quit), key: "q")
        statusItem.menu = menu
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self else { return }
                if note.name == NSWorkspace.sessionDidResignActiveNotification { self.sessionActive = false } else { self.sleeping = true }
                self.policy.reset(now: self.now); self.refresh()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.sleeping = false; self.sessionActive = true; self.policy.reset(now: self.now); self.refresh()
            })
        }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
        if args.contains("--show-about") { showAbout() }
        if args.contains("--self-test") { DispatchQueue.main.async { self.selfTest() } }
    }
    @discardableResult func add(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key); item.target = self; menu.addItem(item); return item
    }
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    var unlocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool != true && session[kCGSessionOnConsoleKey as String] as? Bool == true
    }
    var available: Bool { !sleeping && sessionActive && unlocked && AXIsProcessTrusted() }
    var buttonDown: Bool {
        (0..<5).contains { CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!) }
        || !NSEvent.modifierFlags.intersection([.shift,.control,.option,.command]).isEmpty
    }
    func tick() {
        let idle = idleSeconds
        if !available { policy.reset(now: now) }
        if policy.shouldMove(now: now, idle: idle, available: available, buttonDown: buttonDown) { move() }
        refresh()
    }
    func move() {
        guard available, !buttonDown, idleSeconds >= policy.interval, let point = CGEvent(source: nil)?.location else { return }
        var ids = [CGDirectDisplayID](repeating: 0, count: 32); var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &ids, &count) == .success,
              let display = ids.prefix(Int(count)).first(where: { CGDisplayBounds($0).contains(point) }) else { return }
        let target = movementTarget(point, bounds: CGDisplayBounds(display), direction: moves % 2 == 0 ? 1 : -1)
        guard let source = CGEventSource(stateID: .hidSystemState), let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: target, mouseButton: .left) else { return }
        // Posting one bounded movement avoids a delayed return fighting real user input.
        event.post(tap: .cghidEventTap); policy.didMove(now: now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let after = CGEvent(source: nil)?.location ?? point
            if after != point { self.moves += 1; self.lastMessage = "Last move: \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))" }
            else { self.lastMessage = "Movement blocked — check Accessibility" }
            self.refresh()
        }
    }
    func refresh() {
        let state = !policy.enabled ? "Stopped" : !AXIsProcessTrusted() ? "Accessibility permission needed" : !available ? "Paused while screen is unavailable" : "Running · moves only when idle"
        stateItem.title = state; detailItem.title = policy.enabled ? lastMessage : "Click Start to resume"
        startItem.isEnabled = !policy.enabled; stopItem.isEnabled = policy.enabled
        for item in intervalItems { item.state = Double(item.tag) == policy.interval ? .on : .off }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionItem.isHidden = AXIsProcessTrusted()
        statusItem.button?.appearsDisabled = !policy.enabled
        statusItem.button?.toolTip = "Automatic Mouse Mover — \(state)"
        writeDiagnostics(state: state)
    }
    @objc func start() { policy.setEnabled(true, now: now); defaults.set(true, forKey: "enabled"); lastMessage = "Waiting for inactivity"; refresh(); if !AXIsProcessTrusted() && !testing { showPermissions() } }
    @objc func stop() { policy.setEnabled(false, now: now); defaults.set(false, forKey: "enabled"); refresh() }
    @objc func changeInterval(_ sender: NSMenuItem) { policy.interval = Double(sender.tag); defaults.set(sender.tag, forKey: "interval"); policy.reset(now: now); refresh() }
    @objc func toggleLogin() {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } }
        catch { let alert = NSAlert(); alert.messageText = "Could not change launch at login"; alert.informativeText = "Move the app to Applications, then try again. \(error.localizedDescription)"; alert.runModal() }
        refresh()
    }
    @objc func showPermissions() { showWindow(permission: true) }
    @objc func showAbout() { showWindow(permission: false) }
    func showWindow(permission: Bool) {
        window?.close()
        let panel = NSWindow(contentRect: NSRect(x:0,y:0,width:460,height:360), styleMask: [.titled,.closable], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.title = permission ? "Allow mouse movement" : "Automatic Mouse Mover"; panel.center()
        let content = NSStackView(); content.orientation = .vertical; content.alignment = .centerX; content.spacing = 16; content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 32), content.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -32), content.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor)])
        let icon = NSImageView(image: NSImage(systemSymbolName: "computermouse", accessibilityDescription: nil)!); icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular); content.addArrangedSubview(icon)
        let title = NSTextField(labelWithString: permission ? "One permission. Then you’re set." : "Automatic Mouse Mover"); title.font = .boldSystemFont(ofSize: 21); content.addArrangedSubview(title)
        let text = NSTextField(wrappingLabelWithString: permission ? "Enable Automatic Mouse Mover in System Settings → Privacy & Security → Accessibility. This lets the app gently move your pointer after you stop using your Mac.\n\nThe app stays in your menu bar. It never records your screen or keystrokes." : "A quiet companion for your menu bar.\nMoves your pointer only after inactivity.\n\nVersion \(appVersion) · Apple Silicon native\nSiymoAI · Inspired by Prashant Gupta’s AMM\nNo accounts. No tracking. No network requests.")
        text.alignment = .center; text.font = .systemFont(ofSize: 13); text.textColor = .secondaryLabelColor; content.addArrangedSubview(text)
        let button = NSButton(title: permission ? "Open Accessibility Settings" : "Source & Downloads", target: self, action: permission ? #selector(openAccessibility) : #selector(openSource)); button.bezelStyle = .rounded; content.addArrangedSubview(button)
        window = panel; panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func openSource() { NSWorkspace.shared.open(URL(string: repository)!) }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
    func writeDiagnostics(state: String) {
        guard let diagnostics else { return }
        let data: [String:Any] = ["version":appVersion,"architecture":"arm64","state":state,"enabled":policy.enabled,"permission":AXIsProcessTrusted(),"available":available,"moves":moves,"interval":policy.interval,"idleSeconds":idleSeconds,"pid":getpid(),"menuBarOnly":NSApp.activationPolicy() == .accessory]
        if let json = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted,.sortedKeys]) { try? json.write(to: diagnostics, options: .atomic) }
    }
    func selfTest() {
        let previous = defaults.dictionaryRepresentation()
        let originalEnabled = policy.enabled; let originalInterval = policy.interval
        menu.performActionForItem(at: menu.index(of: stopItem)); let stopOK = !policy.enabled && startItem.isEnabled && !stopItem.isEnabled
        menu.performActionForItem(at: menu.index(of: startItem))
        let startOK = policy.enabled && !startItem.isEnabled && stopItem.isEnabled
        intervalItems[2].menu?.performActionForItem(at: 2); let intervalOK = policy.interval == 120 && intervalItems[2].state == .on
        sleeping = true; refresh(); let sleepOK = !available
        sleeping = false; sessionActive = false; refresh(); let inactiveOK = !available
        sessionActive = true
        policy.interval = originalInterval; policy.setEnabled(originalEnabled, now: now)
        for key in ["enabled","interval"] { if let value = previous[key] { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) } }
        let report: [String:Any] = ["passed":stopOK && startOK && intervalOK && sleepOK && inactiveOK,"stop":stopOK,"start":startOK,"interval":intervalOK,"sleep":sleepOK,"inactiveSession":inactiveOK,"menuBarOnly":NSApp.activationPolicy() == .accessory,"permission":AXIsProcessTrusted(),"architecture":"arm64"]
        if let diagnostics, let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]) { try? data.write(to: diagnostics, options:.atomic) }
        NSApp.terminate(nil)
    }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

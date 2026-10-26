# Validation for v1.0.0

Tested on 25 October 2026, using a real Apple Silicon Mac and a real Windows 11 x64 computer. The initial Windows development build used .NET 8; the release was rebuilt with **.NET 10 LTS** and the installed app’s interactive test suite was rerun successfully.

## Original app

Cloned `prashantgupta24/automatic-mouse-mover` with GitHub CLI. Inspected its tray controls, activity tracker, movement logic, and MIT license. Downloaded the upstream v1.3.0 `amm.x86.zip`, confirmed that its executable is **x86_64**, and ran it under Rosetta on the Apple Silicon Mac. Its log reported a successful pointer movement after the first 60-second inactivity interval.

## macOS arm64

- Compiled with an explicit `arm64-apple-macos13.0` target. Verified the executable architecture and code signature.
- Verified and mounted the DMG, checked its Applications shortcut, copied the app into Applications, and launched it through Launch Services.
- Inspected the installed app’s real About window and captured the screenshot with desktop UI tools.
- Ran native app tests through the actual menu action callbacks: Start, Stop, interval selection, and UI enabled/check states.
- Tested movement policy boundaries, rate limiting, resume cooldown, disabled state, invalid idle values, button/modifier suppression, and positive/negative monitor coordinates.
- Ran repeated 60-second idle cycles in the actual arm64 executable. Pointer position changed and the system idle counter reset after movement. The implementation uses `kCGAnyInputEventType`, covering all input types.
- Ran an OS input integration test using a harmless Shift press/release: the real system idle counter reset from approximately 53 seconds to 0.1 seconds. The running app then waited another full interval before moving.
- Checked that the app uses the accessory activation policy, so normal launches have no Dock icon or terminal window.
- Tested permission denial through a separately launched GUI app: it remained in the menu bar and reported that Accessibility permission was needed.

**Permission scope:** the movement tests launched the executable from a host that already had Accessibility approval. The independently launched `.app` has a separate permission identity and still needs the user to approve it in System Settings. This approval was not silently granted or bypassed.

Sleep and session-unavailable branches were exercised in the app tests. A complete physical sleep/wake cycle, login-item approval, Intel Macs, and older macOS versions were not tested on hardware. The public app is ad hoc signed, not Developer ID signed or notarized.

## Windows x64

- Built the release on the real Windows machine with .NET SDK 10.0.403, targeting `net10.0-windows` and `win-x64`; published with the runtime included.
- Verified the PE machine field is **x64** and the subsystem is **Windows GUI**, not console.
- Built the per-user Setup EXE with pinned Inno Setup 6.4.3.
- Installed from the real Setup EXE. Verified the installed executable, Start Menu shortcut, uninstaller, and a matching hash between installed and built executables.
- Uninstalled, verified that the executable was removed, reinstalled, and verified the binary match again.
- Ran the final installed app’s tests in the signed-in interactive desktop. All boolean assertions passed: actual Start/Stop menu callbacks, interval persistence, corrupt-settings recovery, idle boundary, rate limit, stop/resume cooldown, unavailable-screen and button-down policy suppression, Win32 INPUT layout, screen boundaries, tray icon, and absence of a main window.
- Verified actual mouse movement: `GetCursorPos` before and after the app’s `SendInput` call differed by two pixels. No console was launched.
- Captured the app’s real tray menu and About controls for the documentation.
- Ran the tray app through ordinary production timers for repeated 60-second inactivity cycles; verified movement and idle-counter resets.
- Disconnected the production tray app’s desktop session and observed its state change to paused, with no additional moves. Reconnected the same session, waited the full cooldown, and verified movement resumed.

The Windows 10 minimum, Windows on Arm, real secure-desktop lock/unlock, physical sleep/resume, login startup, and a multi-monitor hardware setup were not tested. Negative-coordinate display behavior and paused-state behavior were tested as deterministic cases. The Windows executable and installer are not Authenticode signed.

## Scope and reproduction

The app never records keystrokes or screenshots in normal operation. Optional diagnostic arguments write local JSON reports; Windows self-test mode additionally captures its own menu/About controls. No test reports, credentials, or machine paths are required at runtime.

Run the policy tests and build scripts described in the README. Windows interactive tests require an unlocked, connected desktop; they deliberately fail the actual-movement assertion in a disconnected or locked session. Close any running copy first because the app permits one instance per user session.

Screenshots and a machine-readable validation summary are attached to the release. GitHub Actions additionally builds and verifies both platform packages from the published source. Physical hardware tests remain separate from those automated build checks.

SiymoAI Mouse Mover is now available as a native **Apple Silicon menu bar app** and a **Windows x64 system tray app**.

### Downloads

- **Mac:** install the `macos-arm64.dmg` by dragging the app to Applications. The ZIP is an alternative.
- **Windows:** run `windows-x64-setup.exe`. It installs for the current user and includes the runtime. The portable ZIP is an alternative.
- `SHA256SUMS.txt` lists checksums for all installers and archives. Source archives are available below.

### Included

Start / Stop, inactivity intervals from 30 seconds to 5 minutes, saved preferences, optional launch at login, two-pixel pointer movement, and pause checks for locked / sleeping screens and disconnected Windows sessions. Both apps run quietly in the menu bar or tray, with no terminal window.

Built with Apple AppKit / Core Graphics and Microsoft WinForms / Win32. No accounts, telemetry, or runtime network calls (the Source & Downloads button opens the repository in your browser).

### First launch

**macOS 13+, Apple Silicon:** this build is ad hoc signed and **not Apple-notarized**. If blocked, use System Settings → Privacy & Security → Open Anyway after attempting to open the app. Enable **SiymoAI Mouse Mover** in **Privacy & Security → Accessibility** to allow pointer movement. The app detects the permission change automatically. Do not disable Gatekeeper.

**Windows 10/11, x64:** this build is **not Authenticode signed**, so SmartScreen may identify an unknown publisher. Verify the checksum and source. Windows may initially place the icon under **Show hidden icons** beside the clock.

### Validation

Built and tested on real Apple Silicon macOS and Windows 11 x64 hardware, including actual pointer movement, idle timing, Start / Stop callbacks, interval persistence, screen boundaries, and installed app checks. See [the validation notes](https://github.com/SiymoAI/siymo-mouse-mover/blob/main/docs/TESTING.md) for scope and limitations. The separately launched Mac app still needs its own user-approved Accessibility permission.

Screenshots of the native Mac window and Windows tray controls are attached. Copyright © 2026 SiymoAI. MIT licensed.

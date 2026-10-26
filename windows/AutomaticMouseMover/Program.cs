using System.Reflection;
using System.Text.Json;
using Microsoft.Win32;
namespace AutomaticMouseMover;
internal static class Program
{
    [STAThread] private static void Main(string[] args) {
        ApplicationConfiguration.Initialize();
        using var mutex = new Mutex(true, "Local\\SiymoAI.AutomaticMouseMover", out bool created);
        if (!created) return;
        try { using var context = new TrayApp(args); Application.Run(context); }
        catch (Exception e) {
            if (args.Contains("--self-test")) { var i = Array.IndexOf(args, "--self-test"); if (i + 1 < args.Length) File.WriteAllText(args[i+1], JsonSerializer.Serialize(new { passed = false, error = e.ToString() })); }
            else MessageBox.Show("Automatic Mouse Mover could not start.\n\n" + e.Message, "Automatic Mouse Mover", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
internal sealed class TrayApp : ApplicationContext
{
    internal readonly MoverPolicy Policy = new();
    private readonly NotifyIcon tray;
    private readonly ContextMenuStrip menu = new();
    private readonly System.Windows.Forms.Timer timer = new() { Interval = 1000 };
    private readonly ToolStripMenuItem state = new(""), detail = new(""), start = new("Start"), stop = new("Stop"), login = new("Launch at login");
    private readonly List<ToolStripMenuItem> intervalItems = new();
    private readonly Settings settings;
    private readonly string settingsPath;
    private readonly string? diagnostics;
    private readonly bool testing;
    private readonly Control dispatcher = new();
    private bool suspended;
    private int moves;
    private string lastMessage = "Waiting for inactivity";
    private Form? about;
    private readonly Icon appIcon;
    internal TrayApp(string[] args) {
        testing = args.Contains("--self-test");
        settingsPath = testing ? Path.Combine(Path.GetTempPath(), "amm-tests-" + Guid.NewGuid(), "settings.json") : Settings.DefaultPath;
        int d = Array.IndexOf(args, "--diagnostics"); diagnostics = d >= 0 && args.Length > d + 1 ? args[d+1] : null;
        settings = Settings.Load(settingsPath); Policy.IntervalSeconds = settings.IntervalSeconds; Policy.SetEnabled(settings.Enabled, Environment.TickCount64);
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("AutomaticMouseMover.AppIcon.ico")!;
        appIcon = new Icon(stream);
        menu.Items.Add(new ToolStripMenuItem("Automatic Mouse Mover") { Enabled = false });
        state.Enabled = detail.Enabled = false; menu.Items.Add(state); menu.Items.Add(detail); menu.Items.Add(new ToolStripSeparator());
        start.Click += (_,_) => Start(); stop.Click += (_,_) => Stop(); menu.Items.Add(start); menu.Items.Add(stop);
        var interval = new ToolStripMenuItem("Move after inactivity");
        foreach (int seconds in new[] {30,60,120,300}) {
            var item = new ToolStripMenuItem(seconds < 60 ? "30 seconds" : $"{seconds/60} minute{(seconds == 60 ? "" : "s")}") { Tag = seconds };
            item.Click += (_,_) => SetInterval(seconds); interval.DropDownItems.Add(item); intervalItems.Add(item);
        }
        menu.Items.Add(interval); login.Click += (_,_) => ToggleLogin(); menu.Items.Add(login); menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("About Automatic Mouse Mover…", null, (_,_) => ShowAbout()); menu.Items.Add(new ToolStripSeparator()); menu.Items.Add("Quit", null, (_,_) => ExitThread());
        menu.Opening += (_,_) => Refresh();
        tray = new NotifyIcon { Icon = appIcon, Text = "Automatic Mouse Mover", ContextMenuStrip = menu, Visible = true };
        tray.MouseClick += (_, e) => { if (e.Button == MouseButtons.Left) menu.Show(Cursor.Position); };
        tray.DoubleClick += (_,_) => ShowAbout();
        _ = dispatcher.Handle;
        SystemEvents.SessionSwitch += OnSessionSwitch; SystemEvents.PowerModeChanged += OnPower;
        timer.Tick += (_,_) => Tick(); timer.Start(); Refresh();
        if (args.Contains("--show-about")) ShowAbout();
        if (testing) dispatcher.BeginInvoke(new Action(() => RunTests(args[Array.IndexOf(args,"--self-test")+1])));
    }
    private void OnSessionSwitch(object sender, SessionSwitchEventArgs e) => Dispatch(() => { Policy.Reset(Environment.TickCount64); Refresh(); });
    private void OnPower(object sender, PowerModeChangedEventArgs e) => Dispatch(() => { suspended = e.Mode == PowerModes.Suspend; Policy.Reset(Environment.TickCount64); Refresh(); });
    private void Dispatch(Action action) { if (!dispatcher.IsDisposed && dispatcher.IsHandleCreated) { try { dispatcher.BeginInvoke(action); } catch (InvalidOperationException) { } } }
    internal void Start() { Policy.SetEnabled(true, Environment.TickCount64); settings.Enabled = true; Save(); lastMessage = "Waiting for inactivity"; Refresh(); }
    internal void Stop() { Policy.SetEnabled(false, Environment.TickCount64); settings.Enabled = false; Save(); Refresh(); }
    internal void SetInterval(int seconds) { Policy.IntervalSeconds = seconds; settings.IntervalSeconds = seconds; Policy.Reset(Environment.TickCount64); Save(); Refresh(); }
    private void Save() { try { settings.Save(settingsPath); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { lastMessage = "Settings could not be saved"; } }
    private static bool LoginEnabled {
        get { using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"); return key?.GetValue("SiymoAI.AutomaticMouseMover") as string == "\"" + Application.ExecutablePath + "\""; }
    }
    private void ToggleLogin() {
        try { using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"); if (LoginEnabled) key.DeleteValue("SiymoAI.AutomaticMouseMover", false); else key.SetValue("SiymoAI.AutomaticMouseMover", "\"" + Application.ExecutablePath + "\""); }
        catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException) { MessageBox.Show("Could not change launch at login.\n" + e.Message, "Automatic Mouse Mover"); }
        Refresh();
    }
    private void Tick() {
        bool available = !suspended && Native.Available;
        if (!available) Policy.Reset(Environment.TickCount64);
        if (Policy.ShouldMove(Environment.TickCount64, Native.IdleSeconds, available, Native.ButtonDown)) {
            if (Native.TryMove(moves % 2 == 0 ? 1 : -1, out var error)) { moves++; lastMessage = "Last move: " + DateTime.Now.ToShortTimeString(); }
            else lastMessage = error;
            Policy.DidMove(Environment.TickCount64);
        }
        Refresh();
    }
    private void Refresh() {
        string status = !Policy.Enabled ? "Stopped" : suspended || !Native.Available ? "Paused while screen is unavailable" : "Running · moves only when idle";
        state.Text = status; detail.Text = Policy.Enabled ? lastMessage : "Click Start to resume"; start.Enabled = !Policy.Enabled; stop.Enabled = Policy.Enabled;
        foreach (var item in intervalItems) item.Checked = (int)item.Tag! == Policy.IntervalSeconds;
        login.Checked = LoginEnabled; tray.Text = "Automatic Mouse Mover — " + (Policy.Enabled ? "Running" : "Stopped");
        if (diagnostics != null) File.WriteAllText(diagnostics, JsonSerializer.Serialize(new { version = "1.0.0", architecture = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString(), state = status, enabled = Policy.Enabled, moves, interval = Policy.IntervalSeconds, available = Native.Available, idleSeconds = Native.IdleSeconds, pid = Environment.ProcessId, session = System.Diagnostics.Process.GetCurrentProcess().SessionId, trayVisible = tray.Visible, mainWindow = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle.ToInt64() }, new JsonSerializerOptions { WriteIndented = true }));
    }
    private void ShowAbout() {
        if (about is { IsDisposed: false }) { about.Activate(); return; }
        about = new Form { Text = "Automatic Mouse Mover", ClientSize = new Size(440,330), FormBorderStyle = FormBorderStyle.FixedDialog, MaximizeBox = false, MinimizeBox = false, StartPosition = FormStartPosition.CenterScreen, Icon = appIcon, BackColor = SystemColors.Window };
        var title = new Label { Text = "Automatic Mouse Mover", Font = new Font("Segoe UI",20,FontStyle.Bold), AutoSize = false, TextAlign = ContentAlignment.MiddleCenter, Dock = DockStyle.Top, Height = 85 };
        var body = new Label { Text = "A quiet companion for your system tray.\nMoves your pointer only after inactivity.\n\nVersion 1.0.0 · Windows native\nSiymoAI · Inspired by Prashant Gupta’s AMM\n\nNo accounts. No tracking. No network requests.", Font = new Font("Segoe UI",11), AutoSize = false, TextAlign = ContentAlignment.MiddleCenter, Dock = DockStyle.Top, Height = 175 };
        var button = new Button { Text = "Source && Downloads", Width = 180, Height = 32, Top = 280, Left = 130 }; button.Click += (_,_) => System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://github.com/SiymoAI/automatic-mouse-mover-native") { UseShellExecute = true });
        about.Controls.Add(body); about.Controls.Add(title); about.Controls.Add(button); about.Show();
    }
    protected override void ExitThreadCore() { timer.Stop(); tray.Visible = false; base.ExitThreadCore(); }
    protected override void Dispose(bool disposing) {
        if (disposing) { timer.Dispose(); SystemEvents.SessionSwitch -= OnSessionSwitch; SystemEvents.PowerModeChanged -= OnPower; tray.Visible = false; tray.Dispose(); menu.Dispose(); about?.Dispose(); dispatcher.Dispose(); appIcon.Dispose(); if (testing) { try { Directory.Delete(Path.GetDirectoryName(settingsPath)!, true); } catch (IOException) { } } }
        base.Dispose(disposing);
    }
    private void RunTests(string reportPath) {
        var results = new Dictionary<string, object>();
        try {
            stop.PerformClick(); results["stopMenu"] = !Policy.Enabled && start.Enabled && !stop.Enabled;
            start.PerformClick(); results["startMenu"] = Policy.Enabled && !start.Enabled && stop.Enabled;
            intervalItems[2].PerformClick(); results["intervalPersistence"] = Settings.Load(settingsPath).IntervalSeconds == 120 && intervalItems[2].Checked;
            File.WriteAllText(settingsPath, "broken json"); results["corruptSettingsRecovery"] = Settings.Load(settingsPath).IntervalSeconds == 60;
            var p = new MoverPolicy(); p.Reset(100000);
            results["idleBoundary"] = !p.ShouldMove(159000,500,true,false) && p.ShouldMove(160000,60,true,false) && !p.ShouldMove(160000,59,true,false);
            results["suppression"] = !p.ShouldMove(160000,500,false,false) && !p.ShouldMove(160000,500,true,true);
            p.DidMove(160000); results["rateLimit"] = !p.ShouldMove(219000,500,true,false) && p.ShouldMove(220000,60,true,false);
            p.SetEnabled(false,220000); results["stopped"] = !p.ShouldMove(500000,500,true,false);
            p.SetEnabled(true,500000); results["resumeCooldown"] = !p.ShouldMove(559000,500,true,false) && p.ShouldMove(560000,60,true,false);
            results["inputStructureSize"] = Native.InputSize == (IntPtr.Size == 8 ? 40 : 28);
            results["trayVisible"] = tray.Visible; results["noMainWindow"] = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle == IntPtr.Zero;
            bool edges = true; foreach (var b in new[] { new Rectangle(0,0,1920,1080), new Rectangle(-1920,-1080,1920,1080) }) foreach (var point in new[] { b.Location,new Point(b.Right-1,b.Bottom-1) }) foreach (int dir in new[] {-1,1}) { var target = Native.Target(point,b,dir); edges &= b.Contains(target) && target != point && target.Y == point.Y; }
            results["screenEdges"] = edges;
            results["interactiveDesktop"] = Native.Available;
            if (Native.Available && !Native.ButtonDown) {
                var before = Native.CursorPosition;
                bool sent = Native.TryMove(1,out string error); Thread.Sleep(100); var after = Native.CursorPosition;
                results["actualMovement"] = sent && after != before; results["movementBefore"] = before.ToString(); results["movementAfter"] = after.ToString(); results["movementError"] = error;
            } else results["actualMovement"] = false;
            Stop(); menu.Show(new Point(80,80)); Application.DoEvents();
            using (var bitmap = new Bitmap(menu.Width,menu.Height)) { menu.DrawToBitmap(bitmap,new Rectangle(Point.Empty,bitmap.Size)); bitmap.Save(Path.ChangeExtension(reportPath,"menu.png")); }
            menu.Close(); ShowAbout(); Application.DoEvents();
            using (var bitmap = new Bitmap(about!.Width,about.Height)) { about.DrawToBitmap(bitmap,new Rectangle(Point.Empty,bitmap.Size)); bitmap.Save(Path.ChangeExtension(reportPath,"about.png")); }
            results["passed"] = results.Values.OfType<bool>().All(x=>x);
        } catch (Exception e) { results["passed"] = false; results["error"] = e.ToString(); }
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(reportPath))!);
        File.WriteAllText(reportPath, JsonSerializer.Serialize(results,new JsonSerializerOptions { WriteIndented = true })); ExitThread();
    }
}

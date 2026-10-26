using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
namespace SiymoMouseMover;
internal static class Native
{
    [StructLayout(LayoutKind.Sequential)] private struct LastInput { public uint Size, Time; }
    [StructLayout(LayoutKind.Sequential)] private struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] private struct MouseInput { public int X, Y; public uint MouseData, Flags, Time; public UIntPtr ExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] private struct InputUnion { [FieldOffset(0)] public MouseInput Mouse; }
    [StructLayout(LayoutKind.Sequential)] private struct Input { public uint Type; public InputUnion Data; }
    [DllImport("user32.dll")] private static extern bool GetLastInputInfo(ref LastInput info);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll", SetLastError = true)] private static extern uint SendInput(uint count, Input[] inputs, int size);
    [DllImport("user32.dll")] private static extern short GetAsyncKeyState(int key);
    [DllImport("user32.dll", SetLastError = true)] private static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll")] private static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool GetUserObjectInformation(IntPtr handle, int index, StringBuilder info, uint length, out uint needed);
    [DllImport("wtsapi32.dll", SetLastError = true)] private static extern bool WTSQuerySessionInformation(IntPtr server, int session, int infoClass, out IntPtr buffer, out uint bytes);
    [DllImport("wtsapi32.dll")] private static extern void WTSFreeMemory(IntPtr buffer);
    public static double IdleSeconds {
        get { var info = new LastInput { Size = (uint)Marshal.SizeOf<LastInput>() }; return GetLastInputInfo(ref info) ? unchecked((uint)Environment.TickCount - info.Time) / 1000.0 : -1; }
    }
    public static bool ButtonDown => new[] { 1, 2, 4, 5, 6, 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(key => (GetAsyncKeyState(key) & 0x8000) != 0);
    public static bool Available {
        get {
            if (!WTSQuerySessionInformation(IntPtr.Zero, Process.GetCurrentProcess().SessionId, 8, out var buffer, out var bytes)) return false;
            try { if (bytes < 4 || Marshal.ReadInt32(buffer) != 0) return false; } finally { WTSFreeMemory(buffer); }
            var desktop = OpenInputDesktop(0, false, 1); if (desktop == IntPtr.Zero) return false;
            try { var name = new StringBuilder(256); return GetUserObjectInformation(desktop, 2, name, 512, out _) && name.ToString() == "Default"; }
            finally { CloseDesktop(desktop); }
        }
    }
    public static System.Drawing.Point CursorPosition {
        get { if (!GetCursorPos(out var point)) throw new Win32Exception(); return new(point.X, point.Y); }
    }
    internal static System.Drawing.Point Target(System.Drawing.Point point, Rectangle bounds, int direction) {
        int step = direction >= 0 ? 2 : -2;
        int next = point.X + step; if (next < bounds.Left || next >= bounds.Right) next = point.X - step;
        return new(Math.Clamp(next, bounds.Left, bounds.Right - 1), point.Y);
    }
    public static bool TryMove(int direction, out string error) {
        error = "";
        if (!Available || ButtonDown) { error = "Screen unavailable or input in progress"; return false; }
        var before = CursorPosition; var bounds = Screen.FromPoint(before).Bounds; var target = Target(before, bounds, direction);
        var desktop = SystemInformation.VirtualScreen;
        var input = new Input { Type = 0, Data = new InputUnion { Mouse = new MouseInput {
            X = (int)Math.Round((target.X - desktop.Left) * 65535.0 / Math.Max(1, desktop.Width - 1)),
            Y = (int)Math.Round((target.Y - desktop.Top) * 65535.0 / Math.Max(1, desktop.Height - 1)),
            Flags = 0x0001 | 0x8000 | 0x4000 // MOVE | ABSOLUTE | VIRTUALDESK
        } } };
        if (SendInput(1, new[] { input }, Marshal.SizeOf<Input>()) != 1) { error = "Windows blocked mouse movement (" + Marshal.GetLastWin32Error() + ")"; return false; }
        return true;
    }
    public static int InputSize => Marshal.SizeOf<Input>();
}

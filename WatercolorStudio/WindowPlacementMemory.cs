using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.UI.Xaml;

namespace WatercolorStudio;

internal sealed class WindowPlacementMemory
{
    readonly Window window;
    readonly DispatcherTimer saveTimer = new() { Interval = TimeSpan.FromMilliseconds(600) };
    readonly string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Pigment", "window.json");
    bool restoring;

    public WindowPlacementMemory(Window window)
    {
        this.window = window;
        Restore();
        saveTimer.Tick += (_, _) => { saveTimer.Stop(); Save(); };
        window.AppWindow.Changed += (_, args) =>
        {
            if (!restoring && (args.DidPositionChange || args.DidSizeChange || args.DidPresenterChange))
            { saveTimer.Stop(); saveTimer.Start(); }
        };
        window.AppWindow.Closing += (_, _) => { saveTimer.Stop(); Save(); };
        window.Closed += (_, _) => saveTimer.Stop();
    }

    void Restore()
    {
        try
        {
            if (!File.Exists(path)) return;
            var saved = JsonSerializer.Deserialize<SavedPlacement>(File.ReadAllText(path));
            if (saved == null || saved.Right <= saved.Left || saved.Bottom <= saved.Top) return;
            var rect = new Rect { Left = saved.Left, Top = saved.Top, Right = saved.Right, Bottom = saved.Bottom };
            IntPtr monitor = MonitorFromRect(ref rect, 2); // Nearest connected monitor.
            var info = new MonitorInfo { Size = (uint)Marshal.SizeOf<MonitorInfo>() };
            if (!GetMonitorInfoW(monitor, ref info)) return;
            // Recover gracefully after a monitor is unplugged or its resolution changes.
            int width = Math.Clamp(rect.Right - rect.Left, 1, info.Work.Right - info.Work.Left);
            int height = Math.Clamp(rect.Bottom - rect.Top, 1, info.Work.Bottom - info.Work.Top);
            rect.Left = Math.Clamp(rect.Left, info.Work.Left, info.Work.Right - width);
            rect.Top = Math.Clamp(rect.Top, info.Work.Top, info.Work.Bottom - height);
            rect.Right = rect.Left + width; rect.Bottom = rect.Top + height;
            var placement = new Placement { Length = (uint)Marshal.SizeOf<Placement>(), ShowCommand = saved.Maximized ? 3u : 1u, NormalPosition = rect };
            restoring = true;
            SetWindowPlacement(WinRT.Interop.WindowNative.GetWindowHandle(window), ref placement);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException or ArgumentException) { }
        finally { restoring = false; }
    }

    void Save()
    {
        try
        {
            var placement = new Placement { Length = (uint)Marshal.SizeOf<Placement>() };
            if (!GetWindowPlacement(WinRT.Interop.WindowNative.GetWindowHandle(window), ref placement)) return;
            var rect = placement.NormalPosition;
            if (rect.Right <= rect.Left || rect.Bottom <= rect.Top) return;
            var saved = new SavedPlacement
            {
                Left = rect.Left, Top = rect.Top, Right = rect.Right, Bottom = rect.Bottom,
                Maximized = placement.ShowCommand == 3 || (placement.ShowCommand == 2 && (placement.Flags & 2) != 0)
            };
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            string temporary = path + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(saved));
            File.Move(temporary, path, overwrite: true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException) { }
    }

    public sealed class SavedPlacement { public int Left { get; set; } public int Top { get; set; } public int Right { get; set; } public int Bottom { get; set; } public bool Maximized { get; set; } }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Placement { public uint Length, Flags, ShowCommand; public Point MinPosition, MaxPosition; public Rect NormalPosition; }
    [StructLayout(LayoutKind.Sequential)] struct MonitorInfo { public uint Size; public Rect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")] static extern bool GetWindowPlacement(IntPtr window, ref Placement placement);
    [DllImport("user32.dll")] static extern bool SetWindowPlacement(IntPtr window, ref Placement placement);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromRect(ref Rect rect, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetMonitorInfoW(IntPtr monitor, ref MonitorInfo info);
}

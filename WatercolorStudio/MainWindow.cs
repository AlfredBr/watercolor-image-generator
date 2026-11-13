using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Media.Animation;
using Windows.Graphics.Imaging;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Storage.Streams;
using Windows.UI;

namespace WatercolorStudio;

[StructLayout(LayoutKind.Sequential)]
public struct RenderSettings
{
    public int Width, Height, Seed, Palette, Style;
    public float Water, Pigment, Texture, Splatter;
}
internal static class Native
{
    [DllImport("WatercolorCuda.dll", CallingConvention = CallingConvention.Cdecl)]
    internal static extern int wc_device(StringBuilder name, int length);
    [DllImport("WatercolorCuda.dll", CallingConvention = CallingConvention.Cdecl)]
    internal static extern int wc_render(RenderSettings settings, [Out] byte[] pixels, StringBuilder error, int length);
}

public sealed class MainWindow : Window
{
    readonly Image artwork = new() { Stretch = Stretch.Uniform };
    readonly Image incomingArtwork = new() { Stretch = Stretch.Uniform, Opacity = 0, IsHitTestVisible = false };
    Storyboard? activeFade;
    TaskCompletionSource<bool>? fadeCompletion;
    readonly ComboBox palette = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    readonly ComboBox composition = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    readonly ComboBox format = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    readonly ComboBox resolution = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    readonly NumberBox seed = new() { Minimum = 1, Maximum = 2147483646, Value = 48271, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Compact };
    readonly Slider water = new() { Minimum = 0, Maximum = 1, Value = .72 };
    readonly Slider pigment = new() { Minimum = .25, Maximum = 1.8, Value = .85 };
    readonly Slider texture = new() { Minimum = 0, Maximum = 1.5, Value = .85 };
    readonly Slider splatter = new() { Minimum = 0, Maximum = 1.8, Value = .85 };
    readonly TextBlock status = new() { Text = "Preparing the studio…", FontSize = 12, Foreground = Brush("#B5C0BC"), TextWrapping = TextWrapping.Wrap };
    readonly TextBlock caption = new() { FontSize = 12, Foreground = Brush("#AAB6AF") };
    readonly ProgressRing progress = new() { Width = 36, Height = 36, IsActive = false, Visibility = Visibility.Collapsed };
    readonly Button generate = new() { Content = "Paint something new  ↗", HorizontalAlignment = HorizontalAlignment.Stretch, Height = 46 };
    readonly Button save = new() { Content = "Export PNG", IsEnabled = false };
    readonly ToggleSwitch auto = new() { OnContent = "", OffContent = "", MinWidth = 0, Width = 44, VerticalAlignment = VerticalAlignment.Center };
    readonly NumberBox interval = new() { Minimum = 1, Maximum = 3600, Value = 5, SmallChange = 1, Width = 72, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Compact };
    readonly DispatcherTimer autoTimer = new();
    byte[]? pixels;
    RenderSettings rendered;
    bool busy;
    bool exporting;
    bool closed;
    static SolidColorBrush Brush(string hex) => new(Color.FromArgb(255, Convert.ToByte(hex.Substring(1, 2), 16), Convert.ToByte(hex.Substring(3, 2), 16), Convert.ToByte(hex.Substring(5, 2), 16)));
    static TextBlock Text(string text, double size = 14, string color = "#2B3833") => new() { Text = text, FontSize = size, Foreground = Brush(color), TextWrapping = TextWrapping.Wrap };

    public MainWindow()
    {
        Title = "Pigment — Watercolor Studio";
        AppWindow.Resize(new Windows.Graphics.SizeInt32(1440, 1000));
        var root = new Grid { Background = Brush("#F4F1E9"), RequestedTheme = ElementTheme.Light };
        root.ColumnDefinitions.Add(new() { Width = new GridLength(320) });
        root.ColumnDefinitions.Add(new() { Width = new GridLength(1, GridUnitType.Star) });
        Content = root;

        var sidebar = new StackPanel { Spacing = 21, Padding = new Thickness(28, 30, 28, 26) };
        var sidebarLayout = new Grid();
        sidebarLayout.RowDefinitions.Add(new() { Height = new GridLength(1, GridUnitType.Star) });
        sidebarLayout.RowDefinitions.Add(new() { Height = GridLength.Auto });
        root.Children.Add(sidebarLayout);
        sidebarLayout.Children.Add(new ScrollViewer { Content = sidebar, VerticalScrollBarVisibility = ScrollBarVisibility.Auto });
        sidebar.Children.Add(Text("P I G M E N T", 28));
        sidebar.Children.Add(Text("A little water. A little wonder.", 13, "#6F7971"));
        sidebar.Children.Add(new Border { Height = 1, Background = Brush("#DCDDD2"), Margin = new Thickness(0, 0, 0, 0) });

        string[] names = ["Chromatic garden", "Wild botanical", "Lilac & sea glass", "Tidal pools", "Apricot sunset", "After the rain", "Earth & ochre", "The whole rainbow"];
        string[][] colors = [["#F91382", "#FF940B", "#10C2C4", "#8030CC", "#F5DA29"], ["#338D30", "#8AC72E", "#0A754C", "#BADE4A", "#59BA91"], ["#A130D1", "#D659D6", "#6B87D6", "#40D4C7", "#BF9CEB"], ["#0870AD", "#10B8C2", "#38A6C2", "#475096", "#69CFAD"], ["#F54A3D", "#FFA324", "#E3397A", "#A14AA6", "#FAC750"], ["#263D7D", "#61368F", "#148799", "#AD5299", "#5770B0"], ["#BF522E", "#D69C4A", "#637340", "#914D45", "#D6B57A"], ["#FF1440", "#FF7A05", "#F5D90A", "#1FAD42", "#0A9EDB", "#5438D4", "#CF1CA8"]];
        for (int i = 0; i < names.Length; i++)
        {
            var item = new StackPanel { Spacing = 5, Padding = new Thickness(0, 3, 0, 3) };
            item.Children.Add(Text(names[i], 13));
            var swatches = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
            foreach (var color in colors[i]) swatches.Children.Add(new Border { Width = 23, Height = 5, CornerRadius = new CornerRadius(2), Background = Brush(color) });
            item.Children.Add(swatches); palette.Items.Add(item);
        }
        palette.SelectedIndex = 0;
        sidebar.Children.Add(Field("01 / COLOR STORY", palette));
        foreach (string s in new[] { "Botanical bloom", "Floating ink & drips", "All-over color field", "Geometrics", "Mondrian", "Puddles", "Lines", "Splatter" }) composition.Items.Add(s);
        composition.SelectedIndex = 0;
        sidebar.Children.Add(Field("02 / COMPOSITION", composition));
        var sliders = new StackPanel { Spacing = 9 };
        sliders.Children.Add(Text("03 / THE MATERIALS", 11, "#717B72"));
        sliders.Children.Add(SliderField("Water & diffusion", water));
        sliders.Children.Add(SliderField("Pigment richness", pigment));
        sliders.Children.Add(SliderField("Paper & granulation", texture));
        sliders.Children.Add(SliderField("Splashes & wandering drips", splatter));
        sidebar.Children.Add(sliders);
        foreach (string s in new[] { "Square · 1:1", "Landscape · 4:3", "Portrait · 3:4", "Panorama · 16:9" }) format.Items.Add(s);
        format.SelectedIndex = 1;
        foreach (string s in new[] { "Studio · 1200 px", "Fine art · 2400 px", "Print · 3600 px" }) resolution.Items.Add(s);
        resolution.SelectedIndex = 0;
        var output = new StackPanel { Spacing = 8 };
        output.Children.Add(Field("04 / PAPER SIZE", format)); output.Children.Add(resolution);
        sidebar.Children.Add(output);
        sidebar.Children.Add(Field("COMPOSITION SEED", seed));
        generate.Background = Brush("#314F40"); generate.Foreground = Brush("#FFFFFF");
        generate.Click += async (_, _) => await PaintNew();
        sidebar.Children.Add(generate);
        var repaint = new Button { Content = "Repaint this seed", HorizontalAlignment = HorizontalAlignment.Stretch };
        repaint.Click += async (_, _) => await Paint();
        sidebar.Children.Add(repaint);

        var playback = new StackPanel { Spacing = 12, Padding = new Thickness(28, 16, 28, 24) };
        var timing = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        var autoLabel = Text("Auto", 12); autoLabel.VerticalAlignment = VerticalAlignment.Center; timing.Children.Add(autoLabel);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(auto, "Auto");
        timing.Children.Add(auto);
        var every = Text("Every", 12); every.VerticalAlignment = VerticalAlignment.Center; timing.Children.Add(every);
        interval.VerticalAlignment = VerticalAlignment.Center; timing.Children.Add(interval);
        var seconds = Text("seconds", 12); seconds.VerticalAlignment = VerticalAlignment.Center; timing.Children.Add(seconds);
        playback.Children.Add(timing);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(interval, "Auto interval in seconds");
        ToolTipService.SetToolTip(interval, "Wait 1–3600 seconds between paintings. Export pauses Auto.");
        save.HorizontalAlignment = HorizontalAlignment.Stretch;
        save.Click += async (_, _) => await Save(); playback.Children.Add(save);
        playback.Children.Add(Text("Every wash is a small, repeatable accident.\nAdjust the materials, then repaint.", 11, "#7B847A"));
        var playbackFooter = new Border { Child = playback, BorderBrush = Brush("#DCDDD2"), BorderThickness = new Thickness(0, 1, 0, 0) };
        Grid.SetRow(playbackFooter, 1); sidebarLayout.Children.Add(playbackFooter);

        var stage = new Grid { Background = Brush("#202C29"), Padding = new Thickness(40, 30, 40, 24) };
        Grid.SetColumn(stage, 1); root.Children.Add(stage);
        stage.RowDefinitions.Add(new() { Height = GridLength.Auto });
        stage.RowDefinitions.Add(new() { Height = new GridLength(1, GridUnitType.Star) });
        stage.RowDefinitions.Add(new() { Height = GridLength.Auto });
        var header = new Grid { Margin = new Thickness(0, 0, 0, 28) };
        var roomTitle = Text("THE WATERCOLOR ROOM", 12, "#DBE4D9");
        roomTitle.VerticalAlignment = VerticalAlignment.Center;
        header.Children.Add(roomTitle);
        stage.Children.Add(header);
        var mat = new Border { Background = Brush("#FFFDF6"), Padding = new Thickness(18), HorizontalAlignment = HorizontalAlignment.Stretch, VerticalAlignment = VerticalAlignment.Stretch, Margin = new Thickness(0, 0, 0, 26) };
        var artgrid = new Grid(); artgrid.Children.Add(artwork); artgrid.Children.Add(incomingArtwork); artgrid.Children.Add(progress); mat.Child = artgrid;
        Grid.SetRow(mat, 1); stage.Children.Add(mat);
        var footer = new StackPanel { Spacing = 7 }; footer.Children.Add(caption); footer.Children.Add(status); Grid.SetRow(footer, 2); stage.Children.Add(footer);
        root.Loaded += async (_, _) => await Paint();
        auto.Toggled += (_, _) => ScheduleAuto();
        interval.ValueChanged += (_, _) =>
        {
            if (!double.IsFinite(interval.Value)) { interval.Value = 5; return; }
            ScheduleAuto();
        };
        autoTimer.Tick += async (_, _) => { autoTimer.Stop(); await PaintNew(automatic: true); };
        Closed += (_, _) =>
        {
            closed = true; autoTimer.Stop(); activeFade?.Stop(); fadeCompletion?.TrySetResult(false);
        };
    }

    void ScheduleAuto()
    {
        autoTimer.Stop();
        if (closed || busy || exporting || !auto.IsOn) return;
        autoTimer.Interval = TimeSpan.FromSeconds(double.IsFinite(interval.Value) ? Math.Clamp(interval.Value, 1, 3600) : 5);
        autoTimer.Start();
    }
    async Task PaintNew(bool automatic = false)
    {
        if (closed || busy || exporting) return;
        int next;
        do { next = Random.Shared.Next(1, int.MaxValue); } while (next == (int)seed.Value);
        await Paint(next, automatic);
    }

    static StackPanel Field(string label, UIElement child)
    {
        var panel = new StackPanel { Spacing = 8 }; panel.Children.Add(Text(label, 11, "#717B72")); panel.Children.Add(child); return panel;
    }
    static StackPanel SliderField(string label, Slider slider)
    {
        var p = new StackPanel { Spacing = 0 };
        var row = new Grid(); row.Children.Add(Text(label, 12));
        var value = Text($"{slider.Value:0.00}", 11, "#7B847A"); value.HorizontalAlignment = HorizontalAlignment.Right; row.Children.Add(value);
        slider.ValueChanged += (_, e) => value.Text = e.NewValue.ToString("0.00");
        p.Children.Add(row); p.Children.Add(slider); return p;
    }
    async Task ShowPainting(ImageSource source)
    {
        if (artwork.Source == null) { artwork.Source = source; return; }
        // Keep the old painting fully opaque underneath the incoming one.
        // This is a true dissolve, with no blank frame or dip toward the paper color.
        incomingArtwork.Source = source;
        incomingArtwork.Opacity = 0;
        var animation = new DoubleAnimation
        {
            From = 0, To = 1, Duration = new Duration(TimeSpan.FromSeconds(2.5)),
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut }
        };
        Storyboard.SetTarget(animation, incomingArtwork);
        Storyboard.SetTargetProperty(animation, "Opacity");
        var storyboard = new Storyboard(); storyboard.Children.Add(animation);
        var completion = new TaskCompletionSource<bool>();
        storyboard.Completed += (_, _) => completion.TrySetResult(true);
        activeFade = storyboard; fadeCompletion = completion;
        try
        {
            storyboard.Begin();
            if (await completion.Task && !closed) artwork.Source = source;
        }
        finally
        {
            storyboard.Stop(); activeFade = null; fadeCompletion = null;
            if (!closed) { incomingArtwork.Opacity = 0; incomingArtwork.Source = null; }
        }
    }

    async Task Paint(int? requestedSeed = null, bool automatic = false)
    {
        if (closed || busy || exporting) return;
        autoTimer.Stop();
        if (double.IsNaN(seed.Value)) seed.Value = 48271;
        busy = true;
        // Snapshot controls once; they remain steady and editable while CUDA works.
        // Edits made during a render apply to the next painting.
        double startingSeed = seed.Value;
        bool showProgress = !automatic || pixels == null;
        if (showProgress)
        {
            progress.Visibility = Visibility.Visible; progress.IsActive = true;
            status.Text = "Pigment is finding its way through the paper…";
        }
        try
        {
            int size = new[] { 1200, 2400, 3600 }[resolution.SelectedIndex];
            double ratio = new[] { 1.0, 4.0 / 3, 3.0 / 4, 16.0 / 9 }[format.SelectedIndex];
            string compositionLabel = composition.SelectedItem?.ToString() ?? "";
            var p = new RenderSettings { Width = ratio >= 1 ? size : (int)(size * ratio), Height = ratio >= 1 ? (int)(size / ratio) : size, Seed = requestedSeed ?? (int)startingSeed, Palette = palette.SelectedIndex, Style = composition.SelectedIndex, Water = (float)water.Value, Pigment = (float)pigment.Value, Texture = (float)texture.Value, Splatter = (float)splatter.Value };
            var data = new byte[p.Width * p.Height * 4]; var error = new StringBuilder(512); var device = new StringBuilder(256);
            var sw = Stopwatch.StartNew();
            int result = await Task.Run(() => { Native.wc_device(device, 256); return Native.wc_render(p, data, error, 512); });
            if (closed) return;
            if (result < 0) throw new InvalidOperationException(error.ToString());
            var bitmap = new WriteableBitmap(p.Width, p.Height);
            using (var stream = bitmap.PixelBuffer.AsStream()) await stream.WriteAsync(data);
            bitmap.Invalidate();
            progress.IsActive = false; progress.Visibility = Visibility.Collapsed;
            double renderSeconds = sw.Elapsed.TotalSeconds;
            await ShowPainting(bitmap);
            if (closed) return;
            pixels = data; rendered = p;
            if (seed.Value == startingSeed) seed.Value = p.Seed;
            caption.Text = $"STUDY {p.Seed}     /     {p.Width} × {p.Height}     /     {compositionLabel}";
            status.Text = $"{(result == 1 ? device.ToString() : "CPU studio renderer")}    ·    {renderSeconds:0.00}s" + (error.Length > 0 ? $"    ·    {error}" : "");
        }
        catch (Exception ex)
        {
            if (!closed) { auto.IsOn = false; status.Text = "The wash could not be rendered: " + ex.Message; }
        }
        finally
        {
            busy = false;
            if (!closed)
            {
                save.IsEnabled = pixels != null && !exporting;
                progress.IsActive = false; progress.Visibility = Visibility.Collapsed;
                ScheduleAuto();
            }
        }
    }
    async Task Save()
    {
        if (pixels == null || exporting || closed) return;
        exporting = true; autoTimer.Stop(); save.IsEnabled = false;
        var savedPixels = pixels;
        var savedSettings = rendered;
        try
        {
            var picker = new FileSavePicker { SuggestedStartLocation = PickerLocationId.PicturesLibrary, SuggestedFileName = $"Pigment-{savedSettings.Seed}" };
            picker.FileTypeChoices.Add("PNG image", new List<string> { ".png" });
            WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
            StorageFile? file = await picker.PickSaveFileAsync(); if (file == null) return;
            using IRandomAccessStream stream = await file.OpenAsync(FileAccessMode.ReadWrite);
            stream.Size = 0;
            var encoder = await BitmapEncoder.CreateAsync(BitmapEncoder.PngEncoderId, stream);
            encoder.SetPixelData(BitmapPixelFormat.Bgra8, BitmapAlphaMode.Ignore, (uint)savedSettings.Width, (uint)savedSettings.Height, 300, 300, savedPixels);
            await encoder.FlushAsync(); if (!closed) status.Text = "Saved to " + file.Path;
        }
        catch (Exception ex) { if (!closed) status.Text = "Could not save: " + ex.Message; }
        finally
        {
            exporting = false;
            if (!closed) { save.IsEnabled = pixels != null; ScheduleAuto(); }
        }
    }
}

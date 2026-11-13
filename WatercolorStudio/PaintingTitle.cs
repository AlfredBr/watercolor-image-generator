using System.Runtime.InteropServices;

namespace WatercolorStudio;

// Reads the rendered pixels rather than naming a palette preset. Pigment-weighted
// hue, brightness, coverage, and placement supply the vocabulary for each study.
internal static class PaintingTitle
{
    public static string Create(byte[] pixels, RenderSettings settings)
    {
        double[] hues = new double[12];
        double weight = 0, light = 0, cx = 0, cy = 0;
        int colored = 0, samples = 0;
        int step = Math.Max(2, Math.Min(settings.Width, settings.Height) / 150);
        for (int y = 0; y < settings.Height; y += step)
        for (int x = 0; x < settings.Width; x += step)
        {
            int i = (y * settings.Width + x) * 4;
            double r = pixels[i + 2] / 255d, g = pixels[i + 1] / 255d, b = pixels[i] / 255d;
            double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
            double delta = max - min, saturation = max > 0 ? delta / max : 0;
            double luminance = .2126 * r + .7152 * g + .0722 * b;
            samples++; light += luminance;
            if (saturation < .13 || delta < .06) continue;
            colored++;
            double hue = max == r ? (g - b) / delta : max == g ? 2 + (b - r) / delta : 4 + (r - g) / delta;
            hue = (hue * 60 + 360) % 360;
            double pigment = saturation * saturation * (.3 + 1 - luminance);
            hues[(int)(hue / 30)] += pigment;
            weight += pigment; cx += pigment * x / settings.Width; cy += pigment * y / settings.Height;
        }
        int dominant = Array.IndexOf(hues, hues.Max());
        string[] colors = ["Vermilion", "Amber", "Saffron", "Chartreuse", "Jade", "Sea Glass", "Turquoise", "Azure", "Indigo", "Violet", "Orchid", "Rose"];
        string color = weight > 1 ? colors[dominant] : light / samples < .45 ? "Charcoal" : "Pearl";
        string[][] subjects =
        [
            ["Garden", "Wildflowers", "Petals", "Greenhouse", "Bloom", "Meadow"],
            ["Whispers", "Falling Ink", "Rainfall", "Drifting Petals", "Mist", "Rivulets"],
            ["Atmosphere", "Colorfield", "Weather", "Horizon", "Reverie", "Daydream"],
            ["Fragments", "Angles", "Constellation", "Paper Shapes", "Prisms", "Mosaic"],
            ["City", "Windows", "Crossroads", "Architecture", "Intervals", "Painted Rooms"],
            ["Tide Pools", "Backwaters", "Puddles", "Estuary", "Shallows", "Quiet Water"],
            ["Choreography", "Wandering Lines", "Calligraphy", "Tangled Paths", "Currents", "Threads"],
            ["Fireworks", "Confetti", "After the Storm", "Rebellion", "Festival", "Sparks"],
            ["Woven Rhythm", "Textile Song", "Pattern Dance", "Cloth Memory", "Painted Weave", "Threadwork"],
            ["Equilibrium", "Two Currents", "Balance", "Still Center", "Turning Circle", "Quiet Union"],
            ["Continuum", "Endless Current", "Eternal Loop", "Returning Tide", "Unbroken Thread", "Infinity"],
            ["Gesture", "Repose", "Life Study", "Figure in a Dream", "Body of Light", "Quiet Strength"],
            ["One Surface", "Twisted Light", "Endless Ribbon", "Folded Time", "Returning Path", "Continuum"],
            ["Orbits", "Celestial Dance", "Distant Worlds", "Planetary Waltz", "Solar Reverie", "Gravity"],
            ["Stardust", "Nebular Veil", "Cosmic Weather", "Star Nursery", "Interstellar Dream", "Deep Sky"],
            ["Patchwork", "Stitched Memory", "Heirloom", "Quilted Garden", "Gathered Cloth", "Fabric of Dreams"],
            ["Gaze", "Watery Eye", "Inner Light", "Watching the Rain", "Iris", "Window Within"],
            ["Canopy", "Falling Leaves", "Leaf Dance", "Botanical Reverie", "Forest Letters", "Tender Branches"],
            ["Bouquet", "Petal Song", "Floral Reverie", "Wildflower Waltz", "Garden Gathering", "Secret Blossoms"],
            ["Vanishing Point", "Distant Passage", "Corridor of Light", "Perspective", "Receding Rooms", "Far Horizon"],
            ["Tempest", "Thunderhead", "Squall", "Cloudburst", "Stormfront", "Lightning"],
            ["Midnight City", "Neon Reflections", "City After Rain", "Night Windows", "Wet Pavements", "Urban Nocturne"]
        ];
        // The seed varies wording, while the subject and color come from this image.
        uint hash = unchecked((uint)settings.Seed * 2654435761u + (uint)dominant * 97u);
        string subject = subjects[Math.Clamp(settings.Style, 0, subjects.Length - 1)][hash % 6];
        double brightness = light / samples, coverage = (double)colored / samples;
        string[] endings = brightness < .35 ? ["at Midnight", "in Shadow", "After Dark"]
            : brightness > .79 ? ["in Morning Light", "in Quiet Air", "at First Light"]
            : settings.Water > .72f ? ["in the Rain", "Adrift", "in Soft Water"]
            : coverage < .35 ? ["in Open Space", "in Silence", "on Paper"]
            : weight > 0 && cy / weight < .42 ? ["Above the Horizon", "Taking Flight", "in High Air"]
            : weight > 0 && cx / weight > .58 ? ["Turning East", "Beyond the Center", "in Motion"]
            : ["in Bloom", "in Motion", "in Reverie"];
        return $"{color} {subject} {endings[(hash >> 8) % 3]}";
    }

    public static void Draw(byte[] pixels, int width, int height, string title)
    {
        IntPtr dc = CreateCompatibleDC(IntPtr.Zero), bitmap = IntPtr.Zero, previousBitmap = IntPtr.Zero, font = IntPtr.Zero, previousFont = IntPtr.Zero;
        if (dc == IntPtr.Zero) throw new InvalidOperationException("Could not create the painting title surface.");
        try
        {
            var info = new BitmapInfo { Size = 40, Width = width, Height = -height, Planes = 1, BitCount = 32 };
            bitmap = CreateDIBSection(dc, ref info, 0, out IntPtr bits, IntPtr.Zero, 0);
            if (bitmap == IntPtr.Zero) throw new InvalidOperationException("Could not allocate the painting title surface.");
            previousBitmap = SelectObject(dc, bitmap);
            Marshal.Copy(pixels, 0, bits, pixels.Length);
            int size = Math.Max(18, (int)(Math.Min(width, height) * .028));
            font = CreateFontW(-size, 0, 0, 0, 400, 1, 0, 0, 1, 0, 0, 4, 0, "Georgia");
            if (font == IntPtr.Zero) throw new InvalidOperationException("Could not create the painting title font.");
            previousFont = SelectObject(dc, font);
            GetTextExtentPoint32W(dc, title, title.Length, out Size measured);
            // Long titles remain within the image at every aspect ratio.
            if (measured.X > width * .78)
            {
                SelectObject(dc, previousFont); DeleteObject(font);
                size = Math.Max(12, (int)(size * width * .78 / measured.X));
                font = CreateFontW(-size, 0, 0, 0, 400, 1, 0, 0, 1, 0, 0, 4, 0, "Georgia");
                if (font == IntPtr.Zero) throw new InvalidOperationException("Could not size the painting title font.");
                SelectObject(dc, font);
                GetTextExtentPoint32W(dc, title, title.Length, out measured);
            }
            int margin = Math.Max(16, (int)(Math.Min(width, height) * .028));
            var rect = new Rect { Left = Math.Max(margin, width - margin - measured.X - 8), Top = height - margin - size * 2, Right = width - margin, Bottom = height - margin };
            uint dark = Rgb(25, 37, 38), ivory = Rgb(255, 249, 234);
            double darkScore = 0, ivoryScore = 0;
            for (int y = rect.Top; y < rect.Bottom; y += 3)
            for (int x = rect.Left; x < rect.Right; x += 3)
            {
                int i = (y * width + x) * 4;
                double luminance = .2126 * Linear(pixels[i + 2]) + .7152 * Linear(pixels[i + 1]) + .0722 * Linear(pixels[i]);
                darkScore += Math.Log(Contrast(luminance, .017));
                ivoryScore += Math.Log(Contrast(luminance, .95));
            }
            bool useDark = darkScore >= ivoryScore;
            SetBkMode(dc, 1);
            // A fine opposing halo keeps letters readable across mixed pigment.
            SetTextColor(dc, useDark ? ivory : dark);
            int halo = Math.Max(1, size / 22);
            for (int dy = -halo; dy <= halo; dy += halo)
            for (int dx = -halo; dx <= halo; dx += halo)
            {
                if (dx == 0 && dy == 0) continue;
                var outline = new Rect { Left = rect.Left + dx, Top = rect.Top + dy, Right = rect.Right + dx, Bottom = rect.Bottom + dy };
                DrawTextW(dc, title, title.Length, ref outline, 2 | 8 | 32 | 256 | 32768);
            }
            SetTextColor(dc, useDark ? dark : ivory);
            DrawTextW(dc, title, title.Length, ref rect, 2 | 8 | 32 | 256 | 32768);
            GdiFlush();
            Marshal.Copy(bits, pixels, 0, pixels.Length);
            for (int i = 3; i < pixels.Length; i += 4) pixels[i] = 255;
        }
        finally
        {
            if (previousFont != IntPtr.Zero) SelectObject(dc, previousFont);
            if (font != IntPtr.Zero) DeleteObject(font);
            if (previousBitmap != IntPtr.Zero) SelectObject(dc, previousBitmap);
            if (bitmap != IntPtr.Zero) DeleteObject(bitmap);
            DeleteDC(dc);
        }
    }
    static double Linear(byte value) { double s = value / 255d; return s <= .04045 ? s / 12.92 : Math.Pow((s + .055) / 1.055, 2.4); }
    static double Contrast(double a, double b) => (Math.Max(a, b) + .05) / (Math.Min(a, b) + .05);
    static uint Rgb(byte r, byte g, byte b) => (uint)(r | g << 8 | b << 16);
    [StructLayout(LayoutKind.Sequential)] struct Size { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct BitmapInfo { public uint Size; public int Width, Height; public ushort Planes, BitCount; public uint Compression, ImageSize; public int XPelsPerMeter, YPelsPerMeter; public uint ColorsUsed, ColorsImportant; public uint Palette; }
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr dc, ref BitmapInfo info, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr value);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr value);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateFontW(int height, int width, int escapement, int orientation, int weight, uint italic, uint underline, uint strikeout, uint charset, uint output, uint clip, uint quality, uint pitch, string face);
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] static extern bool GetTextExtentPoint32W(IntPtr dc, string text, int count, out Size size);
    [DllImport("gdi32.dll")] static extern int SetBkMode(IntPtr dc, int mode);
    [DllImport("gdi32.dll")] static extern uint SetTextColor(IntPtr dc, uint color);
    [DllImport("gdi32.dll")] static extern bool GdiFlush();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int DrawTextW(IntPtr dc, string text, int count, ref Rect rect, uint format);
}

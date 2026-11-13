using System.Runtime.InteropServices;
using System.Text;
using WatercolorStudio;

string root = Path.GetFullPath(args.Length > 0 ? args[0] : ".");
NativeLibrary.SetDllImportResolver(typeof(Program).Assembly, (name, assembly, path) => name == "WatercolorCuda.dll" ? NativeLibrary.Load(Path.Combine(root, "native", name)) : IntPtr.Zero);
var settings = new RenderSettings { Width = 900, Height = 675, Seed = 48271, Style = 0, Water = .72f, Pigment = .85f, Texture = .85f, Splatter = .85f };
byte[] Solid(byte r, byte g, byte b)
{
    var data = new byte[settings.Width * settings.Height * 4];
    for (int i = 0; i < data.Length; i += 4) { data[i] = b; data[i+1] = g; data[i+2] = r; data[i+3] = 255; }
    return data;
}
void Require(bool condition, string message) { if (!condition) throw new Exception(message); }
var red = Solid(210, 35, 40); var blue = Solid(30, 100, 215);
Require(PaintingTitle.Create(red, settings) != PaintingTitle.Create(blue, settings), "Names must respond to actual image colors.");
foreach (byte shade in new byte[] { 15, 245 })
{
    var data = Solid(shade, shade, shade); string name = PaintingTitle.Create(data, settings);
    Require(name == PaintingTitle.Create(data, settings), "Naming must be repeatable.");
    PaintingTitle.Draw(data, settings.Width, settings.Height, name);
    int changed = 0;
    for (int y = 0; y < settings.Height; y++)
    for (int x = 0; x < settings.Width; x++)
    {
        int i = (y * settings.Width + x) * 4;
        Require(data[i+3] == 255, "Text must preserve opaque alpha.");
        if (data[i] == shade && data[i+1] == shade && data[i+2] == shade) continue;
        changed++;
        Require(y > settings.Height * .8, "Title must remain in the bottom of the painting.");
    }
    Require(changed > 100, "Title was not drawn.");
    bool contrasting = false;
    for (int i = 0; i < data.Length; i += 4) if (shade < 100 ? data[i] > 200 : data[i] < 70) { contrasting = true; break; }
    Require(contrasting, "Title must contrast on light and dark paintings.");
}
foreach (var (style, palette, label) in new[] { (0,0,"bloom"), (11,2,"figure"), (14,2,"nebula"), (16,3,"iris") })
{
    settings.Style=style; settings.Palette=palette;
    byte[] data = new byte[settings.Width*settings.Height*4];
    var error = new StringBuilder(512);
    Require(Render(settings,data,error,512)>=0,error.ToString());
    string name = PaintingTitle.Create(data,settings);
    PaintingTitle.Draw(data,settings.Width,settings.Height,name);
    using var file = new BinaryWriter(File.Create(Path.Combine(root,"samples",$"titled-{label}.bmp")));
    file.Write((ushort)0x4d42); file.Write(54+data.Length); file.Write(0); file.Write(54);
    file.Write(40); file.Write(settings.Width); file.Write(-settings.Height); file.Write((ushort)1); file.Write((ushort)32);
    file.Write(0); file.Write(data.Length); file.Write(11811); file.Write(11811); file.Write(0); file.Write(0); file.Write(data);
    Console.WriteLine($"{label}: {name}");
}
Console.WriteLine("Pixel-based naming, repeatability, contrast, title placement, alpha, and native render checks passed.");

[DllImport("WatercolorCuda.dll", EntryPoint="wc_render", CallingConvention=CallingConvention.Cdecl)]
static extern int Render(RenderSettings settings,[Out] byte[] pixels,StringBuilder error,int length);

namespace WatercolorStudio
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RenderSettings { public int Width, Height, Seed, Palette, Style; public float Water, Pigment, Texture, Splatter; }
}

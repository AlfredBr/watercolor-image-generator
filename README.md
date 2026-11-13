# Pigment — Watercolor Studio

A native WinUI 3 / CUDA art studio inspired by loose watercolor splashes, botanical pigment blooms, pastel ink, and vivid washes on textured paper.

## Open the studio

Run `./Run.ps1` in PowerShell, or open:

`WatercolorStudio/bin/x64/Release/net10.0-windows10.0.19041.0/win-x64/WatercolorStudio.exe`

The built application includes the Windows App SDK runtime and needs the .NET 10 Desktop Runtime. Keep all files in the executable's folder together.

## Paint

- Choose from eight color stories: Chromatic garden, Wild botanical, Lilac & sea glass, Tidal pools, Apricot sunset, After the rain, Earth & ochre, and The whole rainbow.
- Choose Botanical bloom, Floating ink & drips, All-over color field, Geometrics, Mondrian, Puddles, Lines, or Splatter. The five newer themes are deliberately loose and messy: Geometrics overlaps torn polygons and broken rings; Mondrian tilts bleeding panels across a fractured charcoal grid; Puddles merges wet pools and runoffs; Lines tangles looping, interrupted brush trails; Splatter throws dense bursts, spidery flicks, and drips across the page. All eight work with every color palette, seeded generation, Auto, crossfades, and PNG export.
- Adjust water, pigment, paper granulation, and splashes.
- **Paint something new** chooses a new seed and renders. **Repaint this seed** applies your settings while keeping the seed.
- Choose square, landscape, portrait, or panoramic paper, with a longest edge of 1200, 2400, or 3600 pixels.
- Turn **Auto** on at the bottom of the sidebar to paint a new seed automatically. Set **Every … seconds** from 1 to 3600 (default 5). Auto, timing, and Export PNG stay visible while the settings above scroll. Each new painting dissolves over the previous one over 2.5 seconds. The interval starts after the dissolve completes, so renders and transitions never overlap. Auto renders quietly without disabling and re-enabling the sidebar or showing a loading spinner. Controls remain editable; edits during rendering apply to the next painting. Manual painting restarts the interval. Export pauses new Auto renders until the dialog and save finish; closing the studio stops it. A render error turns Auto off.
- **Export PNG** saves the current artwork at its rendered resolution with 300 DPI metadata. Changing a control takes effect on the next repaint.

The same settings and seed reproduce the same image on the same rendering backend. Export saves the last fully presented painting, even if controls have since changed or a new image is currently dissolving in.

## Build

Requirements: Windows 10/11 x64, .NET SDK 10.0.115, Visual Studio with Desktop C++ and Windows app development tools, Windows SDK, CUDA Toolkit 13.1, and MSVC 14.44. A CUDA-capable NVIDIA GPU enables acceleration. If CUDA is unavailable, the native library uses its parallel CPU renderer.

```powershell
./Build.ps1
./Build.ps1 -Run
```

Close the studio before rebuilding. `Build.ps1` selects MSVC 14.44 for compatibility with CUDA 13.1 and uses Visual Studio MSBuild for the WinUI resource pipeline. On this machine it reuses the installed NuGet package cache. On another machine NuGet restore downloads the packages normally.

## Renderer

`native/Watercolor.cu` generates seeded, overlapping pigment deposits. The CUDA pixel kernel applies warped wash contours, multiscale noise, translucent optical-density mixing, capillary edge deposits, cauliflower-like pigment variation, paper fibers, granulation, splatters, and thin wandering runs. This is a procedural watercolor renderer, not a time-stepped fluid solver or an image-generation service. No network connection is needed to paint or export.

The x64 C# interface calls the native CUDA library through a small C ABI. GPU failures use the CPU path and appear in the status text. CUDA runtime is linked statically; an NVIDIA driver is needed for acceleration.

## Verification and examples

`samples/` contains nine generated PNG studies, including all five new themes, plus `theme-preview.jpg` for comparison. With Python and Pillow installed:

```powershell
python native/verify.py
```

This exercises the native renderer, checks for pigment output, verifies exact seed reproducibility, and regenerates the samples. Verified on this machine with an NVIDIA GeForce RTX 3080. The WinUI application was also built, opened, and exercised through its palette/repaint controls. PNG export was verified through the application's Save As dialog; `samples/studio-export.png` is that exported painting, checked for valid PNG data, 1200 × 900 dimensions, and 300 DPI metadata.

Windows deployment reference: [Microsoft's self-contained Windows App SDK deployment guide](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps).

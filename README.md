# Pigment — Watercolor Studio

A native WinUI 3 / CUDA art studio inspired by loose watercolor splashes, botanical pigment blooms, pastel ink, and vivid washes on textured paper.

## Open the studio

Run `./Run.ps1` in PowerShell, or open:

`WatercolorStudio/bin/x64/Release/net10.0-windows10.0.19041.0/win-x64/WatercolorStudio.exe`

The built application includes the Windows App SDK runtime and needs the .NET 10 Desktop Runtime. Keep all files in the executable's folder together.

The studio remembers its window size, position, and maximized state between launches. Placement is stored locally in `%LOCALAPPDATA%/Pigment/window.json`; disconnected monitors are handled by moving the window back onto a connected display.

## Paint

- Choose from eleven color stories: Chromatic garden, Wild botanical, Lilac & sea glass, Tidal pools, Apricot sunset, After the rain, Earth & ochre, The whole rainbow, Sparkle & metallics, Grayscale, and Sepia. The metallic palette combines gold, silver, copper, rose gold, teal, and plum with simulated foil islands, fine reflective flakes, and scattered four-point glints. Grayscale converts every pigment, highlight, and wash to neutral gray; Sepia gives the entire painting a warm vintage ink treatment. All palettes work across every theme and are included in Auto gallery and PNG exports.
- Choose from nineteen compositions: Botanical bloom, Floating ink & drips, All-over color field, Geometrics, Mondrian, Puddles, Lines, Splatter, African-inspired, Yin-yang, Infinity, Human Forms, Möbius, Planetary Systems, Nebula, Quilt, Eyeball / Iris, Leaves, and Flowers. Every style works with every color palette, seeded generation, Auto, crossfades, and PNG export.
- Geometrics overlaps torn polygons and broken rings; Mondrian tilts bleeding panels across a fractured charcoal grid; Puddles merges wet pools and runoffs; Lines tangles looping, interrupted brush trails; Splatter throws dense bursts, flicks, and drips.
- African-inspired varies original textile-like bands, diamonds, chevrons, and broken rings. Yin-yang varies its rotation, placement, and ornamental halo. Infinity alternates between figure-eight gestures and Möbius ribbons; the dedicated Möbius choice always paints a twisted ribbon. Planetary Systems varies planets, moons, rings, and tilted orbits. Nebula layers luminous clouds, dark dust lanes, and stars.
- Human Forms paints exactly one adult artistic nude figure, randomly male or female, with continuous curved outlines, curvy or muscular proportions, and softly modeled light and shadow. Figures use abstract palette pigments, rather than fixed skin colors. Raised, lowered, and waist-resting arms vary together with leg bends, crossed or extended feet, hip sway, mirroring, seated poses, and reclining compositions. The complete figure is fitted inside the sheet. Newer compositions all include full-sheet watercolor grounds and drifting background washes. Layout, scale, colors, and ornament vary with the seed.
- Quilt combines randomized patchwork blocks, diamonds, triangles, nested squares, and painted stitch marks. Eyeball / Iris paints a watery almond-shaped eye with blurred radial fibers, bleeding iris pigment, a feathered pupil, and pale highlights.
- Leaves grows randomized branching sprigs with translucent leaf washes, fine central and side veins, and loose floating leaves. It works with botanical greens, autumnal colors, and the metallic palette.
- Flowers paints randomized bouquets and loose floral fields with layered petals, pollen centers, branching stems, and small leaves.
- Adjust water, pigment, paper granulation, and splashes.
- **Paint something new** chooses a new seed and renders. **Repaint this seed** applies your settings while keeping the seed.
- Choose square, landscape, portrait, or panoramic paper, with a longest edge of 1200, 2400, or 3600 pixels.
- Set the **Auto** slider at the bottom of the sidebar from **0–60 seconds**. **0 = Off** (the startup default); **1–60** runs a random watercolor gallery at that interval. Each painting gets a new seed, theme, palette, water level, pigment richness, paper texture, and splatter amount. Themes and palettes come from separately shuffled bags, so every theme and every palette is visited before its bag repeats. Material settings explore their full slider ranges. Your paper size and resolution stay selected. Each new painting dissolves over the previous one over 2.5 seconds, then the interval starts. Auto renders quietly without disabling the sidebar or showing a spinner. The sidebar recipe updates once after the dissolve, preserving edits made during that render. Manual painting restarts the interval. Export pauses new Auto renders until saving finishes; closing the studio stops it. A render error resets the slider to 0.
- **Export PNG** saves the current artwork at its rendered resolution with 300 DPI metadata. Changing a control takes effect on the next repaint.
- Every finished painting gets a poetic title generated locally from its rendered pigment colors, brightness, coverage, composition, and seed. The title is painted in the lower-right corner in dark ink or warm ivory, selected against the actual pixels behind it, with a fine contrasting halo. It fades with the painting and is included in PNG exports. Suggested filenames include the title and seed.

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

Browse the [theme comparison preview](samples/theme-preview.jpg) or open an individual watercolor:

[Preview the ornamental, human, and cosmic themes](samples/new-theme-preview.jpg).

[Compare eight randomized human poses](samples/human-poses-preview.jpg).

[Preview titles on light and dark paintings](samples/titled-preview.jpg).

- [Chromatic garden](samples/chromatic-garden.png)
- [Wild botanical](samples/wild-botanical.png)
- [Lilac & sea glass](samples/lilac-sea-glass.png)
- [All-over color field](samples/color-field.png)
- [Geometrics](samples/geometrics.png)
- [Mondrian](samples/mondrian.png)
- [Puddles](samples/puddles.png)
- [Lines](samples/lines.png)
- [Splatter](samples/splatter.png)
- [African-inspired](samples/african-inspired.png)
- [Yin-yang](samples/yin-yang.png)
- [Infinity](samples/infinity.png)
- [Human Forms](samples/human-forms.png)
- [Möbius](samples/mobius.png)
- [Planetary Systems](samples/planetary-systems.png)
- [Nebula](samples/nebula.png)
- [Quilt](samples/quilt.png)
- [Eyeball / Iris](samples/eyeball-iris.png)
- [Sparkle & metallics](samples/sparkle-metallics.png)
- [Leaves](samples/leaves.png)
- [Flowers](samples/flowers.png)
- [Grayscale](samples/grayscale.png)
- [Sepia](samples/sepia.png)
- [Painting exported from the studio](samples/studio-export.png)

Regenerate the twenty-three sample studies and preview galleries with Python and Pillow installed:

```powershell
python native/verify.py
```

Check image-based naming, reproducibility, lower-right title placement, contrast on light and dark grounds, and opaque alpha with `dotnet run --project checks/NamingChecks.csproj -- .`. The check also renders four titled studies for visual inspection.

This exercises the native renderer, checks for pigment output, verifies exact seed reproducibility, and regenerates the samples. Verified on this machine with an NVIDIA GeForce RTX 3080. The WinUI application was also built, opened, and exercised through its palette/repaint controls. PNG export was verified through the application's Save As dialog; `samples/studio-export.png` is that exported painting, checked for valid PNG data, 1200 × 900 dimensions, and 300 DPI metadata.

Windows deployment reference: [Microsoft's self-contained Windows App SDK deployment guide](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps).

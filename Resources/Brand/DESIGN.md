# Container Desk — VM + Package

2026-10-26. New logo design based on the user's three-tier frosted-glass reference.

- Left half: three virtual-machine modules with small status indicators.
- Right half: a closed package cube, representing a container workload.
- Shared base: a container rests on VM infrastructure.
- Palette: slate lavender, silver glass and restrained ice blue.
- PNG is a flattened marketing/source image with alpha. `Resources/AppIcon.icns` contains resized macOS icon representations. This is not a layered Icon Composer asset and does not claim native dynamic Liquid Glass rendering.
- Small-size conversion preserves the generated image; no synthetic success indicators or Apple trademarks are added.

Reference: https://developer.apple.com/design/human-interface-guidelines/app-icons/ and https://developer.apple.com/icon-composer/ . Apple recommends simple, recognizable forms and layered Icon Composer artwork for native material effects.

Generation used the built-in imagegen tool. The user's reference supplied material, palette and stacked-form direction. Final prompt:

Edit the provided Container Desk app icon. Keep its slate-lavender rounded-square background, restrained macOS-inspired frosted-glass material, soft upper-left lighting and overall polished dimensional quality. REDESIGN THE FOREGROUND INTO TWO CLEAR EQUAL HALVES: the left half is a compact three-tier virtual-machine/server stack, and the right half is one large unmistakable PACKAGE / SHIPPING BOX symbol, a closed three-dimensional cube with a clearly visible top flap seam and two side faces. The cube must occupy approximately the right half of the foreground, at the same visual scale and weight as the three-tier stack on the left. Make the two halves meet neatly at the center and share one subtle glass foundation to communicate a container package built on VM infrastructure. The VM stack has only three simple softly rounded horizontal modules with tiny status indicators, not toggle switches. The package is frosted porcelain glass, not brown cardboard, with a simple incised lid seam so it reads as a package rather than a generic block. Keep both symbols easily readable at small Dock sizes: bold, simple silhouette, generous margins, minimal detail. Maintain the cool silver/lavender palette; a restrained icy-blue hint may appear where the two halves meet. No text, no VM letters, no Apple logo, no arrows, no extra badges, no separate mini tiles, no actual app UI controls, no neon, no heavy borders. One single centered square app icon, with clean truly transparent space outside the rounded-square tile. Remove any stray colored pixels, disconnected specks, or halo fragments outside the icon. Preserve the outer background proportions.

Final source: `ContainerDesk-VM-Package.png`. App export: `../AppIcon.icns`. Historical v0.3.0-preview remains unchanged; this logo ships with 1.0.0.

## Rebuild icon sizes

From the repository root:

```sh
swift scripts/make_icon.swift /tmp/ContainerDesk.iconset
iconutil -c icns /tmp/ContainerDesk.iconset -o Resources/AppIcon.icns
```

The exporter resizes this approved artwork into 16–1024 pixel representations. It no longer generates the previous blue shipping-box design. Verified by exporting and round-tripping the ICNS with `iconutil`.

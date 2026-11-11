# Assets

All graphics are drawn in code. Third-party assets are logged here with source and license.

## Fonts

All fonts: **SIL Open Font License 1.1** (license texts in `assets/fonts/OFL-*.txt`).
Bundled as .ttf files; no `google_fonts` package.

| File | Use | Source |
| --- | --- | --- |
| `assets/fonts/BarlowCondensed-SemiBold.ttf` | Display, numbers (600) | https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-SemiBold.ttf |
| `assets/fonts/BarlowCondensed-Bold.ttf` | Display, numbers (700) | https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-Bold.ttf |
| `assets/fonts/BarlowCondensed-ExtraBold.ttf` | Display, numbers (800) | https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-ExtraBold.ttf |
| `assets/fonts/BarlowCondensed-BoldItalic.ttf` | Display, speed italic (700) | https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-BoldItalic.ttf |
| `assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf` | Display, speed italic (800) | https://github.com/google/fonts/blob/main/ofl/barlowcondensed/BarlowCondensed-ExtraBoldItalic.ttf |
| `assets/fonts/Inter-Variable.ttf` | Small body text; Regular/Medium/SemiBold via `FontVariation('wght', …)` | https://github.com/google/fonts/blob/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf |

Note: google/fonts ships Inter only as a variable font (no static Regular/Medium/SemiBold files), so the
single variable file is bundled under a simpler name.

## App icon and launch screen

Original artwork made for this project (no third-party source or license). Source files in `assets/icon/`:

| File | Use |
| --- | --- |
| `icon-1024.png` | iOS app icon (opaque), Android legacy icon |
| `icon-dark-1024.png` | iOS dark-mode icon |
| `icon-tinted-1024.png` | iOS tinted icon, Android themed (monochrome) icon |
| `android-foreground-1024.png` | Android adaptive icon foreground (background `#0A0C10`) |
| `splash-mark-1024.png` | Launch screen mark on `#0A0C10` (iOS, Android, Android 12+) |

Generated native files come from the dev-only tools `flutter_launcher_icons` and `flutter_native_splash` (not shipped in the app). The iOS `LaunchImage*.png` files were then resized to 112/224/336 px so the mark is 112 pt wide; re-run that resize if the splash is regenerated.

## Sound effects

Original sounds, synthesized by `tool/gen_sounds.py` (Python 3 standard library only, fixed random seed, so re-running reproduces the same files). No third-party audio. 44.1 kHz, 16-bit mono, peaks at -4.5 dBFS, 5 ms fades at both ends.

| File | Use |
| --- | --- |
| `assets/sfx/place.wav` | Piece placement click (~40 ms) |
| `assets/sfx/clear_1.wav` … `clear_6.wav` | Bell chime line clear (~600 ms); each step higher in pitch, for combos 1 to 6+ |
| `assets/sfx/light.wav` | Start-light beep (~120 ms) |
| `assets/sfx/passby_full.wav` | Single-seater fly-by at top speed (~1.8 s), plays when the lights go out |
| `assets/sfx/passby_short.wav` | Short fly-by (~0.9 s), plays on FASTEST LAP! and the first Pole pass |

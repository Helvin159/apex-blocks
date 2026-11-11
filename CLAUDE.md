# Block Puzzle — Project Spec

Name: **Apex Blocks** (no existing app found under this name; a USPTO trademark search is still pending before store submission).
Bundle ID / applicationId: `com.helvinrymer.apexblocks` on both platforms. Permanent: never change it.
Devices: iPhone only on iOS for v1 (`TARGETED_DEVICE_FAMILY = 1`; iPad support can be added later, but can't be removed after release). Phones on Android.
Launch plan: iOS ships first, as soon as v1 is done. Android stays release-ready (every milestone must pass `flutter build apk --debug`) and ships after the Google Play 12-tester / 14-day closed test, which starts whenever 12 testers are found. Nothing on iOS waits for Android.
A casual, endless block puzzle game for iOS and Android with a night-race motorsport look. One home screen plus one game screen, no levels. Goal: polished, fast to ship, monetized with ads plus a Remove Ads purchase.

**Trademark rule:** motorsport *vibe* only. Never use "Formula 1", "F1", "Grand Prix", team or driver names, real circuit names, team liveries or color schemes, official fonts, tyre-brand names, or any logos — not in code, UI text, assets, or store listings. Generic racing culture (checkered flags, start lights, pit stops, carbon fiber, timing screens, racing jargon) is fine.

## Stack
- Flutter (Dart), one codebase for iOS and Android. Developed in VS Code.
- State: plain `ChangeNotifier` / `ValueNotifier`. No state-management packages.
- Packages (do NOT add others without asking):
  - `shared_preferences` — best score, settings, purchase flag, theme
  - `google_mobile_ads` — AdMob rewarded and interstitial ads, plus the UMP consent flow
  - `in_app_purchase` — Remove Ads (non-consumable)
  - `audioplayers` — sound effects
- Haptics: Flutter's built-in `HapticFeedback`.
- All graphics are drawn in code (`CustomPainter`). No paid assets. Any third-party asset must be CC0 and logged in `ASSETS.md` with its source URL.
- Fonts: **Barlow Condensed** (display, numbers; italic for speed) and **Inter** (small body text), both SIL Open Font License from Google Fonts. Bundle the .ttf files in `assets/fonts/` (no `google_fonts` package) and log them in `ASSETS.md` with the license.

## Project structure
```
lib/
  main.dart
  game/        # pure Dart game logic, no Flutter imports
    piece.dart, pieces.dart, board.dart, game_state.dart, scoring.dart
  ui/
    home_screen.dart, game_screen.dart, board_view.dart, tray_view.dart,
    block_painter.dart, start_lights.dart, game_over_screen.dart, effects/
  theme/
    themes.dart
  services/
    storage_service.dart, audio_service.dart, ads_service.dart, iap_service.dart
test/          # unit tests for everything in lib/game/
```

## Game rules
- Board: 8×8 grid.
- Tray: 3 pieces shown at the bottom. The player places them in any order. When all 3 are placed, deal 3 new ones.
- Pieces cannot be rotated.
- Placing a piece is valid only if every cell lands on an empty board cell.
- After a placement, any fully filled **row or column** clears. Rows and columns clear at the same time, so a placement can clear several lines at once.
- Game over: none of the remaining tray pieces fits anywhere on the board.
- Order after every placement: place cells → clear full lines → add score → if the tray is empty, deal 3 new pieces → check game over.

### Piece set
Single (1×1); lines of 2, 3, 4, 5 (horizontal and vertical); 2×2 square; 3×3 square; 3-cell corner L (all 4 orientations); 4-cell L and J (all orientations); T (4 orientations); S/Z (horizontal and vertical).
These are the ONLY families. Don't add others (no 2×3 rectangles, no 5-cell L) unless this spec changes after playtesting.
Each shape family has a spawn weight. Small and medium pieces are more common; the 3×3 and 5-lines are rarer. Keep weights in one tunable table in `pieces.dart`. A family's weight is split evenly across its orientations, so adding orientations never changes how often a family appears.
Each family has a fixed color id (0–5, matching the six block colors). Game logic stores color ids only, never Flutter colors.

### Dealing
- Deal 3 weighted-random pieces.
- Pick each piece by weight from ONLY the pieces that fit the current board right now, so every piece in a fresh tray fits on its own. There is no single-block rescue: singles appear only by their (low) weight. If nothing fits, deal anyway (that is game over). Game over otherwise only happens through the order the player places pieces.
- Weights depend on the run's score (see Difficulty). The rewarded continue's `dealFittingTray()` keeps its own behavior (3 fitting pieces, singles as a last resort).

### Scoring (all values are constants in `scoring.dart`)
- Placement: +1 point per cell placed.
- Line clears: lines cleared in one placement = n → +10 × n × n.
- Combo: `combo` starts at 0. When a placement clears at least one line, its clear points are multiplied by (1 + combo × 0.5), and then `combo` increases by 1. A placement that clears nothing resets `combo` to 0. So the first clear is ×1.0, the next consecutive clear ×1.5, then ×2.0, ×2.5, and so on with no cap. The multiplier applies to clear points only, never to per-cell points. Example: placing 3 cells that clear 1 line with combo 2 scores 3 + 10 × 1 × 1 × 2.0 = 23.
- Track and persist the best score.

### Difficulty
- Two weight tables in `pieces.dart`: `easyWeights` and `hardWeights`. The weights used are a linear blend from easy to hard as the run's score goes from `rampStartScore` (300) to `rampEndScore` (1500), clamped (`weightsForScore`). Singles stay in the set but get rarer (6 → 2).
- Targets: a typical honest run lasts 4–8 minutes, good runs score 1,000–1,500, and 2,000+ is rare.
- Measure with `dart run tool/simulate.dart` (greedy bot, seeded games, old vs new rules).

## Look: "Night Race"

Approved design canvas: three phone screens (Home, In race, Chequered flag). Match it closely.

### Color tokens (default livery, in `themes.dart`)
- Background `#0A0C10` with a subtle carbon-fiber weave (two crossed diagonal stripe patterns at ~3% white) and a soft radial lift at the top.
- Panels `#111419` / `#13161B`, borders `#2A2F37`, empty cell `#1A1E25` (inset shadow).
- Text `#F2F4F7`, muted text `#9AA3AF`.
- Accent red `#FF2D3A` (start lights, main buttons). Pole/best purple `#9B5CFF`, light `#C9A2FF`. Combo/highlight yellow `#FFC22E`.
- Block colors (light / base / dark for the gradient): red `#FF6B76/#F2334A/#B51C30`, yellow `#FFE27A/#FFC22E/#C78B00`, white `#FFFFFF/#DDE3EA/#9AA4B1`, teal `#6FF2E6/#1FC8BA/#0E8C83`, green `#8BF0A6/#34D46A/#1E9446`, purple `#C9A2FF/#9B5CFF/#6A31C9`.

### Blocks (`block_painter.dart`)
Rounded squares (radius ~6 on board, ~4 small) with a vertical 3-stop gradient, a 1 px top highlight, a darker bottom edge, a soft drop shadow, and a diagonal "racing stripe" sheen (a thin lighter band at ~115°).

### Home screen
- Top: small "ROUND N · NIGHT RACE" label, settings button top right.
- Logo: a tilted 2×2 block cluster above the "APEX / BLOCKS" wordmark (Barlow Condensed, italic, 800; second word in accent red), tagline "ENDLESS BLOCK RACING".
- Start-light gantry: 5 pods, UNLIT at rest. On LIGHTS OUT they light one at a time, hold for a random moment, then ALL go out together (a real standing start), and the race begins.
- Big "LIGHTS OUT →" button (accent red) starts a run with the start-light sequence above.
- Pole card: purple "POLE" chip + best score in large purple numbers.
- Liveries row: 3 cards (Night Race, Rain Race, Desert Dusk), each showing a mini 2×2 block preview; the equipped one has an accent border.
- Bottom: "SETUP" and "CLEAN AIR · NO ADS" buttons, then a checkered strip along the bottom edge.

### Game screen
- Top row: menu button (44 px), a timing-panel score box (red edge bar, "SCORE" label, big italic number), and a purple "POLE" box with the best score.
- Pop-up area between the score and board: combo text in italic yellow, tilted ~-4°, e.g. "OVERTAKE!" with "COMBO ×3 · +180" below. Chosen by the pure function in `lib/ui/popup_text.dart`, where `combo` is the placement result's `comboAfter` (first clear = 1, next consecutive clear = 2, …) and `+points` is the placement's total points gained:
  - 3+ lines cleared → "FASTEST LAP!"
  - 2 lines → "SLIPSTREAM!"
  - 1 line with combo ≥ 2 → "OVERTAKE!"
  - 1 line, first clear → no word, just "+N"
  - Second line "COMBO ×{combo} · +{points}" only when combo ≥ 2 (a first-clear "SLIPSTREAM!" / "FASTEST LAP!" shows the word alone). No clear → no pop-up.
- Board: carbon panel with a checkered strip along its top edge and an 8 px inner padding, 4 px cell gaps.
- Drag: the piece lifts above the finger (offset upward), scales to board-cell size, and casts a deep shadow. The ghost preview is a dashed outline tinted with the piece's color. Rows and columns that would clear get a glowing yellow outline before release. An invalid drop animates back to the tray.
- Tray: dark panel with 3 slots at the bottom; a slot shows a dashed outline while its piece is lifted.
- When a new score passes the best score during play, flash the score purple ("fastest sector").

### Chequered flag (game-over screen)
- A large skewed checkered flag band at the top, then "CHEQUERED FLAG" and "No room left on the grid".
- Result card: "FINISH" + score, a purple "POLE x" chip with "N to beat it" (or "NEW POLE!" when beaten), then stats: lines cleared, best combo, pieces placed.
- Main button: "PIT STOP · FRESH TYRES" (yellow, play-ad icon, subtitle "Watch an ad, get 3 pieces that fit"); hide it if already used this run or no ad is loaded.
- Then "NEW RACE" (red outline) and "GARAGE" (back to home), and a small "One pit stop per race" note.

### Effects, sound, haptics
- Clears: a white speed streak sweeps across the line, blocks burst into sparks plus a little gray tyre smoke, then vanish.
- Sound: all original, synthesized by `tool/gen_sounds.py` (nothing sampled or downloaded). Two layers:
  - Every clear: a bell chime that climbs a pentatonic scale per combo step (`clear_1` … `clear_6`).
  - Big moments: a stylized V6 turbo single-seater flying past at top speed. `passby_full` plays when the lights go out; `passby_short` plays on FASTEST LAP! (3+ lines) and the first time a run passes Pole (only if Pole > 0), at most once per `PASSBY_COOLDOWN_MS`, never twice for the same move.
  - Also: placement click, a start-light beep per light.
- Haptics: light on placement, medium on clears, a "rumble strip" pattern (several quick light pulses) on combos of 3+.

### Liveries (themes)
**Night Race** (default, above), **Rain Race** (deep navy board, cool blue blocks), **Desert Dusk** (warm brown board, orange/sand/rose blocks). Same structure, different color tokens. Unlocks: Rain Race at 5,000 career points, Desert Dusk at 15,000 career points (named constants; starting guesses, tune after testing), or 3 rewarded ads each, or instantly with Remove Ads. Career points = the sum of final scores across all runs. Locked livery cards show progress, e.g. "3,240 / 5,000 pts · or watch 3 ads".

### General
Respect safe areas. Portrait only. Target 60 fps on mid-range phones. Touch targets ≥ 44 px.

## Monetization
- **Rewarded continue ("Pit Stop"):** at game over, offer it once per run. Reward: replace the tray with 3 pieces that each fit (fall back to singles if needed).
- **Interstitial:** only between games, shown on every 3rd game over, at least 90 seconds apart, never during the player's first session, never mid-run.
- **Remove Ads:** a non-consumable purchase with product ID `remove_ads`. It turns off interstitials; rewarded ads stay available as an opt-in. Include a "Restore Purchases" button in settings (Apple requires one).
- During development, use Google's official **test** ad unit IDs only. Keep real IDs in one config file.
- Run the UMP consent flow before loading any ads. On iOS, configure the App Tracking Transparency message.

## Persistence
Best score, career points, selected livery, livery unlock progress (rewarded ads watched per livery), sound and haptics toggles, `adsRemoved` flag, games-played counter, and first-session flag.

## Post-launch backlog (do NOT build in v1)
- Tracks: alternate boards with fictional names only (never real circuits), e.g. Harbour Night (standard 8×8), Hairpin (L-shaped board), Chicane (fixed blocked cells), Long Straight (9×7), Rain Run (random blocked cells). Each needs its own best score. First update candidate if day-30 data shows players leaving from sameness.
- Paid "Track Pack" (cosmetic/variety only, never easier scoring), only if tracks prove popular.
- Alternate app icons (iOS only; hidden on Android): concepts B Apex chevron, C Lights out, D Chequered block from the design canvas, as unlockable cosmetics (career points, or included with Remove Ads). v1 ships icon A only.

## Working rules for Claude Code
- Build in small steps. After each step, run `flutter analyze` and `flutter test`, and fix any issues before finishing.
- Every milestone must also pass `flutter build apk --debug`. No iOS-only APIs or plugins without an Android equivalent.
- Keep `lib/game/` pure Dart and fully unit-tested (placement, clears, scoring, combo, game-over detection, dealing).
- Don't add packages or change the stack without asking.
- Keep tunable numbers (weights, scores, ad frequency, animation timings) as named constants.
- At the end of each task, summarize what changed and anything I should test on a real device.

## Milestones
1. Core logic + tests
2. Night Race game screen: board, tray, drag-and-drop with ghost preview (playable)
3. Home screen, score/Pole UI, combo pop-ups, Chequered flag screen, best score
4. Start lights, clear effects, particles, haptics, sounds
5. Liveries + settings
6. Ads (consent, rewarded continue, interstitial)
7. Remove Ads purchase + restore
8. App icon, splash, store prep

# Apex Blocks: game spec (source of truth)

Flutter block-puzzle game. Game logic lives in `lib/game/` as pure Dart (no `package:flutter`, enforced by a test). Every tunable number is a named constant.

## Rules
- Board 8×8. Tray of 3 pieces. Place pieces anywhere they fit; no rotation by the player.
- A full row or column clears. Rows and columns completed by one placement clear simultaneously (a shared cell clears once).
- Game over when no remaining tray piece fits anywhere.

## Scoring (`scoring.dart`)
- 1 point per cell placed (`pointsPerCell`).
- Line bonus = `lineBonusBase (10) × n²`, n = lines cleared by that placement (row + column = 2).
- Combo streak = consecutive placements that clear at least one line. Clear bonus multiplier: ×1.0, ×1.5, ×2.0 (3rd and later). A non-clearing placement resets the streak. The multiplier applies to the bonus only. Round to int.
- Worked example: 3-cell piece, 3rd consecutive 1-line clear: 3 + 10×1²×2.0 = **23**.

## Turn order (`GameState.place`)
validate → stamp → detect full lines → clear simultaneously → score → update combo/stats → empty slot → refill tray if all 3 are empty → game-over check.

## Fair dealer
Deal 3 random pieces; if none fits the board, re-roll up to `dealerMaxRetries` (10) times; if still nothing fits, deal anyway. `dealFittingTray()` deals 3 that each fit, falling back to singles.

## Pieces (`pieces.dart`)
Orientations are distinct rotations/mirrors. A family's spawn weight is split evenly across its orientations.

| Family | Cells | Orientations | Weight |
|---|---|---|---|
| single | 1 | 1 | 4 |
| domino | 2 | 2 | 8 |
| lineTromino | 3 | 2 | 8 |
| lTromino | 3 | 4 | 8 |
| square2 | 4 | 1 | 8 |
| lineTetromino | 4 | 2 | 6 |
| lTetromino (L+J) | 4 | 8 | 8 |
| tTetromino | 4 | 4 | 6 |
| sTetromino (S+Z) | 4 | 4 | 6 |
| linePentomino | 5 | 2 | 3 |
| rect2x3 | 6 | 2 | 4 |
| bigL | 5 | 4 | 3 |
| square3 | 9 | 1 | 2 |

## Project
- Bundle ID / applicationId: `com.helvinrymer.apexblocks`. Portrait only.
- Best score is not stored in game state; storage comes in a later milestone.
- Check with `flutter analyze` and `flutter test`.

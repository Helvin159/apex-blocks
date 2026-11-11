import 'dart:math';

import 'board.dart';
import 'piece.dart';
import 'pieces.dart';
import 'scoring.dart';

/// Number of pieces in the tray.
const int traySize = 3;

/// How many random picks `dealFittingTray` tries per slot before using a single.
const int fittingPickAttempts = 50;

/// What a placement would do, without doing it.
class PlacementPreview {
  final bool valid;
  final List<Cell> cells;
  final List<int> wouldClearRows;
  final List<int> wouldClearCols;

  const PlacementPreview({
    required this.valid,
    required this.cells,
    required this.wouldClearRows,
    required this.wouldClearCols,
  });
}

/// The outcome of one placement.
class PlacementResult {
  final List<Cell> placedCells;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final int pointsGained;
  final int comboAfter;
  final bool trayRefilled;
  final bool gameOver;

  const PlacementResult({
    required this.placedCells,
    required this.clearedRows,
    required this.clearedCols,
    required this.pointsGained,
    required this.comboAfter,
    required this.trayRefilled,
    required this.gameOver,
  });
}

class GameState {
  final Random _random;
  Board board;
  final List<Piece?> tray;
  int score = 0;

  /// Consecutive placements that cleared at least one line.
  int combo = 0;

  int linesCleared = 0;
  int bestCombo = 0;
  int piecesPlaced = 0;

  /// [board] and [tray] can be supplied to start from a crafted position.
  GameState({Random? random, Board? board, List<Piece?>? tray})
    : _random = random ?? Random(),
      board = board ?? Board(),
      tray = tray ?? List<Piece?>.filled(traySize, null) {
    if (tray == null) this.tray.setAll(0, dealTray());
  }

  bool get isGameOver {
    final remaining = tray.whereType<Piece>();
    if (remaining.isEmpty) return false;
    return remaining.every((p) => !board.anyPlacementFor(p));
  }

  PlacementPreview preview(int slot, int row, int col) {
    final piece = tray[slot];
    if (piece == null) {
      return const PlacementPreview(
        valid: false,
        cells: [],
        wouldClearRows: [],
        wouldClearCols: [],
      );
    }
    final cells = [
      for (final c in piece.cells) (row: row + c.row, col: col + c.col),
    ];
    if (!board.canPlace(piece, row, col)) {
      return PlacementPreview(
        valid: false,
        cells: cells,
        wouldClearRows: [],
        wouldClearCols: [],
      );
    }
    final sim = board.copy()..place(piece, row, col);
    return PlacementPreview(
      valid: true,
      cells: cells,
      wouldClearRows: sim.fullRows(),
      wouldClearCols: sim.fullCols(),
    );
  }

  /// Places the tray piece in [slot]. Throws if the slot is empty or the
  /// placement is invalid; use [preview] to check first.
  PlacementResult place(int slot, int row, int col) {
    final piece = tray[slot];
    if (piece == null) throw StateError('Tray slot $slot is empty');

    board.place(piece, row, col);
    final cells = [
      for (final c in piece.cells) (row: row + c.row, col: col + c.col),
    ];
    final cleared = board.clearLines();
    final lines = cleared.rows.length + cleared.cols.length;

    final gained = placementPoints(cells.length) + clearPoints(lines, combo);
    score += gained;
    combo = lines > 0 ? combo + 1 : 0;
    bestCombo = max(bestCombo, combo);
    linesCleared += lines;
    piecesPlaced++;

    tray[slot] = null;
    final refilled = tray.every((p) => p == null);
    if (refilled) tray.setAll(0, dealTray());

    return PlacementResult(
      placedCells: cells,
      clearedRows: cleared.rows,
      clearedCols: cleared.cols,
      pointsGained: gained,
      comboAfter: combo,
      trayRefilled: refilled,
      gameOver: isGameOver,
    );
  }

  /// Fair dealer: see [dealFairTray].
  List<Piece> dealTray() => dealFairTray(_random, board, score);

  /// Three pieces that each fit the current board, falling back to singles.
  List<Piece> dealFittingTray() => [
    for (var i = 0; i < traySize; i++) _fittingPiece(fittingPickAttempts),
  ];

  Piece _fittingPiece(int attempts) {
    for (var i = 0; i < attempts; i++) {
      final piece = pickPiece(_random);
      if (board.anyPlacementFor(piece)) return piece;
    }
    return singlePiece;
  }
}

/// Deals a tray by weight (blended for [score], see [weightsForScore]) from
/// only the pieces that fit [board] right now. If nothing fits, deals by
/// weight anyway; that board is game over.
List<Piece> dealFairTray(Random random, Board board, int score) {
  final weights = weightsForScore(score);
  final fits = {for (final p in allPieces) p: board.anyPlacementFor(p)};
  return [
    for (var i = 0; i < traySize; i++)
      pickPiece(random, weights: weights, where: (p) => fits[p]!),
  ];
}

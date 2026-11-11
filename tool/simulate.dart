// Greedy-bot simulator for tuning the dealer and difficulty ramp.
//
//   dart run tool/simulate.dart [gamesPerVariant]
//
// Plays seeded games with a bot that tries every piece order and every
// position for the whole tray, and compares the Tuning pass 1 rules against
// the current ones. Pure Dart; shares only lib/game with the app.
// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import '../lib/game/board.dart';
import '../lib/game/game_state.dart';
import '../lib/game/piece.dart';
import '../lib/game/pieces.dart';
import '../lib/game/scoring.dart';

const int defaultGames = 500;

/// A game stops once this many pieces have been placed.
const int pieceCap = 3000;

/// Tuning pass 1 dealer, kept here only for the before/after comparison:
/// re-roll each slot up to this many times, then fall back to a single.
const int oldDealerMaxRetries = 10;

List<Piece> dealOld(Random random, Board board) => [
  for (var i = 0; i < traySize; i++)
    () {
      for (var t = 0; t < oldDealerMaxRetries; t++) {
        final piece = pickPiece(random);
        if (board.anyPlacementFor(piece)) return piece;
      }
      return singlePiece;
    }(),
];

// ---- Bitmask board (bit = row * 8 + col) ----

const int _col0 = 0x0101010101010101;
const int _col7 = _col0 << 7;

int _popcount(int v) {
  var n = 0;
  while (v != 0) {
    v &= v - 1;
    n++;
  }
  return n;
}

int _toMask(Board b) {
  var m = 0;
  for (var r = 0; r < boardSize; r++) {
    for (var c = 0; c < boardSize; c++) {
      if (b.cellAt(r, c) != null) m |= 1 << (r * boardSize + c);
    }
  }
  return m;
}

int _pieceMask(Piece p) {
  var m = 0;
  for (final c in p.cells) {
    m |= 1 << (c.row * boardSize + c.col);
  }
  return m;
}

/// Empty cells with no empty 4-neighbour.
int _isolatedEmpty(int filled) {
  final e = ~filled;
  final near =
      (e << 8) | (e >>> 8) | ((e << 1) & ~_col0) | ((e >>> 1) & ~_col7);
  return _popcount(e & ~near);
}

typedef _Move = ({int piece, int row, int col});

class _Best {
  int placed = -1;
  int lines = -1;
  int isolated = 1 << 30;
  List<_Move> moves = const [];

  void offer(int p, int l, int iso, List<_Move> m) {
    if (p > placed ||
        (p == placed && (l > lines || (l == lines && iso < isolated)))) {
      placed = p;
      lines = l;
      isolated = iso;
      moves = List.of(m);
    }
  }
}

void _search(
  List<Piece> pieces,
  List<int> masks,
  int used,
  int filled,
  int placed,
  int lines,
  List<_Move> path,
  _Best best,
) {
  var extended = false;
  final seen = <String>{};
  for (var i = 0; i < pieces.length; i++) {
    if (used & (1 << i) != 0 || !seen.add(pieces[i].id)) continue;
    final p = pieces[i];
    for (var r = 0; r <= boardSize - p.height; r++) {
      for (var c = 0; c <= boardSize - p.width; c++) {
        final m = masks[i] << (r * boardSize + c);
        if (filled & m != 0) continue;
        extended = true;
        var next = filled | m;
        var clear = 0, n = 0;
        for (var k = 0; k < boardSize; k++) {
          final row = 0xFF << (k * boardSize);
          final col = _col0 << k;
          if (next & row == row) {
            clear |= row;
            n++;
          }
          if (next & col == col) {
            clear |= col;
            n++;
          }
        }
        next &= ~clear;
        path.add((piece: i, row: r, col: c));
        _search(
          pieces,
          masks,
          used | (1 << i),
          next,
          placed + 1,
          lines + n,
          path,
          best,
        );
        path.removeLast();
      }
    }
  }
  if (!extended) best.offer(placed, lines, _isolatedEmpty(filled), path);
}

typedef GameResult = ({int pieces, int score, bool capped});

GameResult playGame(int seed, {required bool newRules}) {
  final random = Random(seed);
  final board = Board();
  var score = 0, combo = 0, placed = 0;

  List<Piece> deal() =>
      newRules ? dealFairTray(random, board, score) : dealOld(random, board);

  while (true) {
    final tray = deal();
    final best = _Best();
    _search(
      tray,
      [for (final p in tray) _pieceMask(p)],
      0,
      _toMask(board),
      0,
      0,
      [],
      best,
    );
    for (final mv in best.moves) {
      final piece = tray[mv.piece];
      board.place(piece, mv.row, mv.col);
      final lines = board.clearLines();
      final n = lines.rows.length + lines.cols.length;
      score += placementPoints(piece.cells.length) + clearPoints(n, combo);
      combo = n > 0 ? combo + 1 : 0;
      placed++;
      if (placed >= pieceCap) {
        return (pieces: placed, score: score, capped: true);
      }
    }
    if (best.moves.length < tray.length) {
      return (pieces: placed, score: score, capped: false);
    }
  }
}

int _percentile(List<int> sorted, double p) =>
    sorted[((sorted.length - 1) * p).round()];

String _row(String label, List<GameResult> games) {
  final pieces = games.map((g) => g.pieces).toList()..sort();
  final scores = games.map((g) => g.score).toList()..sort();
  final capped = games.where((g) => g.capped).length * 100 / games.length;
  String f(List<int> v) =>
      '${_percentile(v, 0.5)} / ${_percentile(v, 0.1)} / ${_percentile(v, 0.9)}';
  return '${label.padRight(22)}${f(pieces).padRight(20)}${f(scores).padRight(24)}'
      '${capped.toStringAsFixed(1)}%';
}

Future<List<GameResult>> _runVariant(int games, bool newRules) async {
  final workers = max(1, Platform.numberOfProcessors - 1);
  final futures = <Future<List<GameResult>>>[];
  for (var w = 0; w < workers; w++) {
    futures.add(
      Isolate.run(
        () => [
          for (var seed = w; seed < games; seed += workers)
            playGame(seed, newRules: newRules),
        ],
      ),
    );
  }
  return [for (final chunk in await Future.wait(futures)) ...chunk];
}

Future<void> main(List<String> args) async {
  final games = args.isEmpty ? defaultGames : int.parse(args.first);
  final clock = Stopwatch()..start();
  final before = await _runVariant(games, false);
  final after = await _runVariant(games, true);
  print(
    '$games seeded games per variant, cap $pieceCap pieces '
    '(${clock.elapsed.inSeconds}s)\n',
  );
  print(
    '${'Variant'.padRight(22)}${'Pieces med/p10/p90'.padRight(20)}'
    '${'Score med/p10/p90'.padRight(24)}Capped',
  );
  print(_row('Tuning pass 1 rules', before));
  print(_row('Tuning pass 2 rules', after));
}

import 'package:apexblocks/game/board.dart';
import 'package:apexblocks/game/game_state.dart';
import 'package:apexblocks/game/piece.dart';
import 'package:apexblocks/game/pieces.dart';
import 'package:apexblocks/services/audio_service.dart';
import 'package:apexblocks/services/haptics_service.dart';
import 'package:apexblocks/services/storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<Size> phoneSizes = [Size(320, 568), Size(375, 667), Size(430, 932)];

Future<StorageService> makeStorage([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return StorageService.open(await SharedPreferences.getInstance());
}

void useScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Piece family(PieceFamily f) => piecesByFamily[f]!.first;

/// A checkerboard whose empty cells are all isolated, with a tray of one
/// single and two 2×2 squares. Placing the single anywhere ends the game
/// without clearing a line.
GameState nearlyDeadGame() {
  final board = Board();
  for (var r = 0; r < boardSize; r++) {
    for (var c = 0; c < boardSize; c++) {
      if ((r + c).isEven) board.setCell(r, c, 1);
    }
  }
  return GameState(
    board: board,
    tray: [
      family(PieceFamily.single),
      family(PieceFamily.square2),
      family(PieceFamily.square2),
    ],
  );
}

/// An [AudioService] that records what would have played.
class RecordingAudio extends AudioService {
  RecordingAudio() : super.silent();

  final List<String> events = [];

  @override
  void playPlace() => events.add('place');

  @override
  void playClear(int comboAfter) => events.add('clear_$comboAfter');

  @override
  void playLight() => events.add('light');

  @override
  void playLightsOut() => events.add('lights_out');
}

/// A [HapticsService] that records placements.
class RecordingHaptics extends HapticsService {
  RecordingHaptics() : super.silent();

  final List<({int lines, int combo})> placements = [];

  @override
  void onPlacement({required int linesCleared, required int comboAfter}) =>
      placements.add((lines: linesCleared, combo: comboAfter));
}

/// A board with row 7 filled except its last cell, and a tray of a single
/// and two 2×2 squares. Placing the single at (7, 7) clears row 7.
GameState oneLineFromClearing() {
  final board = Board();
  for (var c = 0; c < boardSize - 1; c++) {
    board.setCell(7, c, 1);
  }
  return GameState(
    board: board,
    tray: [
      family(PieceFamily.single),
      family(PieceFamily.square2),
      family(PieceFamily.square2),
    ],
  );
}

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/game_state.dart';
import '../game/piece.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/sound_plan.dart';
import '../services/storage_service.dart';
import '../theme/themes.dart';
import 'block_painter.dart';
import 'board_geometry.dart';
import 'board_view.dart';
import 'combo_popup.dart';
import 'effects/clear_effects.dart';
import 'effects/cleared_cells.dart';
import 'game_over_screen.dart';
import 'popup_text.dart';
import 'tray_view.dart';

/// Time for a lifted piece to grow from tray size to board-cell size.
const int dragScaleMs = 120;

/// Time for a rejected piece to fly back to its tray slot.
const int returnMs = 180;

const double _screenPadding = 16;
const double _sectionGap = 12;
const double _headerHeight = 64;

/// Menu button edge; also the minimum touch target.
const double _menuButtonSize = 44;

/// Height reserved between the header and the board for combo pop-ups.
const double _popupHeight = 44;

/// How long the score stays purple after passing the best score.
const int scoreFlashMs = 900;

/// Tray blocks are at most this fraction of a board cell.
const double _trayCellMaxRatio = 0.6;

/// One piece being dragged, from pointer-down until it lands or flies back.
class _DragSession extends ChangeNotifier {
  final int slot;
  final Piece piece;

  /// Piece center in its slot minus the pointer-down position; decays as the
  /// piece lifts so it doesn't jump.
  final Offset grab;
  final double trayCell;
  final double boardCell;
  final double boardStep;

  /// Overlay origin in global coordinates.
  final Offset origin;

  Offset pointer;

  /// Lift/scale progress, 0 (in the tray) to 1 (floating at board size).
  double t = 0;

  bool returning = false;
  double returnT = 0;
  late Offset _returnFromCenter;
  late double _returnFromCell;
  late double _returnFromGap;
  late Offset _returnToCenter;

  _DragSession({
    required this.slot,
    required this.piece,
    required this.pointer,
    required this.grab,
    required this.trayCell,
    required this.boardCell,
    required this.boardStep,
    required this.origin,
  });

  void changed() => notifyListeners();

  ({Offset center, double cell, double gap}) visual() {
    if (returning) {
      final e = Curves.easeOutCubic.transform(returnT);
      return (
        center: Offset.lerp(_returnFromCenter, _returnToCenter, e)!,
        cell: ui.lerpDouble(_returnFromCell, trayCell, e)!,
        gap: ui.lerpDouble(_returnFromGap, trayCellGap, e)!,
      );
    }
    final e = Curves.easeOutCubic.transform(t);
    return (
      center:
          pointer + grab * (1 - e) - Offset(0, dragLiftCells * boardStep * e),
      cell: ui.lerpDouble(trayCell, boardCell, e)!,
      gap: ui.lerpDouble(trayCellGap, cellGap, e)!,
    );
  }

  void startReturn(Offset slotCenter) {
    final v = visual();
    _returnFromCenter = v.center;
    _returnFromCell = v.cell;
    _returnFromGap = v.gap;
    _returnToCenter = slotCenter;
    returning = true;
    returnT = 0;
  }
}

class _DragPainter extends CustomPainter {
  final _DragSession session;
  final ApexTheme theme;

  _DragPainter(this.session, this.theme) : super(repaint: session);

  @override
  void paint(Canvas canvas, Size size) {
    final s = session;
    final v = s.visual();
    final extent = pieceExtent(s.piece, v.cell, v.gap);
    final topLeft = v.center - Offset(extent.width / 2, extent.height / 2);

    canvas.translate(-s.origin.dx, -s.origin.dy);

    // Deep shadow that grows with the lift.
    final span = s.boardCell - s.trayCell;
    final lift = span <= 0
        ? 1.0
        : ((v.cell - s.trayCell) / span).clamp(0.0, 1.0);
    if (lift > 0) {
      final shadow = Path();
      for (final c in s.piece.cells) {
        shadow.addRRect(
          RRect.fromRectAndRadius(
            pieceCellRect(topLeft, c, v.cell, v.gap),
            Radius.circular(blockRadiusFor(v.cell)),
          ),
        );
      }
      canvas.drawPath(
        shadow.shift(Offset(0, v.cell * 0.8 * lift)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.55 * lift)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            v.cell * 0.35 * lift + 0.1,
          ),
      );
    }

    paintPiece(
      canvas,
      s.piece,
      topLeft,
      v.cell,
      v.gap,
      theme.blocks[s.piece.colorId],
      shadow: false,
    );
  }

  @override
  bool shouldRepaint(_DragPainter old) =>
      old.session != session || old.theme != theme;
}

class GameScreen extends StatefulWidget {
  final StorageService storage;
  final ApexTheme theme;

  /// Builds the game for each run; tests use it to start from a crafted
  /// position.
  final GameState Function() newGame;

  /// Sounds and haptics; silent when omitted (tests).
  final AudioService? audio;
  final HapticsService? haptics;

  const GameScreen({
    super.key,
    required this.storage,
    this.theme = nightRace,
    this.newGame = GameState.new,
    this.audio,
    this.haptics,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameState _game = widget.newGame();
  late final AudioService _audio = widget.audio ?? AudioService.silent();
  late final HapticsService _haptics =
      widget.haptics ?? HapticsService.silent();

  /// Line-clear overlay; purely visual, never blocks input.
  late final ClearEffectsController _effects = ClearEffectsController(
    vsync: this,
  );

  // Run bookkeeping. `_runRecorded` makes sure a finished run is booked once,
  // however often the screen rebuilds.
  bool _runRecorded = false;
  late int _bestAtStart = widget.storage.bestScore;
  int _previousBest = 0;
  bool _flashed = false;
  final ValueNotifier<PopupEvent?> _popup = ValueNotifier(null);
  int _popupId = 0;
  late final AnimationController _flashCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: scoreFlashMs),
  );

  /// Bumped whenever the board changes, so the board painter repaints.
  final ValueNotifier<int> _boardTick = ValueNotifier(0);
  final ValueNotifier<GhostInfo?> _ghost = ValueNotifier(null);
  final ValueNotifier<int?> _hiddenSlot = ValueNotifier(null);

  final GlobalKey _boardKey = GlobalKey();
  final List<GlobalKey> _slotKeys = List.generate(traySize, (_) => GlobalKey());

  late final AnimationController _scaleCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: dragScaleMs),
  );
  late final AnimationController _returnCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: returnMs),
  );

  // Layout from the latest build; used to translate pointer positions.
  BoardGeometry _geometry = const BoardGeometry(300);
  double _trayCell = 16;

  _DragSession? _session;
  OverlayEntry? _entry;
  int? _pointerId;
  TargetCell? _lastTarget;

  @override
  void initState() {
    super.initState();
    _scaleCtl.addListener(() {
      final s = _session;
      if (s == null || s.returning) return;
      s.t = _scaleCtl.value;
      s.changed();
    });
    _returnCtl.addListener(() {
      final s = _session;
      if (s == null || !s.returning) return;
      s.returnT = _returnCtl.value;
      s.changed();
    });
    _returnCtl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _endDrag();
    });
  }

  @override
  void dispose() {
    _endDrag();
    _scaleCtl.dispose();
    _returnCtl.dispose();
    _boardTick.dispose();
    _ghost.dispose();
    _hiddenSlot.dispose();
    _popup.dispose();
    _flashCtl.dispose();
    _effects.dispose();
    super.dispose();
  }

  Offset _slotCenter(int slot) {
    final box = _slotKeys[slot].currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  Offset _boardLocal(Offset global) {
    final box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(global);
  }

  void _onSlotDown(int slot, PointerDownEvent event) {
    if (_session != null || _game.isGameOver) return;
    final piece = _game.tray[slot];
    if (piece == null) return;

    final overlay = Overlay.of(context);
    final origin = (overlay.context.findRenderObject() as RenderBox)
        .localToGlobal(Offset.zero);
    final session = _DragSession(
      slot: slot,
      piece: piece,
      pointer: event.position,
      grab: _slotCenter(slot) - event.position,
      trayCell: _trayCell,
      boardCell: _geometry.cellSize,
      boardStep: _geometry.step,
      origin: origin,
    );
    _session = session;
    _pointerId = event.pointer;
    _lastTarget = null;
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _onPointer);

    _hiddenSlot.value = slot;
    _entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _DragPainter(session, widget.theme)),
        ),
      ),
    );
    overlay.insert(_entry!);
    _scaleCtl.forward(from: 0);
    _updateGhost();
  }

  void _onPointer(PointerEvent event) {
    final s = _session;
    if (s == null || s.returning || event.pointer != _pointerId) return;
    if (event is PointerMoveEvent) {
      s.pointer = event.position;
      s.changed();
      _updateGhost();
    } else if (event is PointerUpEvent) {
      s.pointer = event.position;
      _drop();
    } else if (event is PointerCancelEvent) {
      _startReturn();
    }
  }

  /// Recomputes the ghost only when the snapped cell changes.
  void _updateGhost() {
    final s = _session!;
    final target = targetCell(
      _geometry,
      _boardLocal(s.pointer),
      s.piece.height,
      s.piece.width,
    );
    if (target == _lastTarget) return;
    _lastTarget = target;
    if (target == null) {
      _ghost.value = null;
      return;
    }
    final p = _game.preview(s.slot, target.row, target.col);
    _ghost.value = p.valid
        ? GhostInfo(
            cells: p.cells,
            colorId: s.piece.colorId,
            clearRows: p.wouldClearRows,
            clearCols: p.wouldClearCols,
          )
        : null;
  }

  void _drop() {
    final s = _session!;
    _stopRouting();
    _updateGhost();
    final target = _lastTarget;
    if (target != null && _ghost.value != null) {
      final slot = s.slot;
      final piece = s.piece;
      // Cleared cells are gone once placed; keep their colors for the effect.
      final before = _game.board.copy();
      _endDrag();
      late PlacementResult result;
      setState(() => result = _game.place(slot, target.row, target.col));
      _boardTick.value++;
      _afterPlacement(result, before, piece, target);
    } else {
      _beginReturn(s);
    }
  }

  void _startReturn() {
    final s = _session;
    if (s == null) return;
    _stopRouting();
    _beginReturn(s);
  }

  void _beginReturn(_DragSession s) {
    _ghost.value = null;
    _scaleCtl.stop();
    s.startReturn(_slotCenter(s.slot));
    _returnCtl.forward(from: 0);
  }

  void _stopRouting() {
    final id = _pointerId;
    if (id != null) {
      GestureBinding.instance.pointerRouter.removeRoute(id, _onPointer);
    }
    _pointerId = null;
  }

  void _endDrag() {
    _stopRouting();
    _scaleCtl.stop();
    _returnCtl.stop();
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    _session?.dispose();
    _session = null;
    _lastTarget = null;
    _ghost.value = null;
    _hiddenSlot.value = null;
  }

  void _afterPlacement(
    PlacementResult result,
    Board before,
    Piece piece,
    TargetCell target,
  ) {
    final lines = result.clearedRows.length + result.clearedCols.length;
    final plan = soundPlanFor(
      result: result,
      scoreAfter: _game.score,
      poleBefore: _bestAtStart,
      polePassedAlready: _flashed,
      msSinceLastPassby: _audio.msSincePassby,
    );
    _audio.playPlace();
    _haptics.onPlacement(linesCleared: lines, comboAfter: result.comboAfter);
    if (plan.chimeVariant != null) _audio.playClear(result.comboAfter);
    if (plan.passby) _audio.playPassbyShort();
    if (lines > 0) {
      _effects.trigger(
        cells: clearedCellsOf(
          before: before,
          piece: piece,
          row: target.row,
          col: target.col,
          clearedRows: result.clearedRows,
          clearedCols: result.clearedCols,
        ),
        rows: result.clearedRows,
        cols: result.clearedCols,
        geometry: _geometry,
        theme: widget.theme,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
      );
    }

    final text = popupFor(result);
    if (text != null) _popup.value = PopupEvent(++_popupId, text);

    if (!_flashed && _bestAtStart > 0 && _game.score > _bestAtStart) {
      _flashed = true;
      _flashCtl.forward(from: 0);
    }

    if (result.gameOver && !_runRecorded) {
      _runRecorded = true;
      _previousBest = widget.storage.bestScore;
      widget.storage.recordRun(_game.score);
    }
  }

  void _restart() {
    setState(() {
      _game = widget.newGame();
      _runRecorded = false;
      _flashed = false;
      _bestAtStart = widget.storage.bestScore;
    });
    _effects.clear();
    _flashCtl.value = 0;
    _boardTick.value++;
  }

  void _garage() => Navigator.of(context).pop();

  Future<void> _openMenu() async {
    if (_session != null || _game.isGameOver) return;
    final choice = await showModalBottomSheet<_MenuChoice>(
      context: context,
      backgroundColor: widget.theme.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PauseSheet(theme: widget.theme),
    );
    if (!mounted) return;
    switch (choice) {
      case _MenuChoice.restart:
        _restart();
      case _MenuChoice.garage:
        _garage();
      case _MenuChoice.resume || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth - 2 * _screenPadding;
            final tray = trayMetrics(width);
            final trayPanelHeight = tray.slotHeight + 2 * trayPadding + 2;
            final fixed =
                _headerHeight +
                _popupHeight +
                trayPanelHeight +
                4 * _sectionGap;
            final boardWidth = (constraints.maxHeight - fixed - stripHeight)
                .clamp(120.0, width);
            _geometry = BoardGeometry(boardWidth);
            _trayCell = tray.cell < _geometry.cellSize * _trayCellMaxRatio
                ? tray.cell
                : _geometry.cellSize * _trayCellMaxRatio;

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(_screenPadding)
                      .copyWith(top: _sectionGap, bottom: _sectionGap),
                  child: Column(
                    children: [
                      _Header(
                        theme: theme,
                        score: _game.score,
                        best: widget.storage.bestScore,
                        flash: _flashCtl,
                        onMenu: _openMenu,
                      ),
                      SizedBox(
                        height: _popupHeight,
                        child: Center(
                          child: ComboPopup(event: _popup, theme: theme),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            key: _boardKey,
                            width: _geometry.panelWidth,
                            height: _geometry.panelHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                BoardView(
                                  game: _game,
                                  theme: theme,
                                  geometry: _geometry,
                                  repaint: _boardTick,
                                  ghost: _ghost,
                                ),
                                Positioned.fill(
                                  child: ClearEffectsOverlay(
                                    controller: _effects,
                                    geometry: _geometry,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: _sectionGap),
                      TrayView(
                        tray: _game.tray,
                        theme: theme,
                        cell: _trayCell,
                        slotHeight: tray.slotHeight,
                        hiddenSlot: _hiddenSlot,
                        slotKeys: _slotKeys,
                        onSlotDown: _onSlotDown,
                      ),
                    ],
                  ),
                ),
                if (_game.isGameOver)
                  Positioned.fill(
                    child: GameOverScreen(
                      theme: theme,
                      score: _game.score,
                      previousBest: _previousBest,
                      linesCleared: _game.linesCleared,
                      bestCombo: _game.bestCombo,
                      piecesPlaced: _game.piecesPlaced,
                      onNewRace: _restart,
                      onGarage: _garage,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Menu button, timing-panel score and POLE box.
class _Header extends StatelessWidget {
  final ApexTheme theme;
  final int score;
  final int best;
  final Animation<double> flash;
  final VoidCallback onMenu;

  const _Header({
    required this.theme,
    required this.score,
    required this.best,
    required this.flash,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          SizedBox(
            width: _menuButtonSize,
            height: _menuButtonSize,
            child: IconButton(
              tooltip: 'Menu',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: theme.panelAlt,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.border),
                ),
              ),
              icon: Icon(Icons.menu, color: theme.text, size: 22),
              onPressed: onMenu,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _ScoreBox(score: score, theme: theme, flash: flash),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _PoleBox(best: score > best ? score : best, theme: theme),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final int score;
  final ApexTheme theme;
  final Animation<double> flash;

  const _ScoreBox({
    required this.score,
    required this.theme,
    required this.flash,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _headerHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.panelAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(width: 5, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCORE', style: _boxLabel(theme.muted)),
                AnimatedBuilder(
                  animation: flash,
                  builder: (context, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$score',
                      style: _boxNumber(
                        // Purple at once, easing back to white.
                        Color.lerp(
                          theme.text,
                          theme.pole,
                          flash.value == 0 ? 0 : 1 - flash.value,
                        )!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PoleBox extends StatelessWidget {
  final int best;
  final ApexTheme theme;

  const _PoleBox({required this.best, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.pole.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.pole),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POLE', style: _boxLabel(theme.poleLight)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$best', style: _boxNumber(theme.poleLight, size: 26)),
          ),
        ],
      ),
    );
  }
}

TextStyle _boxLabel(Color color) => TextStyle(
  fontFamily: 'Inter',
  fontVariations: const [FontVariation('wght', 600)],
  fontSize: 11,
  letterSpacing: 1.5,
  height: 1,
  color: color,
);

TextStyle _boxNumber(Color color, {double size = 34}) => TextStyle(
  fontFamily: 'BarlowCondensed',
  fontWeight: FontWeight.w800,
  fontStyle: FontStyle.italic,
  fontSize: size,
  height: 1.05,
  color: color,
);

enum _MenuChoice { resume, restart, garage }

class _PauseSheet extends StatelessWidget {
  final ApexTheme theme;

  const _PauseSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetButton(
              label: 'RESUME',
              color: theme.accent,
              filled: true,
              onTap: () => Navigator.pop(context, _MenuChoice.resume),
            ),
            const SizedBox(height: 10),
            _SheetButton(
              label: 'RESTART',
              color: theme.highlight,
              onTap: () => Navigator.pop(context, _MenuChoice.restart),
            ),
            const SizedBox(height: 10),
            _SheetButton(
              label: 'GARAGE',
              color: theme.muted,
              onTap: () => Navigator.pop(context, _MenuChoice.garage),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'BarlowCondensed',
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      fontSize: 22,
      letterSpacing: 1,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: shape,
              ),
              onPressed: onTap,
              child: Text(label, style: style),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 2),
                shape: shape,
              ),
              onPressed: onTap,
              child: Text(label, style: style),
            ),
    );
  }
}

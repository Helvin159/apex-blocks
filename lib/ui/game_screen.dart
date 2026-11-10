import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/piece.dart';
import '../theme/themes.dart';
import 'block_painter.dart';
import 'board_geometry.dart';
import 'board_view.dart';
import 'tray_view.dart';

/// Time for a lifted piece to grow from tray size to board-cell size.
const int dragScaleMs = 120;

/// Time for a rejected piece to fly back to its tray slot.
const int returnMs = 180;

const double _screenPadding = 16;
const double _sectionGap = 12;
const double _headerHeight = 64;

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
  final ApexTheme theme;

  const GameScreen({super.key, this.theme = nightRace});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GameState _game = GameState();

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
      _endDrag();
      setState(() => _game.place(slot, target.row, target.col));
      _boardTick.value++;
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

  void _restart() {
    setState(() => _game = GameState());
    _boardTick.value++;
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
            final fixed = _headerHeight + trayPanelHeight + 4 * _sectionGap;
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
                      _ScoreBox(score: _game.score, theme: theme),
                      const SizedBox(height: _sectionGap),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            key: _boardKey,
                            width: _geometry.panelWidth,
                            height: _geometry.panelHeight,
                            child: BoardView(
                              game: _game,
                              theme: theme,
                              geometry: _geometry,
                              repaint: _boardTick,
                              ghost: _ghost,
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
                  _GameOverLayer(
                    score: _game.score,
                    theme: theme,
                    onRestart: _restart,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final int score;
  final ApexTheme theme;

  const _ScoreBox({required this.score, required this.theme});

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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCORE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontVariations: const [FontVariation('wght', 600)],
                  fontSize: 11,
                  letterSpacing: 1.5,
                  height: 1,
                  color: theme.muted,
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 34,
                  height: 1.05,
                  color: theme.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder game-over layer; the real Chequered Flag screen comes later.
class _GameOverLayer extends StatelessWidget {
  final int score;
  final ApexTheme theme;
  final VoidCallback onRestart;

  const _GameOverLayer({
    required this.score,
    required this.theme,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: theme.background.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 40,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Score $score',
                style: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  color: theme.muted,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRestart,
                  child: const Text(
                    'Restart',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

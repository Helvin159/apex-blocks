import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../game/game_state.dart';
import '../game/piece.dart';
import '../theme/themes.dart';
import 'block_painter.dart';

/// Gap between blocks of a piece sitting in the tray.
const double trayCellGap = 2;

/// Padding inside the tray panel and between slots.
const double trayPadding = 8;
const double traySlotGap = 6;

/// Longest piece edge, in cells; slots are sized to hold it.
const int trayMaxPieceCells = 5;

/// Tray cell size and slot height for a tray panel of [panelWidth].
({double cell, double slotHeight, double slotWidth}) trayMetrics(
  double panelWidth,
) {
  final slotWidth =
      (panelWidth - 2 * trayPadding - (traySize - 1) * traySlotGap) / traySize;
  const inset = 8.0;
  final cell =
      (slotWidth - inset - (trayMaxPieceCells - 1) * trayCellGap) /
      trayMaxPieceCells;
  final slotHeight =
      trayMaxPieceCells * cell + (trayMaxPieceCells - 1) * trayCellGap + inset;
  return (cell: cell, slotHeight: slotHeight, slotWidth: slotWidth);
}

/// Dark panel with three piece slots. A slot whose piece is being dragged
/// ([hiddenSlot]) shows a dashed outline of the piece instead.
class TrayView extends StatelessWidget {
  final List<Piece?> tray;
  final ApexTheme theme;
  final double cell;
  final double slotHeight;
  final ValueListenable<int?> hiddenSlot;
  final List<GlobalKey> slotKeys;
  final void Function(int slot, PointerDownEvent event) onSlotDown;

  const TrayView({
    super.key,
    required this.tray,
    required this.theme,
    required this.cell,
    required this.slotHeight,
    required this.hiddenSlot,
    required this.slotKeys,
    required this.onSlotDown,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(trayPadding),
        child: Row(
          children: [
            for (var i = 0; i < tray.length; i++) ...[
              if (i > 0) const SizedBox(width: traySlotGap),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => onSlotDown(i, e),
                  child: SizedBox(
                    key: slotKeys[i],
                    height: slotHeight,
                    child: CustomPaint(
                      painter: _SlotPainter(
                        slot: i,
                        piece: tray[i],
                        theme: theme,
                        cell: cell,
                        hiddenSlot: hiddenSlot,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotPainter extends CustomPainter {
  final int slot;
  final Piece? piece;
  final ApexTheme theme;
  final double cell;
  final ValueListenable<int?> hiddenSlot;

  _SlotPainter({
    required this.slot,
    required this.piece,
    required this.theme,
    required this.cell,
    required this.hiddenSlot,
  }) : super(repaint: hiddenSlot);

  @override
  void paint(Canvas canvas, Size size) {
    final slotRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(slotRRect, Paint()..color = theme.panelAlt);

    final p = piece;
    if (p == null) return;
    final extent = pieceExtent(p, cell, trayCellGap);
    final topLeft = Offset(
      (size.width - extent.width) / 2,
      (size.height - extent.height) / 2,
    );

    if (hiddenSlot.value == slot) {
      for (final c in p.cells) {
        paintDashedRRect(
          canvas,
          RRect.fromRectAndRadius(
            pieceCellRect(topLeft, c, cell, trayCellGap).deflate(1),
            Radius.circular(blockRadiusFor(cell)),
          ),
          theme.muted.withValues(alpha: 0.55),
          strokeWidth: 1.2,
          dash: 4,
          gap: 3,
        );
      }
    } else {
      paintPiece(
        canvas,
        p,
        topLeft,
        cell,
        trayCellGap,
        theme.blocks[p.colorId],
      );
    }
  }

  @override
  bool shouldRepaint(_SlotPainter old) =>
      old.slot != slot ||
      old.piece != piece ||
      old.cell != cell ||
      old.theme != theme;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// /show scoreboard layout maths, carved out of `show_screen.dart`
/// (SHADOW-003/I-096: that file is inside the W-012 tainted cone and cannot
/// run under `flutter test`; this file imports ONLY material and takes
/// plain values). Pure function + taint-free shell widget.

/// Target scoreboard tile SHAPE: height per width (2026-09-10, per the
/// presenter's ask — "all slightly taller, not fully mobile, but somewhat
/// in that direction"). 1.2 reads as a mild portrait card (~10×12) —
/// clearly taller than the wide ~3:2–3:1 slabs this replaced, well short of
/// phone-strip. The single knob to retune the whole wall's look:
/// raising it (→1.3+) grows scroll onset below the ~30-player show norm;
/// lowering it (→1.0) reads square.
///
/// NOTE (accepted cost, deliberate): a fixed shape means the grid can no
/// longer stretch tile HEIGHT to squeeze every row onto one screen. Big
/// fields scroll — e.g. 1080p shows 4 of 12 rows at 100 players. Shape
/// beats see-everyone; that trade was chosen explicitly.
const double _tileAspect = 1.2;

/// Width floor for a scoreboard tile: the name-legibility budget (200 −
/// 32 card padding − ~52 writing badge − 8 gap ≈ 108 px name box keeps
/// 20 pt names at worst ~0.85 FittedBox scale — a mild, imperceptible
/// shrink; the old 220 floor bought "never scaled" at the cost of a whole
/// column and a 30-player scroll). Anything narrower turns names into
/// confetti.
const double _minTileWidth = 200;

/// Height floor, DERIVED from the shape: a tile at the width floor with
/// the [tileAspect] shape. (Supersedes the wide-slab-era fixed 90 — that
/// floor existed because heights used to shrink independently of widths;
/// with a fixed shape they never do.) Exposed as a constant only so tests
/// and docs quote the same number the packing uses.
const double _minTileHeight = _minTileWidth * _tileAspect;

/// Safety ceiling on columns. The BINDING limit is the width floor's
/// derate (⌊(width+spacing)/(min+spacing)⌋ — 9 columns on a 1920 wall at
/// the 200 floor); this cap only matters on very large walls (3+ K), where
/// 12 keeps tiles from re-entering slab territory. (Was 8 — a wide-slab
/// artifact that would have throttled the 9th portrait column on 1080p.)
const int _maxColumns = 12;

/// How a grid of [playerCount] tiles fills a content area of [width] ×
/// [height] (already EXCLUDING the grid padding, but INCLUSIVE of tile
/// [spacing]).
///
/// Returns the column count, the GridView `childAspectRatio`, and whether
/// the grid must scroll.
///
/// ASPECT-DRIVEN MAX-TILE PACKING (2026-09-10 design; supersedes the
/// exact-fill packing that stretched/shrunk tile heights to make rows fit):
///
///  - Tiles keep the [_tileAspect] shape at every count. Column count is
///    the FEWEST columns whose aspect-shaped rows fit the height — tile
///    size shrinks as columns grow, so the first fitting count is the
///    LARGEST-tile fit. `ceil(n/columns)` rows × (cellWidth·aspect) may
///    leave bottom leftover height, and the last row may have empty slots:
///    both are preferred over distorting the tile shape.
///  - When NO column count (up to the width-floor derate) fits the height,
///    packing HOLDS THE FLOOR: full width at the derated maximum columns
///    (cellWidth ≥ [_minTileWidth], cellHeight = cellWidth·aspect ≥
///    [_minTileHeight]) and `scrolls` reports that the GridView scrolls.
///  - Single player stays fullscreen (the detail view; minimums are for
///    the wall).
///
/// Kept pure for unit tests — call it from a LayoutBuilder with measured
/// values (see [PlayerTileGrid]).
({int columns, double childAspectRatio, bool scrolls}) showPlayerGridLayout({
  required int playerCount,
  required double width,
  required double height,
  double spacing = 12,
}) {
  // Degenerate inputs: a single centered tile beats a layout crash.
  if (playerCount <= 0 || width <= 0 || height <= 0) {
    return (columns: 1, childAspectRatio: 1, scrolls: false);
  }
  if (playerCount == 1) {
    // A single player IS the detail view — fullscreen by design; the
    // minimums and the shape exist for the scoreboard wall, not for it.
    return (columns: 1, childAspectRatio: width / height, scrolls: false);
  }

  // Width floor's derate: the most columns that keep tiles ≥
  // [_minTileWidth] while filling the width, plus the safety ceiling.
  final maxColumns =
      ((width + spacing) / (_minTileWidth + spacing)).floor().clamp(
            1,
            _maxColumns,
          );

  // Max-tile search: tile size shrinks monotonically with the column
  // count (aspect fixes height to width), so the fewest columns whose
  // rows fit the height is the largest-tile fit.
  for (var columns = 1; columns <= maxColumns; columns++) {
    final cellWidth = (width - (columns - 1) * spacing) / columns;
    final cellHeight = cellWidth * _tileAspect;
    final rows = (playerCount / columns).ceil();
    final gridHeight = rows * cellHeight + (rows - 1) * spacing;
    if (gridHeight <= height + 0.01) {
      return (
        columns: columns,
        childAspectRatio: cellWidth / cellHeight, // == 1 / _tileAspect
        scrolls: false,
      );
    }
  }

  // No column count keeps the shape and fits the height: hold the floor.
  // Full width at the derated maximum columns — cells stay ≥ the minimums
  // by construction — and the GridView scrolls.
  final columns = maxColumns;
  final cellWidth = (width - (columns - 1) * spacing) / columns;
  return (
    columns: columns,
    childAspectRatio: cellWidth / (cellWidth * _tileAspect),
    scrolls: true,
  );
}

/// The /show scoreboard: an aspect-shaped grid of per-challenger tiles
/// (see [showPlayerGridLayout] for the maths).
///
/// Tiles keep a mild portrait shape (height/width 1.2) at every count.
/// When the packing reports `scrolls` (tiles at the 200-wide floor no
/// longer tile the viewport — 37+ players on a full-width 1080p wall),
/// this GridView simply scrolls: it always fills its parent box already,
/// so no structural change is needed, and tiles keep their shape and
/// minimum instead of shrinking into unseeable slivers. Below that,
/// bigger fields simply leave bottom/leftover space rather than distort.
///
/// Taint-free shell in the PaneTabShell style (I-117/I-022): tiles are
/// built by the CALLER and passed in, so the tainted /show screen builds
/// its real [tiles] while this shell runs under `flutter test` — 100 tiles
/// can be proven to lay out at the minimum size and scroll, with no room
/// imports here.
class PlayerTileGrid extends StatelessWidget {
  const PlayerTileGrid({
    super.key,
    required this.tiles,
    this.padding = const EdgeInsets.all(12),
    this.spacing = 12,
  });

  /// One widget per challenger, in scoreboard order.
  final List<Widget> tiles;

  /// Grid padding, removed from the area before packing.
  final EdgeInsetsGeometry padding;

  /// Gap between tiles, kept inside the solved tile size.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for players…',
          style: TextStyle(color: Colors.white38, fontSize: 28),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = padding.resolve(Directionality.of(context));
        final layout = showPlayerGridLayout(
          playerCount: tiles.length,
          width: math.max(0, constraints.maxWidth - pad.horizontal),
          height: math.max(0, constraints.maxHeight - pad.vertical),
          spacing: spacing,
        );
        return GridView.count(
          crossAxisCount: layout.columns,
          childAspectRatio: layout.childAspectRatio,
          padding: padding,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: tiles,
        );
      },
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// /show scoreboard layout maths, carved out of `show_screen.dart`
/// (SHADOW-003/I-096: that file is inside the W-012 tainted cone and cannot
/// run under `flutter test`; this file imports ONLY material and takes
/// plain values). Pure function + taint-free shell widget.

/// Target width/height for a scoreboard tile at large player counts. The
/// packing below lands close to it: wide enough to read a name, tall
/// enough for a glimpse of the content.
const double _targetTileAspect = 1.4;

/// Ceiling on columns so extreme counts still produce readable tiles; the
/// exact-tiling aspect keeps the grid fitting (no scrolling) up to
/// [_maxColumns] * [_maxColumns] tiles.
const int _maxColumns = 8;

/// Minimum scoreboard tile size (2026-09-10, measured on the 1920×1080
/// projector capture at 100 players — 227×70 tiles):
///
///  - Height 90 = the ~46 px name header (20 pt line + vertical padding)
///    plus ~44 px of content, enough to render the "Thinking in the
///    dark…" placeholder or one prompt line unclipped. Below the header
///    crowds out the content entirely.
///  - Width 220 = the name box (220 − 32 card padding − ~52 writing badge
///    − 8 gap ≈ 128 px) keeps ≤ ~11-character names UNSCALED at the 20 pt
///    ceiling; narrower tiles push the FittedBox (which has no floor)
///    toward single-digit, unreadable text.
///
/// When even the minimum no longer tiles the viewport, [PlayerTileGrid]
/// holds the minimum and the GridView SCROLLS (e.g. a full-width 1080p
/// wall fits 10 rows of 90 px rooms → scrolling starts at 81 players).
const double _minTileWidth = 220;
const double _minTileHeight = 90;

/// How a grid of [playerCount] tiles fills a content area of [width] ×
/// [height] (already EXCLUDING the grid padding, but INCLUSIVE of tile
/// [spacing]).
///
/// Returns the column count, the GridView `childAspectRatio`, and whether
/// the grid must scroll:
///
///  - Small fields: `ceil(playerCount / columns)` rows tile the area
///    EXACTLY at the sqrt-estimate columns (no scroll, no overflow) —
///    byte-for-byte the algorithm this replaced, so ≤threshold layouts
///    are pixel-identical.
///  - When exact-fill would shrink a tile below [_minTileWidth] or
///    [_minTileHeight], the packing stops shrinking instead: columns are
///    reduced to the width minimum, cell height is floored at
///    [_minTileHeight], and `scrolls` reports that the GridView must
///    scroll (rows × (min + spacing) now exceed the viewport).
///
/// The old fixed-switch layout picked 4 columns for any count > 9, so
/// ~30 players produced 8 rows that scrolled off the projector (cells
/// sized from the full-height aspect).
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
  final viewportAspect = width / height;
  if (playerCount == 1) {
    // A single player IS the detail view — fullscreen by design; the
    // minimums exist for the scoreboard wall, not for it.
    return (columns: 1, childAspectRatio: viewportAspect, scrolls: false);
  }

  // columns ≈ sqrt(n · viewportAspect / targetAspect): the classic
  // even-packing estimate — it reproduces the old choice for the small
  // square-ish counts (1→1, 2→2, 4→2, 9→3) and grows with the count
  // instead of capping at 4.
  final candidate = math
      .sqrt(playerCount * viewportAspect / _targetTileAspect)
      .round()
      .clamp(1, _maxColumns);

  final rows = (playerCount / candidate).ceil();

  // Solve aspect so cellWidth/cellHeight makes rows·cellHeight == height
  // exactly (spacing both between tiles and inside the solved size):
  final exactCellWidth = (width - (candidate - 1) * spacing) / candidate;
  final exactCellHeight = (height - (rows - 1) * spacing) / rows;

  // PASS 1 — everything fits at the legacy exact-fill packing: return it
  // untouched, so small/medium fields render pixel-identical to before.
  if (exactCellWidth >= _minTileWidth && exactCellHeight >= _minTileHeight) {
    return (
      columns: candidate,
      childAspectRatio: exactCellWidth / exactCellHeight,
      scrolls: false,
    );
  }

  // PASS 2 — the minimums bind: stop shrinking. Columns yield to the
  // width minimum first (wider tiles), and the cell height is floored so
  // the header + one content line always render; the grid scrolls.
  final byWidth = ((width + spacing) / (_minTileWidth + spacing))
      .floor()
      .clamp(1, _maxColumns);
  final columns = math.min(candidate, byWidth);
  final scrollRows = (playerCount / columns).ceil();
  final cellWidth = (width - (columns - 1) * spacing) / columns;
  final cellHeight = math.max(
    _minTileHeight,
    (height - (scrollRows - 1) * spacing) / scrollRows,
  );
  final gridHeight = scrollRows * cellHeight + (scrollRows - 1) * spacing;
  return (
    columns: columns,
    childAspectRatio: cellWidth / cellHeight,
    scrolls: gridHeight > height + 0.01,
  );
}

/// The /show scoreboard: an exact-tiling grid of per-challenger tiles
/// (see [showPlayerGridLayout] for the maths).
///
/// When the packing reports `scrolls` (tiles floored at the minimum size —
/// 220×90 — no longer tile the viewport, empirically 81+ players on a
/// full-width 1080p wall), this GridView simply scrolls: it always fills
/// its parent box already, so no structural change is needed, and the
/// tiles keep the readable minimum instead of shrinking into
/// name-commands-nothing strips.
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

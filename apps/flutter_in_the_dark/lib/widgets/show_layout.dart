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

/// How a grid of [playerCount] tiles fills a content area of [width] ×
/// [height] (already EXCLUDING the grid padding, but INCLUSIVE of tile
/// [spacing]):
///
/// Returns the column count and the GridView `childAspectRatio` that make
/// `ceil(playerCount / columns)` rows tile the area EXACTLY — no scroll,
/// no overflow, at any viewport shape. The old fixed-switch layout picked
/// 4 columns for any count > 9, so ~30 players produced 8 rows that
/// scrolled off the projector (cells sized from the full-height aspect).
///
/// Kept pure for unit tests — call it from a LayoutBuilder with measured
/// values (see [PlayerTileGrid]).
({int columns, double childAspectRatio}) showPlayerGridLayout({
  required int playerCount,
  required double width,
  required double height,
  double spacing = 12,
}) {
  // Degenerate inputs: a single centered tile beats a layout crash.
  if (playerCount <= 0 || width <= 0 || height <= 0) {
    return (columns: 1, childAspectRatio: 1);
  }
  final viewportAspect = width / height;
  if (playerCount == 1) {
    return (columns: 1, childAspectRatio: viewportAspect);
  }

  // columns ≈ sqrt(n · viewportAspect / targetAspect): the classic
  // even-packing estimate — it reproduces the old choice for the small
  // square-ish counts (1→1, 2→2, 4→2, 9→3) and grows with the count
  // instead of capping at 4.
  final columns =
      math.sqrt(playerCount * viewportAspect / _targetTileAspect)
          .round()
          .clamp(1, _maxColumns);

  final rows = (playerCount / columns).ceil();

  // Solve aspect so cellWidth/cellHeight makes rows·cellHeight == height
  // exactly (spacing both between tiles and inside the solved size):
  final cellWidth = (width - (columns - 1) * spacing) / columns;
  final cellHeight = (height - (rows - 1) * spacing) / rows;
  return (columns: columns, childAspectRatio: cellWidth / cellHeight);
}

/// The /show scoreboard: an exact-tiling grid of per-challenger tiles
/// (see [showPlayerGridLayout] for the maths).
///
/// Taint-free shell in the PaneTabShell style (I-117/I-022): tiles are
/// built by the CALLER and passed in, so the tainted /show screen builds
/// its real [tiles] while this shell runs under `flutter test` — 30 tiles
/// can be proven to lay out without overflow, with no room imports here.
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
        final (:columns, :childAspectRatio) = showPlayerGridLayout(
          playerCount: tiles.length,
          width: math.max(0, constraints.maxWidth - pad.horizontal),
          height: math.max(0, constraints.maxHeight - pad.vertical),
          spacing: spacing,
        );
        return GridView.count(
          crossAxisCount: columns,
          childAspectRatio: childAspectRatio,
          padding: padding,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: tiles,
        );
      },
    );
  }
}

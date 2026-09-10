import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/show_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The /show scoreboard packing ([showPlayerGridLayout]) and its taint-free
/// shell ([PlayerTileGrid]).
///
/// Two eras are pinned here:
///  - ≤ minimum-size fields keep the legacy exact-fill packing — the
///    [_legacyPacking] golden asserts the packing is byte-identical to the
///    merged 30-player algorithm (no scroll, unchanged look).
///  - Past the minimum (220×90, the measured legibility floor: ~46 px name
///    header + one content line tall; ~11-char names unscaled wide) tiles
///    STOP shrinking and the grid scrolls — the 100-player capture had
///    227×70 strips that could not even render a loader without bleeding
///    across neighbouring tiles.
void main() {
  // 16:9 projector, minus the timer-pill margin one can tolerate.
  const projector = Size(1920, 1056);
  const spacing = 12.0;

  ({
    int columns,
    double childAspectRatio,
    bool scrolls,
  }) layout({
    required int playerCount,
    required double width,
    required double height,
  }) {
    return showPlayerGridLayout(
      playerCount: playerCount,
      width: width,
      height: height,
    );
  }

  ({int columns, int rows, double tileWidth, double tileHeight, bool scrolls})
      layoutFor(int count, Size area) {
    final (:columns, :childAspectRatio, :scrolls) = layout(
      playerCount: count,
      width: area.width,
      height: area.height,
    );
    final rows = (count / columns).ceil();
    final tileWidth = (area.width - (columns - 1) * spacing) / columns;
    final tileHeight = tileWidth / childAspectRatio;
    return (
      columns: columns,
      rows: rows,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      scrolls: scrolls,
    );
  }

  /// The algorithm exactly as merged in the 30-player fix — preserved to
  /// prove the min-size change is pixel-identical whenever the exact-fill
  /// tiles already satisfy the 220×90 minimum.
  ({int columns, double childAspectRatio}) legacyPacking(
    int playerCount,
    double width,
    double height,
  ) {
    final viewportAspect = width / height;
    final columns =
        math.sqrt(playerCount * viewportAspect / 1.4).round().clamp(1, 8);
    final rows = (playerCount / columns).ceil();
    final cellWidth = (width - (columns - 1) * spacing) / columns;
    final cellHeight = (height - (rows - 1) * spacing) / rows;
    return (columns: columns, childAspectRatio: cellWidth / cellHeight);
  }

  group('column choice', () {
    test('reproduces the old small-count choices', () {
      expect(
        layout(
          playerCount: 1,
          width: projector.width,
          height: projector.height,
        ).columns,
        1,
      );
      expect(
        layout(
          playerCount: 2,
          width: projector.width,
          height: projector.height,
        ).columns,
        2,
      );
      expect(
        layout(
          playerCount: 4,
          width: projector.width,
          height: projector.height,
        ).columns,
        2,
      );
      expect(
        layout(
          playerCount: 9,
          width: projector.width,
          height: projector.height,
        ).columns,
        3,
      );
    });

    test('grows past the old 4-column cap (~30 players → 6×5)', () {
      final layout30 = layout(
        playerCount: 30,
        width: projector.width,
        height: projector.height,
      );
      expect(layout30.columns, 6);
      expect((30 / layout30.columns).ceil(), 5);
      expect(layout30.childAspectRatio, greaterThan(0));
    });

    test('clamps to a sane column ceiling', () {
      final layout300 = layout(
        playerCount: 300,
        width: projector.width,
        height: projector.height,
      );
      expect(layout300.columns, lessThanOrEqualTo(8));
    });
  });

  group('≤ threshold is pixel-identical to the merged exact-fill packing', () {
    // Counts/scopes that comfortably satisfy the 220×90 minimum.
    final shapes = {
      'projector 16:9': const Size(1920, 1056),
      'laptop 16:10': const Size(1440, 855),
    };
    final goldenCounts = {
      'projector 16:9': [
        2, 3, 5, 8, 12, 16, 24, 30, 40,
        // 40 on laptop 16:10 gives 195px tiles (< the 220 width floor) —
        // the NEW code legitimately derates there, so it's not a golden.
      ],
      'laptop 16:10': [2, 3, 5, 8, 12, 16, 24, 30],
    };
    for (final entry in shapes.entries) {
      for (final count in goldenCounts[entry.key]!) {
        test('${entry.key} × $count matches the legacy packing', () {
          final (:columns, :childAspectRatio, :scrolls) = layout(
            playerCount: count,
            width: entry.value.width,
            height: entry.value.height,
          );
          final legacy = legacyPacking(
            count,
            entry.value.width,
            entry.value.height,
          );
          expect(columns, legacy.columns, reason: '${entry.key} × $count');
          expect(
            childAspectRatio,
            closeTo(legacy.childAspectRatio, 1e-9),
            reason: '${entry.key} × $count',
          );
          expect(scrolls, isFalse, reason: '${entry.key} × $count');
        });
      }
    }
  });

  group('minimum tile size + scroll', () {
    test('48 players: exact-fill survives (no scroll, 8×6)', () {
      final l = layoutFor(48, projector);
      expect(l.scrolls, isFalse);
      expect(l.columns, 8);
      expect(l.rows, 6);
      expect(l.tileHeight, greaterThanOrEqualTo(90));
    });

    test('64 players: exact-fill survives (no scroll)', () {
      final l = layoutFor(64, projector);
      expect(l.scrolls, isFalse);
      expect(l.tileHeight, greaterThanOrEqualTo(90));
    });

    test('80 players: last exact-fill count (tile height 94.8 ≥ 90)', () {
      final l = layoutFor(80, projector);
      expect(l.scrolls, isFalse);
      expect(l.tileHeight, closeTo(94.8, 0.5));
    });

    test('81 players: THE scroll threshold on 1080p', () {
      final l = layoutFor(81, projector);
      expect(l.scrolls, isTrue, reason: '11 rows × 90 px + spacing > 1056');
      expect(
        l.tileHeight,
        closeTo(90, 0.01),
        reason: 'tiles hold the minimum instead of shrinking',
      );
      expect(l.columns, 8);
    });

    test('100 players: 8×13 at the 227×90 minimum, grid scrolls', () {
      final l = layoutFor(100, projector);
      expect(l.scrolls, isTrue);
      expect(l.columns, 8);
      expect(l.rows, 13);
      expect(
        l.tileWidth,
        closeTo(229.5, 0.01),
        reason: '(1920 − 7·12)/8 — the caller passed the CONTENT area',
      );
      expect(l.tileHeight, closeTo(90, 0.01));
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(
        gridHeight,
        greaterThan(projector.height),
        reason: 'why the grid must scroll',
      );
    });

    test('150 players: still at the minimum, ~2.4 viewports tall', () {
      final l = layoutFor(150, projector);
      expect(l.scrolls, isTrue);
      expect(l.tileHeight, closeTo(90, 0.01));
      expect(l.rows, 19);
    });

    test('portrait: the width minimum forces fewer columns', () {
      // 500×1400: the sqrt estimate wants 3 columns of ~155 px — narrower
      // than the width floor — so the width minimum derates to 2 columns.
      final l = layoutFor(30, const Size(500, 1400));
      expect(l.columns, 2);
      expect(l.tileWidth, greaterThanOrEqualTo(220));
      expect(l.tileHeight, greaterThanOrEqualTo(90));
    });

    test('the width floor never excludes the chosen columns', () {
      // At any size, the emitted columns must keep tiles ≥ min width.
      for (final count in [12, 45, 100, 200]) {
        final l = layoutFor(count, const Size(900, 700));
        expect(
          l.tileWidth,
          greaterThanOrEqualTo(220),
          reason: '$count players on 900×700',
        );
        expect(
          l.tileHeight,
          greaterThanOrEqualTo(90),
          reason: '$count players on 900×700',
        );
      }
    });
  });

  group('degenerate inputs do not crash', () {
    test('zero and negative inputs yield a safe single tile', () {
      expect(
        showPlayerGridLayout(
          playerCount: 0,
          width: projector.width,
          height: projector.height,
        ),
        (columns: 1, childAspectRatio: 1, scrolls: false),
      );
      expect(
        showPlayerGridLayout(
          playerCount: 4,
          width: 0,
          height: projector.height,
        ),
        (columns: 1, childAspectRatio: 1, scrolls: false),
      );
      expect(
        showPlayerGridLayout(
          playerCount: 4,
          width: projector.width,
          height: -5,
        ),
        (columns: 1, childAspectRatio: 1, scrolls: false),
      );
    });

    test('single player fills the whole area and never scrolls', () {
      final l = layout(
        playerCount: 1,
        width: projector.width,
        height: projector.height,
      );
      expect(l.columns, 1);
      expect(l.scrolls, isFalse);
      expect(
        l.childAspectRatio,
        closeTo(projector.width / projector.height, 1e-9),
      );
    });
  });

  group('PlayerTileGrid (real widget)', () {
    Future<void> pumpTiles(WidgetTester tester, int count) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerTileGrid(
              tiles: [
                for (var i = 0; i < count; i++)
                  ColoredBox(
                    color: Color(0xFF000000 + (i % 0xFF)),
                    child: Text('Player $i'),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('30 tiles fill the viewport with no overflow or scroll', (
      tester,
    ) async {
      await pumpTiles(tester, 30);
      expect(tester.takeException(), isNull);
      expect(find.text('Player 0'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      // GridView's scroll physics with a fitting layout: no scroll range.
      expect(scrollable.position.maxScrollExtent, lessThanOrEqualTo(0.01));
    });

    testWidgets('100 tiles hold the 227×90 minimum and scroll', (tester) async {
      await pumpTiles(tester, 100);
      expect(tester.takeException(), isNull);
      expect(find.text('Player 0'), findsOneWidget);
      expect(
        find.text('Player 99'),
        findsNothing,
        reason: 'last tiles live below the fold before scrolling',
      );

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(
        scrollable.position.maxScrollExtent,
        greaterThan(0),
        reason: 'the wall must scroll at 100 players',
      );

      // First tile: floored at the minimum (227-ish × 90) instead of the
      // old 227×70 strip. (Scoped to the grid: the scaffold's Material
      // background is itself a full-viewport ColoredBox.)
      final firstTile = tester.getSize(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(
        firstTile.height,
        closeTo(90, 0.5),
        reason: 'tile holds the minimum height',
      );
      expect(firstTile.width, closeTo(226.5, 0.5));

      // The scroll actually reveals the tail of the scoreboard.
      await tester.scrollUntilVisible(
        find.text('Player 99'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Player 99'), findsOneWidget);
    });

    testWidgets('empty grid shows the waiting placeholder', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlayerTileGrid(tiles: [])),
        ),
      );
      expect(find.text('Waiting for players…'), findsOneWidget);
    });
  });
}

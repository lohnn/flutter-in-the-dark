import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/show_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The /show scoreboard packing ([showPlayerGridLayout]) and its taint-free
/// shell ([PlayerTileGrid]).
///
/// DESIGN (2026-09-10, supersedes the merged exact-fill packing): tiles
/// keep a FIXED mild-portrait shape — height/width 1.2 — at every count,
/// and the packing maximises tile size: the fewest columns whose
/// aspect-shaped rows fit the height wins; bottom leftover (and empty
/// slots in the last row) are preferred over distorting the shape. When
/// NO column count keeps the shape and fits, tiles hold the 200-wide
/// floor (height derives from the aspect: 240) and the grid SCROLLS.
///
/// The user deliberately changed the design this session, so the old
/// "byte-identical to the merged exact-fill goldens" pins are GONE —
/// re-derived below as literals for the new aspect packing (30 players
/// and up scroll differently than the merged design; that is the point).
///
/// Test convention: the pure function receives the CONTENT box (grid
/// padding excluded). A 1920×1080 projector minus the grid's 12 px
/// padding is 1896×1056 — that (not the raw panel) is what /show really
/// lays out, and it is where the width floor bites EXACTLY (9 columns ×
/// 200.0 px). Onset arithmetic below uses the same convention.
void main() {
  // 16:9 projector content box: 1920×1080 minus the grid padding.
  const projector = Size(1896, 1056);
  // 16:10 laptop content box: 1440×855 minus the grid padding.
  const laptop = Size(1416, 831);
  const spacing = 12.0;
  const aspect = 1.2; // height/width — the single shape knob

  ({
    int columns,
    int rows,
    double tileWidth,
    double tileHeight,
    bool scrolls,
  })
  layoutFor(int count, Size area) {
    final layout = showPlayerGridLayout(
      playerCount: count,
      width: area.width,
      height: area.height,
    );
    final tileWidth = (area.width - (layout.columns - 1) * spacing) /
        layout.columns;
    return (
      columns: layout.columns,
      rows: (count / layout.columns).ceil(),
      tileWidth: tileWidth,
      // childAspectRatio is width/height; invert it for tile height.
      tileHeight: tileWidth / layout.childAspectRatio,
      scrolls: layout.scrolls,
    );
  }

  /// The shape/leftover invariants EVERY non-degenerate layout must hold:
  /// fixed aspect, width floor, and `scrolls` telling the truth about the
  /// grid height vs the viewport.
  void expectInvariants(int count, Size area, {int? expectedColumns}) {
    final l = showPlayerGridLayout(
      playerCount: count,
      width: area.width,
      height: area.height,
    );
    final tileWidth = (area.width - (l.columns - 1) * spacing) / l.columns;
    final tileHeight = tileWidth / l.childAspectRatio;
    final rows = (count / l.columns).ceil();
    final gridHeight = rows * tileHeight + (rows - 1) * spacing;
    expect(
      tileHeight / tileWidth,
      closeTo(aspect, 1e-9),
      reason: '$count×${area.width}×${area.height}: fixed tile aspect',
    );
    expect(
      tileWidth,
      greaterThanOrEqualTo(200 - 1e-6),
      reason: '$count×${area.width}×${area.height}: width floor',
    );
    expect(
      tileHeight,
      greaterThanOrEqualTo(200 * aspect - 1e-6),
      reason: '$count×${area.width}×${area.height}: derived height floor',
    );
    if (l.scrolls) {
      expect(
        gridHeight,
        greaterThan(area.height + 0.01),
        reason: '$count×${area.width}×${area.height}: scrolls ⇒ overflows',
      );
    } else {
      expect(
        gridHeight,
        lessThanOrEqualTo(area.height + 0.01),
        reason: '$count×${area.width}×${area.height}: no scroll ⇒ fits',
      );
    }
    if (expectedColumns != null) {
      expect(l.columns, expectedColumns, reason: '$count columns');
    }
  }

  group('column choice — max-tile packing at the 1.2 aspect', () {
    test('matches the hand-derived literals (projector content box)', () {
      // Each entry is the fewest columns whose aspect-shaped rows fit
      // 1896×1056; smaller counts give bigger tiles so the scan ascends.
      const expectations = {
        2: 3, // 2×624×748.8 + one empty slot (2 cols would not fit height)
        3: 3, // 3×624×748.8, one exact row
        4: 4, // 465×558
        5: 5, // 369.6×443.5
        8: 5, // 5 cols × 2 rows, 2 empty slots, 157 px leftover
        9: 5, // 5 cols × 2 rows, 3 empty slots
        10: 5, // 5×2, exactly full rows, 157 px leftover
        12: 6, // 304×364.8 — 5 cols would need a 3rd row
        16: 7, // 258.9×310.6
        21: 7, // 7×3, exactly full rows
        24: 8, // 226.5×271.8 — 9 cols would shrink tiles pointlessly
        27: 9, // 200×240 — floor lands exactly (derate = 9 at 1896)
        30: 9, // 9×4, 60 px leftover
      };
      expectations.forEach((count, columns) {
        expectInvariants(count, projector, expectedColumns: columns);
      });
    });

    test('single player stays fullscreen; degenerates stay safe', () {
      final single = showPlayerGridLayout(
        playerCount: 1,
        width: projector.width,
        height: projector.height,
      );
      expect(single.columns, 1);
      expect(single.childAspectRatio, closeTo(projector.width / projector.height, 1e-9));
      expect(single.scrolls, isFalse);

      const degenerate = (
        columns: 1,
        childAspectRatio: 1.0,
        scrolls: false,
      );
      expect(
        showPlayerGridLayout(playerCount: 0, width: 100, height: 100),
        degenerate,
      );
      expect(
        showPlayerGridLayout(playerCount: 5, width: 0, height: 1056),
        degenerate,
      );
      expect(
        showPlayerGridLayout(playerCount: 5, width: 1896, height: -5),
        degenerate,
      );
    });

    test('width floor derates the column count on narrow walls', () {
      // 500 wide: only ⌊(500+12)/(200+12)⌋ = 2 columns keep 200-px tiles.
      for (final count in [5, 30]) {
        final l = showPlayerGridLayout(
          playerCount: count,
          width: 500,
          height: 1400,
        );
        expect(l.columns, 2, reason: '500-wide wall, $count players');
        expectInvariants(count, const Size(500, 1400), expectedColumns: 2);
      }
      // Even a 360-wide phone-shaped wall lays out without crashing; one
      // column of full-width portrait tiles, scrolling for any real count.
      final phone = showPlayerGridLayout(
        playerCount: 5,
        width: 360,
        height: 700,
      );
      expect(phone.columns, 1);
      expect(phone.scrolls, isTrue);
      expectInvariants(5, const Size(360, 700), expectedColumns: 1);
    });
  });

  group('small fields — shaped tiles, no scroll, leftover beats distortion', () {
    test('4 players: 4 portrait tiles in a single row, 486 px leftover', () {
      final l = layoutFor(4, projector);
      expect(l.scrolls, isFalse);
      expect(l.columns, 4);
      expect(l.rows, 1);
      expect(l.tileWidth, closeTo(465, 0.01));
      expect(l.tileHeight, closeTo(558, 0.01));
    });

    test('12 players: 6×2 grid, 310 px bottom leftover', () {
      final l = layoutFor(12, projector);
      expect(l.scrolls, isFalse);
      expect(l.columns, 6);
      expect(l.rows, 2);
      expect(l.tileWidth, closeTo(306, 0.01));
      expect(l.tileHeight, closeTo(367.2, 0.01));
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(gridHeight, lessThanOrEqualTo(projector.height + 0.01));
    });

    test('30 players: 9×4, tiles at 200×240, one screen, no scroll', () {
      final l = layoutFor(30, projector);
      expect(l.scrolls, isFalse);
      expect(l.columns, 9);
      expect(l.rows, 4);
      expect(l.tileWidth, closeTo(200, 0.01));
      expect(l.tileHeight, closeTo(240, 0.01));
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(gridHeight, closeTo(996, 0.01)); // 1056 − 60 leftover
    });

    test('laptop 16:10 holds the same shape: 12 players on 6×2', () {
      final l = layoutFor(12, laptop);
      expect(l.scrolls, isFalse);
      expect(l.columns, 6);
      expect(l.tileWidth, closeTo(226, 0.01));
      expect(l.tileHeight, closeTo(271.2, 0.01));
    });
  });

  group('scroll onset — tiles hold 200×240, the wall scrolls', () {
    test('projector 1080p: 36 players still fit (9×4), 37 scrolls', () {
      final at36 = layoutFor(36, projector);
      expect(at36.scrolls, isFalse, reason: '9×4 × 240 + spacing = 996');
      expect(at36.rows, 4);
      expect(at36.tileHeight, closeTo(240, 0.01));

      final at37 = layoutFor(37, projector);
      expect(at37.scrolls, isTrue, reason: '5 rows × 240 + spacing = 1248');
      expect(at37.columns, 9, reason: 'floor mode at the derate maximum');
      expect(at37.tileWidth, closeTo(200, 0.01));
      expect(at37.tileHeight, closeTo(240, 0.01));
    });

    test('floor mode always scrolls (it only runs when nothing fits)', () {
      for (final count in [37, 60, 81, 100, 150]) {
        final layout = showPlayerGridLayout(
          playerCount: count,
          width: projector.width,
          height: projector.height,
        );
        expect(layout.scrolls, isTrue, reason: '$count players');
      }
    });

    test('60 players: 9 cols × 7 rows of 200×240, ~1.7 viewports', () {
      final l = layoutFor(60, projector);
      expect(l.scrolls, isTrue);
      expect(l.columns, 9);
      expect(l.rows, 7);
      expect(l.tileHeight, closeTo(240, 0.01));
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(gridHeight, closeTo(1752, 0.01));
    });

    test('81 players: 9 rows, 2.2 viewports (was no-scroll in the old design)', () {
      final l = layoutFor(81, projector);
      expect(l.scrolls, isTrue);
      expect(l.rows, 9);
      expect(l.tileWidth, closeTo(200, 0.01));
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(gridHeight, closeTo(2256, 0.01));
    });

    test('100 players: 12 rows of 200×240, 4 rows visible per screen', () {
      final l = layoutFor(100, projector);
      expect(l.scrolls, isTrue);
      expect(l.columns, 9);
      expect(l.rows, 12);
      final gridHeight = l.tileHeight * l.rows + (l.rows - 1) * spacing;
      expect(gridHeight, closeTo(3012, 0.01));
      final visibleRows = (projector.height + spacing) / (240 + spacing);
      expect(visibleRows, closeTo(4.24, 0.05));
    });

    test('150 players: 17 rows, still at the floor', () {
      final l = layoutFor(150, projector);
      expect(l.scrolls, isTrue);
      expect(l.columns, 9);
      expect(l.rows, 17);
      expect(l.tileHeight, closeTo(240, 0.01));
    });

    test('laptop 16:10 onset: 12 players fit, the 13th scrolls', () {
      final at12 = layoutFor(12, laptop);
      expect(at12.scrolls, isFalse);
      final at13 = layoutFor(13, laptop);
      expect(at13.scrolls, isTrue, reason: '13/6 → 3 rows overshoot 831');
      expect(at13.columns, 6);
      expect(at13.tileWidth, closeTo(226, 0.01));
      expect(at13.tileHeight, closeTo(271.2, 0.01));
    });
  });

  group('invariants hold across shapes and counts', () {
    test('aspect, floors and scroll truth at 200+ counts on odd shapes', () {
      const shapes = [
        Size(1896, 1056), // projector content
        Size(1416, 831), // laptop content
        Size(900, 700), // square-ish
        Size(500, 1400), // portrait
        Size(1896, 320), // extreme short wall
      ];
      for (final shape in shapes) {
        for (final count in [2, 5, 12, 30, 60, 81, 100, 150]) {
          expectInvariants(count, shape);
        }
      }
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

    testWidgets('24 tiles fill one screen (9th column unused), no scroll', (
      tester,
    ) async {
      await pumpTiles(tester, 24);
      expect(tester.takeException(), isNull);
      expect(find.text('Player 0'), findsOneWidget);
      expect(find.text('Player 23'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, lessThanOrEqualTo(0.01));

      // 8 columns of 226.5×271.8 shaped tiles (the largest fit at 24).
      final firstTile = tester.getSize(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(firstTile.width, closeTo(226.5, 0.5));
      expect(firstTile.height, closeTo(271.8, 0.5));
    });

    testWidgets('30 tiles: 9×4 at the exact 200×240 floor, no scroll', (
      tester,
    ) async {
      await pumpTiles(tester, 30);
      expect(tester.takeException(), isNull);
      expect(find.text('Player 29'), findsOneWidget);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, lessThanOrEqualTo(0.01));
      final firstTile = tester.getSize(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(firstTile.width, closeTo(200, 0.5));
      expect(firstTile.height, closeTo(240, 0.5));
    });

    testWidgets('100 tiles hold 200×240 and scroll to the tail', (tester) async {
      await pumpTiles(tester, 100);
      expect(tester.takeException(), isNull);
      expect(find.text('Player 0'), findsOneWidget);
      expect(
        find.text('Player 99'),
        findsNothing,
        reason: 'the tail lives below the fold (12 rows on one screen)',
      );

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(
        scrollable.position.maxScrollExtent,
        greaterThan(0),
        reason: 'the wall must scroll at 100 players',
      );

      final firstTile = tester.getSize(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(firstTile.width, closeTo(200, 0.5));
      expect(firstTile.height, closeTo(240, 0.5));

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
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Waiting for players…'), findsOneWidget);
    });
  });
}

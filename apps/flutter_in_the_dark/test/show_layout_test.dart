import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/show_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// The /show scoreboard packing ([showPlayerGridLayout]) and its taint-free
/// shell ([PlayerTileGrid]).
///
/// The bug this pins: the old fixed `columns = switch (count) { … _ => 4 }`
/// with `childAspectRatio = maxWidth / maxHeight` gave ~30 players 8 rows of
/// full-height cells — double the viewport — so the projector had to scroll
/// (nobody can). The packing must tile the viewport exactly for every
/// count, at any viewport shape.
void main() {
  // 16:9 projector, minus the timer-pill margin one can tolerate.
  const projector = Size(1920, 1056);
  const spacing = 12.0;

  ({int rows, double tileWidth, double tileHeight}) layoutFor(
    int count,
    Size area,
  ) {
    final (:columns, :childAspectRatio) = showPlayerGridLayout(
      playerCount: count,
      width: area.width,
      height: area.height,
    );
    final rows = (count / columns).ceil();
    return (
      rows: rows,
      tileWidth: (area.width - (columns - 1) * spacing) / columns,
      tileHeight: (area.height - (rows - 1) * spacing) / rows,
    );
  }

  int columnsOf(int count, double width, double height) =>
      showPlayerGridLayout(
        playerCount: count,
        width: width,
        height: height,
      ).columns;

  group('column choice', () {
    test('reproduces the old small-count choices', () {
      expect(columnsOf(1, projector.width, projector.height), 1);
      expect(columnsOf(2, projector.width, projector.height), 2);
      expect(columnsOf(4, projector.width, projector.height), 2);
      expect(columnsOf(9, projector.width, projector.height), 3);
    });

    test('grows past the old 4-column cap (~30 players → 6×5)', () {
      final layout30 = showPlayerGridLayout(
        playerCount: 30,
        width: projector.width,
        height: projector.height,
      );
      expect(layout30.columns, 6);
      expect((30 / layout30.columns).ceil(), 5);
      expect(layout30.childAspectRatio, greaterThan(0));
    });

    test('clamps to a sane column ceiling', () {
      final layout300 = showPlayerGridLayout(
        playerCount: 300,
        width: projector.width,
        height: projector.height,
      );
      expect(layout300.columns, lessThanOrEqualTo(8));
    });
  });

  group('exact tiling (no scroll, no overflow) across shapes', () {
    final shapes = {
      'projector 16:9': const Size(1920, 1056),
      'laptop 16:10': const Size(1440, 855),
      'square-ish': const Size(900, 880),
      'portrait': const Size(500, 1400),
    };

    for (final entry in shapes.entries) {
      for (final count in [2, 3, 5, 8, 12, 16, 24, 30, 45]) {
        test('${entry.key} × $count players tiles exactly', () {
          final (:rows, :tileWidth, :tileHeight) = layoutFor(count, entry.value);
          expect(tileWidth, greaterThan(0));
          expect(tileHeight, greaterThan(0));

          // Total grid height (rows + spacing) must fit the area — the old
          // layout overflowed by rows × (count-driven) cell heights.
          final totalHeight = tileHeight * rows + (rows - 1) * spacing;
          expect(totalHeight, lessThanOrEqualTo(entry.value.height + 0.01));

          // Every full row must fit the width too.
          final columns = columnsOf(
            count,
            entry.value.width,
            entry.value.height,
          );
          final rowWidth = tileWidth * columns + (columns - 1) * spacing;
          expect(rowWidth, lessThanOrEqualTo(entry.value.width + 0.01));
        });
      }
    }
  });

  group('degenerate inputs do not crash', () {
    test('zero and negative inputs yield a safe single tile', () {
      expect(
        showPlayerGridLayout(
          playerCount: 0,
          width: projector.width,
          height: projector.height,
        ),
        (columns: 1, childAspectRatio: 1),
      );
      expect(
        showPlayerGridLayout(
          playerCount: 4,
          width: 0,
          height: projector.height,
        ),
        (columns: 1, childAspectRatio: 1),
      );
      expect(
        showPlayerGridLayout(
          playerCount: 4,
          width: projector.width,
          height: -5,
        ),
        (columns: 1, childAspectRatio: 1),
      );
    });

    test('single player fills the whole area', () {
      final (:columns, :childAspectRatio) = showPlayerGridLayout(
        playerCount: 1,
        width: projector.width,
        height: projector.height,
      );
      expect(columns, 1);
      expect(childAspectRatio, closeTo(projector.width / projector.height, 1e-9));
    });
  });

  group('PlayerTileGrid (real widget)', () {
    testWidgets('30 tiles fill the viewport with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerTileGrid(
              tiles: [
                for (var i = 0; i < 30; i++)
                  ColoredBox(
                    color: Color(0xFF000000 + i),
                    child: Text('Player $i'),
                  ),
              ],
            ),
          ),
        ),
      );

      // An overflow anywhere in the grid throws in tests — landing here
      // means the packing kept every tile inside the viewport.
      expect(tester.takeException(), isNull);
      expect(find.text('Player 0'), findsOneWidget);
      expect(find.text('Player 29'), findsOneWidget);
    });

    testWidgets('empty grid shows the waiting placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PlayerTileGrid(tiles: [])),
        ),
      );
      expect(find.text('Waiting for players…'), findsOneWidget);
    });
  });
}

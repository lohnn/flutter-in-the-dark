import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/plasma_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The loader's fixed intrinsic assembly (~161 px: 120 px paint + 20 gap +
/// caption) must never overflow its box: inside the packed /show
/// scoreboard's short content strips (~24 px at 100 players) it used to
/// paint over neighbouring tiles. The FittedBox scale-down fence keeps the
/// render 1:1 wherever there IS room and shrinks it into any strip that
/// isn't — a RenderFlex overflow under `flutter test` fails these.
void main() {
  testWidgets('loader scales down inside a sub-intrinsic strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 24, child: PlasmaLoader()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Generating…'), findsOneWidget);
  });

  testWidgets('renderer-sized strips do not overflow either', (tester) async {
    // The ~75 px strip a 60-player 1080p scoreboard gives its content.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 300, height: 75, child: PlasmaLoader()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('roomy boxes keep the 1:1 assembly (paint size untouched)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 800, height: 600, child: PlasmaLoader()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final paint = tester.getSize(
      find
          .descendant(
            of: find.byType(PlasmaLoader),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      paint,
      const Size(120, 120),
      reason: 'scaleDown never scales UP — big containers are unchanged',
    );
  });
}

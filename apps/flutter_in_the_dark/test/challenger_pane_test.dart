import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/widgets/challenger_pane.dart';
import 'package:flutter_test/flutter_test.dart';

/// The /show single-competitor switch contract, exercised through the REAL
/// pane decision ([ChallengerPane] — the carrier for what /show renders).
///
/// The switch reuses the pane element (same type, same tree position, no
/// key on PlayerCard), so every branch below mounts the widget once and
/// re-pumps it with a DIFFERENT challenger: whatever the previous
/// competitor showed must be replaced by the new one's content.
///
/// The compiled-widget branch asserts the other half of the contract: the
/// pane must ask for the INCOMING challenger's `/compiled/<id>` path. The
/// iframe itself (CompiledWidget) is inside the W-012 taint cone — its
/// didUpdateWidget src-swap is verified in a browser against the release
/// build, not here.
Challenger _challenger({
  required String id,
  required String name,
  String prompt = '',
  GenState genState = GenState.idle,
  String? generatedCode,
  String? compiledUrl,
  String? error,
}) =>
    Challenger(
      id: id,
      name: name,
      prompt: prompt,
      genState: genState,
      generatedCode: generatedCode,
      compiledUrl: compiledUrl,
      error: error,
    );

Widget _pane(
  Challenger challenger,
  DisplayContent content,
  List<String> widgetPaneRequests,
) =>
    MaterialApp(
      home: Scaffold(
        body: ChallengerPane(
          challenger: challenger,
          content: content,
          widgetViewBuilder: (path) {
            widgetPaneRequests.add(path);
            return Text('WIDGET PANE: $path');
          },
        ),
      ),
    );

void main() {
  testWidgets('prompt pane follows the switched competitor', (tester) async {
    final requests = <String>[];
    final a = _challenger(id: 'a', name: 'A', prompt: 'a prompt about cats');
    final b = _challenger(id: 'b', name: 'B', prompt: 'b prompt about dogs');
    await tester.pumpWidget(_pane(a, DisplayContent.prompt, requests));
    expect(find.text('a prompt about cats'), findsOneWidget);

    await tester.pumpWidget(_pane(b, DisplayContent.prompt, requests));
    expect(find.text('a prompt about cats'), findsNothing);
    expect(find.text('b prompt about dogs'), findsOneWidget);
  });

  testWidgets('code pane follows the switched competitor', (tester) async {
    final requests = <String>[];
    final a = _challenger(
      id: 'a',
      name: 'A',
      genState: GenState.ready,
      generatedCode: 'class _A extends StatelessWidget {}',
    );
    final b = _challenger(
      id: 'b',
      name: 'B',
      genState: GenState.ready,
      generatedCode: 'class _B extends StatelessWidget {}',
    );
    await tester.pumpWidget(_pane(a, DisplayContent.code, requests));
    expect(find.text('class _A extends StatelessWidget {}'), findsOneWidget);

    await tester.pumpWidget(_pane(b, DisplayContent.code, requests));
    expect(find.text('class _A extends StatelessWidget {}'), findsNothing);
    expect(find.text('class _B extends StatelessWidget {}'), findsOneWidget);
  });

  testWidgets('widget pane asks the builder for the NEW competitor path', (
    tester,
  ) async {
    final requests = <String>[];
    final a = _challenger(
      id: 'a',
      name: 'A',
      genState: GenState.ready,
      compiledUrl: '/compiled/aaa',
    );
    final b = _challenger(
      id: 'b',
      name: 'B',
      genState: GenState.ready,
      compiledUrl: '/compiled/bbb',
    );
    await tester.pumpWidget(_pane(a, DisplayContent.widget, requests));
    expect(find.text('WIDGET PANE: /compiled/aaa'), findsOneWidget);

    // Same element in the same position — the switch the projector does.
    await tester.pumpWidget(_pane(b, DisplayContent.widget, requests));
    expect(find.text('WIDGET PANE: /compiled/bbb'), findsOneWidget);
    expect(find.text('WIDGET PANE: /compiled/aaa'), findsNothing);
    expect(requests, ['/compiled/aaa', '/compiled/bbb']);
  });

  testWidgets('widget pane without a compiled url shows the waiting loader', (
    tester,
  ) async {
    final requests = <String>[];
    final a = _challenger(id: 'a', name: 'A', genState: GenState.ready);
    await tester.pumpWidget(_pane(a, DisplayContent.widget, requests));
    expect(find.text('Waiting for compiled app…'), findsOneWidget);
    expect(requests, isEmpty);

    // And when the url arrives (generation finished), the builder is asked:
    await tester.pumpWidget(
      _pane(
        _challenger(
          id: 'a',
          name: 'A',
          genState: GenState.ready,
          compiledUrl: '/compiled/aaa',
        ),
        DisplayContent.widget,
        requests,
      ),
    );
    expect(find.text('WIDGET PANE: /compiled/aaa'), findsOneWidget);
  });

  testWidgets('generation pipeline states surface as loader labels', (
    tester,
  ) async {
    final requests = <String>[];
    final cases = {
      GenState.queued: 'Queued for generation…',
      GenState.generating: 'Generating code…',
      GenState.compiling: 'Compiling…',
      GenState.idle: 'Waiting…',
    };
    for (final entry in cases.entries) {
      final c = _challenger(id: 'a', name: 'A', genState: entry.key);
      await tester.pumpWidget(_pane(c, DisplayContent.code, requests));
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('failed state surfaces the error pane', (tester) async {
    final requests = <String>[];
    final a = _challenger(
      id: 'a',
      name: 'A',
      genState: GenState.failed,
      error: 'dart2js exploded',
    );
    await tester.pumpWidget(_pane(a, DisplayContent.code, requests));
    expect(find.text('Generation failed'), findsOneWidget);
    expect(find.text('dart2js exploded'), findsOneWidget);
  });

  testWidgets('failed pane never overflows a scoreboard-content strip', (
    tester,
  ) async {
    // The 100-player wall gives each tile's content a ~24 px strip; the
    // failed pane's fixed-ish assembly must scale down INSIDE the strip,
    // not paint over the neighbouring tiles.
    final requests = <String>[];
    final a = _challenger(
      id: 'a',
      name: 'A',
      genState: GenState.failed,
      error: 'boom',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 24,
            child: ChallengerPane(
              challenger: a,
              content: DisplayContent.code,
              widgetViewBuilder: (path) {
                requests.add(path);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Generation failed'), findsOneWidget);
  });

  testWidgets('loading states never overflow a scoreboard-content strip', (
    tester,
  ) async {
    // Same fence for the Code/Widget reveal with the pipeline still idle:
    // the loader must scale into the strip (see plasma_loader_test).
    final requests = <String>[];
    final a = _challenger(id: 'a', name: 'A');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 24,
            child: ChallengerPane(
              challenger: a,
              content: DisplayContent.code,
              widgetViewBuilder: (path) {
                requests.add(path);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Waiting…'), findsOneWidget);
  });

  testWidgets('empty prompt shows the thinking placeholder', (tester) async {
    final requests = <String>[];
    final a = _challenger(id: 'a', name: 'A');
    await tester.pumpWidget(_pane(a, DisplayContent.prompt, requests));
    expect(find.text('Thinking in the dark…'), findsOneWidget);
  });
}

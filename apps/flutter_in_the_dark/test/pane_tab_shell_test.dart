import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/widgets/pane_tab_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// pane_tab_shell.dart is deliberately OUTSIDE the W-012 tainted cone (no
/// room_client / dart:js_interop), so [PaneTabShell] CAN be widget-tested on
/// the VM — unlike challenge_screen.dart, which wraps it. The probe panes
/// below likewise use plain Flutter only, keeping this file taint-free.

/// Stateful pane probe: shows "n taps" text, persistent across rebuilds —
/// lets liveness assertions survive a tab switch away and back (the shell
/// must keep panes alive in an IndexedStack, never dispose them).
class TapProbe extends StatefulWidget {
  const TapProbe({super.key, required this.label});

  final String label;

  @override
  State<TapProbe> createState() => _TapProbeState();
}

class _TapProbeState extends State<TapProbe> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.label} pane'),
        Text('$_taps taps'),
        TextButton(
          onPressed: () => setState(() => _taps++),
          child: const Text('tap-me'),
        ),
      ],
    );
  }
}

/// Pane probe holding a focusable TextField. Accepts an injected
/// [focusNode] so the test can assert exactly that node's focus state.
class FocusProbe extends StatefulWidget {
  const FocusProbe({super.key, required this.label, this.focusNode});

  final String label;
  final FocusNode? focusNode;

  @override
  State<FocusProbe> createState() => _FocusProbeState();
}

class _FocusProbeState extends State<FocusProbe> {
  FocusNode? _owned;
  FocusNode get _focusNode => widget.focusNode ?? (_owned ??= FocusNode());

  @override
  void dispose() {
    // Only dispose the node the state owns itself; an injected node belongs
    // to the test.
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.label} pane'),
        TextField(focusNode: _focusNode),
      ],
    );
  }
}

Widget _shell(List<(String, Widget)> tabs, {int? initialIndex}) {
  return MaterialApp(
    home: PaneTabShell(
      title: const Text('Challenger'),
      tabs: tabs,
      initialIndex: initialIndex ?? 0,
    ),
  );
}

/// NOTE: the handle must be disposed INLINE before the test body ends —
/// registering `addTearDown(handle.dispose)` fires after the framework's
/// end-of-test verification, which then fails with
/// "A SemanticsHandle was active at the end of the test".
SemanticsHandle _enableSemantics(WidgetTester tester) =>
    tester.ensureSemantics();

/// Only the selected IndexedStack pane is visible to semantics; the other
/// panes exist in the tree but are excluded from it, so semantic finders can
/// tell "shown" from "merely kept alive".
void main() {
  testWidgets('isCompactWidth boundaries', (tester) async {
    expect(isCompactWidth(599), isTrue);
    expect(isCompactWidth(600), isFalse);
    expect(isCompactWidth(601), isFalse);
    expect(kPaneTabShellBreakpoint, 600);
  });

  testWidgets('initialIndex shows only that pane semantically', (tester) async {
    final handle = _enableSemantics(tester);
    await tester.pumpWidget(
      _shell(
        [
          ('A', const Text('pane-a')),
          ('B', const Text('pane-b')),
        ],
        initialIndex: 1,
      ),
    );
    expect(find.bySemanticsLabel('pane-b'), findsOneWidget);
    expect(find.bySemanticsLabel('pane-a'), findsNothing);
    handle.dispose();
  });

  testWidgets('default initialIndex is 0', (tester) async {
    final handle = _enableSemantics(tester);
    await tester.pumpWidget(
      _shell([
        ('A', const Text('pane-a')),
        ('B', const Text('pane-b')),
      ]),
    );
    expect(find.bySemanticsLabel('pane-a'), findsOneWidget);
    expect(find.bySemanticsLabel('pane-b'), findsNothing);
    handle.dispose();
  });

  testWidgets('initialIndex is clamped into range', (tester) async {
    final handle = _enableSemantics(tester);
    await tester.pumpWidget(
      _shell(
        [
          ('A', const Text('pane-a')),
          ('B', const Text('pane-b')),
        ],
        initialIndex: 5,
      ),
    );
    // Out-of-range initialIndex lands on the last tab, not off the end.
    expect(find.bySemanticsLabel('pane-b'), findsOneWidget);
    expect(find.bySemanticsLabel('pane-a'), findsNothing);
    handle.dispose();
  });

  testWidgets('pane state survives a tab switch round-trip (liveness)',
      (tester) async {
    await tester.pumpWidget(
      _shell([
        ('A', const TapProbe(label: 'Alpha')),
        ('B', const TapProbe(label: 'Beta')),
      ]),
    );
    expect(find.text('0 taps'), findsOneWidget);

    // Interact with pane A, then leave it.
    await tester.tap(find.text('tap-me'));
    await tester.pump();
    expect(find.text('1 taps'), findsOneWidget);

    await tester.tap(find.text('B'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Beta pane'), findsOneWidget);

    // Come back: the indexed stack must have kept A's state.
    await tester.tap(find.text('A'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Alpha pane'), findsOneWidget);
    expect(find.text('1 taps'), findsOneWidget);
  });

  testWidgets('all tab labels are present in the TabBar', (tester) async {
    await tester.pumpWidget(
      _shell([
        ('Challenge', const TapProbe(label: 'Alpha')),
        ('Prompt', const TapProbe(label: 'Beta')),
        ('Assets', const TapProbe(label: 'Gamma')),
      ]),
    );
    expect(find.text('Challenge'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('Assets'), findsOneWidget);
  });

  testWidgets('tab-count change recreates the controller, clamped into range',
      (tester) async {
    final handle = _enableSemantics(tester);
    await tester.pumpWidget(
      _shell(
        [
          ('A', const TapProbe(label: 'Alpha')),
          ('B', const TapProbe(label: 'Beta')),
          ('C', const TapProbe(label: 'Gamma')),
        ],
        initialIndex: 2,
      ),
    );
    expect(find.bySemanticsLabel('Gamma pane'), findsOneWidget);

    // Same element position, fewer tabs: index 2 must clamp to 1.
    await tester.pumpWidget(
      _shell([
        ('A', const TapProbe(label: 'Alpha')),
        ('B', const TapProbe(label: 'Beta')),
      ]),
    );
    expect(find.bySemanticsLabel('Beta pane'), findsOneWidget);
    expect(find.bySemanticsLabel('Alpha pane'), findsNothing);
    handle.dispose();
  });

  testWidgets('switching tabs unfocuses the focused field', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _shell([
        ('A', FocusProbe(label: 'Alpha', focusNode: focusNode)),
        ('B', const TapProbe(label: 'Beta')),
      ]),
    );

    // Focus the probe's text field.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // Switch to tab B: the hidden field must have lost focus (otherwise the
    // mobile keyboard stays up over the newly shown tab). Note primaryFocus
    // does NOT fall back to null in a mounted Navigator — focus retreats to
    // the scope node — so asserting the field's node is the meaningful check.
    await tester.tap(find.text('B'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
  });
}

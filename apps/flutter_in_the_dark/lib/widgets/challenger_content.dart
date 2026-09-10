import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/room/room_client.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/widgets/challenger_pane.dart';
import 'package:flutter_in_the_dark/widgets/compiled_widget.dart';

export 'package:flutter_in_the_dark/widgets/challenger_pane.dart';

/// One challenger's content pane per the admin's tri-state selection
/// (Prompt | Code | Widget), with the loading state shown when the admin
/// flips to Code/Widget before generation+compile is `ready` (§6.C).
///
/// Used identically on `/show` and on the contestant's own done screen —
/// same render, same instant.
///
/// The pane DECISION moved to the taint-free [ChallengerPane]
/// (challenger_pane.dart) so it stays widget-testable (W-012: this file
/// transitively imports room_client/compiled_widget → dart:js_interop and
/// cannot run on the test VM). This class is now the 1:1 adapter that
/// injects the real iframe pane — including the url join against
/// [RoomClient.compileBaseUrl] exactly as the old _WidgetPane did.
class ChallengerContent extends StatelessWidget {
  const ChallengerContent({
    super.key,
    required this.challenger,
    required this.content,
    this.expanded = false,
    this.autoScroll = false,
  });

  final Challenger challenger;
  final DisplayContent content;

  /// Bigger type for the single-player view.
  final bool expanded;

  /// Slow ping-pong auto-scroll for the code pane — used on the projector
  /// view (/show) where nobody can touch the screen. Off by default so
  /// interactive screens (the contestant's own view) keep manual control.
  final bool autoScroll;

  @override
  Widget build(BuildContext context) {
    return ChallengerPane(
      challenger: challenger,
      content: content,
      expanded: expanded,
      autoScroll: autoScroll,
      widgetViewBuilder: (compiledPath) => CompiledWidget(
        url: '${RoomClient.compileBaseUrl}$compiledPath',
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/room/room_models.dart';
import 'package:flutter_in_the_dark/widgets/code_pane.dart';
import 'package:flutter_in_the_dark/widgets/plasma_loader.dart';

/// How a pane's compiled-widget branch obtains its iframe: the tainted side
/// (challenger_content.dart, which imports compiled_widget/room_client)
/// injects [CompiledWidget]; this file stays free of dart:js_interop so the
/// whole pane decision is REAL under `flutter test` (I-096: carve
/// taint-free shells taking plain model objects).
typedef WidgetPaneBuilder = Widget Function(String compiledPath);

/// One challenger's content pane per the admin's tri-state selection
/// (Prompt | Code | Widget), with the loading state shown when the admin
/// flips to Code/Widget before generation+compile is `ready` (§6.C).
///
/// The pane DECISION lives here (taint-free); [ChallengerContent] in
/// challenger_content.dart is its tainted 1:1 adapter for the real app.
/// All data comes in as plain model objects ([Challenger], [DisplayContent])
/// freshly read from the room snapshot — nothing is captured at mount time,
/// so a competitor switch on /show (same element, new challenger) renders
/// the new competitor's content by construction.
class ChallengerPane extends StatelessWidget {
  const ChallengerPane({
    super.key,
    required this.challenger,
    required this.content,
    required this.widgetViewBuilder,
    this.expanded = false,
    this.autoScroll = false,
  });

  final Challenger challenger;
  final DisplayContent content;

  /// Builds the compiled-widget pane for the challenger's `/compiled/<id>`
  /// path (NOT a full url — url resolution stays on the tainted side).
  final WidgetPaneBuilder widgetViewBuilder;

  /// Bigger type for the single-player view.
  final bool expanded;

  /// Slow ping-pong auto-scroll for the code pane — used on the projector
  /// view (/show) where nobody can touch the screen. Off by default so
  /// interactive screens (the contestant's own view) keep manual control.
  final bool autoScroll;

  @override
  Widget build(BuildContext context) {
    final fontSize = expanded ? 24.0 : 14.0;
    return switch (content) {
      DisplayContent.prompt => _PromptPane(
          prompt: challenger.prompt,
          fontSize: fontSize,
        ),
      DisplayContent.code => _readyOrLoading(
          () => CodePane(
                code: challenger.generatedCode ?? '',
                fontSize: fontSize,
                autoScroll: autoScroll,
              ),
        ),
      DisplayContent.widget => _readyOrLoading(
          () {
            final path = challenger.compiledUrl;
            return path == null
                ? const PlasmaLoader(label: 'Waiting for compiled app…')
                : widgetViewBuilder(path);
          },
        ),
    };
  }

  Widget _readyOrLoading(Widget Function() builder) {
    return switch (challenger.genState) {
      GenState.ready => builder(),
      GenState.failed => _FailedPane(error: challenger.error),
      _ => PlasmaLoader(
          label: switch (challenger.genState) {
            GenState.queued => 'Queued for generation…',
            GenState.generating => 'Generating code…',
            GenState.compiling => 'Compiling…',
            _ => 'Waiting…',
          },
        ),
    };
  }
}

class _PromptPane extends StatelessWidget {
  const _PromptPane({required this.prompt, required this.fontSize});

  final String prompt;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (prompt.isEmpty) {
      return Center(
        child: Text(
          'Thinking in the dark…',
          style: TextStyle(
            color: Colors.white24,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      reverse: true,
      padding: const EdgeInsets.all(16),
      child: Text(
        prompt,
        style: TextStyle(
          fontFamily: 'monospace',
          color: const Color(0xFFE6EDF3),
          fontSize: fontSize,
          height: 1.5,
        ),
      ),
    );
  }
}

class _FailedPane extends StatelessWidget {
  const _FailedPane({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Generation failed',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

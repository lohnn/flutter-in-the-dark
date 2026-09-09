import 'package:flutter/material.dart';

/// Full-screen tab shell for compact (phone) viewports in the ChallengeScreen
/// LIVE phase: Challenge | Prompt | Optional assets become AppBar tabs
/// instead of unreadable side-by-side SplitPane panes.
///
/// This file is deliberately OUTSIDE the W-012 tainted cone (no room_client,
/// no compiled_widget, no prompt_editor — nothing that transitively touches
/// package:web / dart:js_interop), so [PaneTabShell] CAN be widget-tested on
/// the VM (SHADOW-003), unlike challenge_screen.dart which is untestable by
/// design.
///
/// Keep this file importing ONLY flutter/material.
class PaneTabShell extends StatefulWidget {
  const PaneTabShell({
    super.key,
    required this.title,
    required this.tabs,
    this.initialIndex = 0,
  });

  /// Rendered inside the AppBar. On mobile the screen passes a smaller,
  /// name-dropped countdown title (I-097: the desktop title Row overflows at
  /// ~360 dp because an AppBar has no width of its own).
  final Widget title;

  /// One `(label, pane)` record per tab: [TabBar] label, and the pane shown
  /// iff that tab is selected.
  final List<(String tabLabel, Widget pane)> tabs;

  /// Tab selected on first build, clamped into range. The SAFE
  /// (desktop-unchanged) default lives at the call site, not here (I-022) —
  /// callers pick which pane opens; this shell only guards the bounds.
  final int initialIndex;

  @override
  State<PaneTabShell> createState() => _PaneTabShellState();
}

class _PaneTabShellState extends State<PaneTabShell>
    with TickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _makeController();
    _controller.addListener(_onTabChanged);
  }

  TabController _makeController() {
    return TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, widget.tabs.length - 1),
    );
  }

  /// TabController.length is fixed at construction; when the challenge update
  /// grows/shrinks the tab set (e.g. assets appear), recreate it and clamp the
  /// current selection into the new range.
  @override
  void didUpdateWidget(covariant PaneTabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      final current = _controller.index.clamp(0, widget.tabs.length - 1);
      _controller.removeListener(_onTabChanged);
      _controller.dispose();
      _controller = TabController(
        length: widget.tabs.length,
        vsync: this,
        initialIndex: current,
      );
      _controller.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // A hidden-but-focused TextField (the PromptEditor under the Prompt tab)
    // keeps the mobile keyboard raised over whichever tab the challenger just
    // switched to — drop focus on every switch.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.title,
        bottom: TabBar(
          controller: _controller,
          tabs: [for (final (label, _) in widget.tabs) Tab(text: label)],
        ),
      ),
      // IndexedStack, NOT TabBarView: panes must stay alive across tab
      // switches — the PromptEditor keeps unsynced text + focus, the
      // challenge's CompiledWidget iframes must not reload. Never dispose
      // panes on switch.
      body: IndexedStack(
        index: _controller.index,
        children: [for (final (_, pane) in widget.tabs) pane],
      ),
    );
  }
}

/// Below this width the ChallengeScreen uses the [PaneTabShell] mobile
/// treatment; desktop keeps the SplitPane layout, unchanged.
const double kPaneTabShellBreakpoint = 600;

/// Compact (phone) test — pure, so it is unit-testable without bindings.
bool isCompactWidth(double width) => width < kPaneTabShellBreakpoint;

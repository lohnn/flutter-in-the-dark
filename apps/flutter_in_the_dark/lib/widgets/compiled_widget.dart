import 'dart:js_interop';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Chromeless iframe rendering a self-hosted compiled Flutter app
/// (`{compileBase}/compiled/<id>`), replacing the dartpad.dev embed.
///
/// Also used for pre-compiled challenge widgets (§6.F) — same serving path.
///
/// The SAME iframe element is kept across updates: [didUpdateWidget] swaps
/// `_iframe.src` when the url changes instead of remounting (which would
/// re-register a platform view and flash blank). This is what makes
/// /show's single-competitor switch actually swap the compiled app: the
/// pane stays in the same tree position while only the focused competitor
/// changes, so a url captured in initState alone would keep rendering the
/// PREVIOUS competitor's frame forever.
///
/// Runtime errors from the frame arrive as postMessage
/// `{sender:'fitd-frame', type:'jserr'|'stderr'|'stdout', message}` and are
/// surfaced through [onError].
///
/// [interactable] — an iframe document grabs browser pointer events at the
/// DOM level: a mouse press/move/wheel over the frame dispatches INTO the
/// frame's document and never reaches the parent window's listeners, so
/// Flutter gestures that cross the frame (dragging a [SplitPane] divider
/// across it; wheel-scrolling a GridView behind it) silently freeze. Flutter
/// hit-testing cannot help — IgnorePointer never sees the events.
/// /show (a projector wall nobody may touch) therefore passes
/// `interactable: false`, which sets `pointer-events: none` on the iframe
/// element itself: the frame still renders and still receives programmatic
/// events, but the browser routes all pointer input to the app underneath.
/// Defaults to true — the player's own preview keeps mouse/keyboard focus
/// and interactivity for editing/scrolling its contents.
class CompiledWidget extends StatefulWidget {
  const CompiledWidget({
    super.key,
    required this.url,
    this.interactable = true,
    this.onError,
  });

  /// Full URL of the compiled app (path-absolute `url` from compileAndServe
  /// resolved against the generation backend).
  final String url;

  /// Whether the frame may receive browser pointer events. False sets
  /// `pointer-events: none` on the iframe (the only reliable switch on web —
  /// see the class comment). Default keeps the frame interactive.
  final bool interactable;

  final void Function(String message)? onError;

  @override
  State<CompiledWidget> createState() => _CompiledWidgetState();
}

class _CompiledWidgetState extends State<CompiledWidget> {
  late final web.HTMLIFrameElement _iframe;
  late final String _viewType;
  JSFunction? _messageHandler;

  static int _instanceCounter = 0;

  @override
  void initState() {
    super.initState();
    _viewType = 'fitd-compiled-${_instanceCounter++}';
    _iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'autoplay';
    _applyInteractable();

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );

    _messageHandler = ((web.Event event) {
      final message = event as web.MessageEvent;
      final data = message.data;
      if (!data.isA<JSObject>()) return;
      final map = (data as JSObject).dartify();
      if (map is Map &&
          map['sender'] == 'fitd-frame' &&
          (map['type'] == 'jserr' || map['type'] == 'stderr')) {
        widget.onError?.call(map['message']?.toString() ?? 'unknown');
      }
    }).toJS;
    web.window.addEventListener('message', _messageHandler!);
  }

  @override
  void didUpdateWidget(CompiledWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The iframe captured `widget.url` in initState; without this, ANY
    // parent rebuild keeps showing the old app (the view type is stable,
    // so the platform view survives). Only touch src when it actually
    // changed — the browser navigates the existing frame to the new app.
    if (widget.url != oldWidget.url) {
      _iframe.src = widget.url;
    }
    if (widget.interactable != oldWidget.interactable) {
      _applyInteractable();
    }
  }

  /// The DOM-level switch for [CompiledWidget.interactable]. An empty string
  /// clears the inline style and restores the browser default (interactive).
  void _applyInteractable() {
    _iframe.style.pointerEvents = widget.interactable ? '' : 'none';
  }

  @override
  void dispose() {
    if (_messageHandler != null) {
      web.window.removeEventListener('message', _messageHandler!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

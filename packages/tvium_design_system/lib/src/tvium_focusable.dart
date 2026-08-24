import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tvium_tokens.dart';

final class TviumFocusable extends StatefulWidget {
  const TviumFocusable({
    required this.child,
    required this.onActivate,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<TviumFocusable> createState() => _TviumFocusableState();
}

final class _TviumFocusableState extends State<TviumFocusable> {
  var _focused = false;
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final borderColor = _focused
        ? accent
        : _hovered
        ? theme.colorScheme.onSurface.withValues(alpha: 0.32)
        : Colors.transparent;
    final scale = _focused ? 1.018 : (_pressed ? 0.985 : 1.0);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.enter):
              const ActivateIntent(),
          const SingleActivator(LogicalKeyboardKey.select):
              const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                if (widget.enabled) {
                  widget.onActivate();
                }
                return null;
              },
            ),
          },
          child: FocusableActionDetector(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            mouseCursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            onShowHoverHighlight: (value) => setState(() => _hovered = value),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? widget.onActivate : null,
              onTapDown: widget.enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapCancel: widget.enabled
                  ? () => setState(() => _pressed = false)
                  : null,
              onTapUp: widget.enabled
                  ? (_) => setState(() => _pressed = false)
                  : null,
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(TviumRadius.card),
                    boxShadow: _focused
                        ? <BoxShadow>[
                            BoxShadow(
                              color: accent.withValues(alpha: 0.2),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

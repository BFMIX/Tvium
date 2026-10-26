import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

final class SourceActionCard extends StatelessWidget {
  const SourceActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onActivate,
    required this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.width = 250,
    this.compact = false,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onActivate;
  final FocusNode focusNode;
  final bool autofocus;
  final bool enabled;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TviumFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      semanticLabel: title,
      onActivate: () {
        focusNode.requestFocus();
        onActivate();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TviumRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: width,
            height: compact ? null : 208,
            constraints: BoxConstraints(minHeight: compact ? 86 : 152),
            padding: const EdgeInsets.all(TviumSpacing.md),
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xAE163149)
                  : TviumColors.surfaceDark.withValues(alpha: 0.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.08),
              ),
              borderRadius: BorderRadius.circular(TviumRadius.card),
            ),
            child: compact
                ? Row(
                    children: <Widget>[
                      _SourceIcon(icon: icon, color: theme.colorScheme.primary),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(
                        child: _SourceCopy(title, description, centered: false),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          _SourceIcon(
                            icon: icon,
                            color: theme.colorScheme.primary,
                            large: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TviumSpacing.md),
                      _SourceCopy(title, description, centered: true),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

final class _SourceIcon extends StatelessWidget {
  const _SourceIcon({
    required this.icon,
    required this.color,
    this.large = false,
  });

  final IconData icon;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
    width: large ? 64 : 48,
    height: large ? 64 : 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(TviumRadius.control),
    ),
    child: Icon(icon, color: color, size: large ? 34 : 26),
  );
}

final class _SourceCopy extends StatelessWidget {
  const _SourceCopy(this.title, this.description, {required this.centered});

  final String title;
  final String description;
  final bool centered;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (centered)
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        )
      else
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      const SizedBox(height: TviumSpacing.xxs),
      Text(
        description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: const Color(0xFFBED0DF)),
      ),
    ],
  );
}

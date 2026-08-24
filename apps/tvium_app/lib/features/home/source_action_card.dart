import 'package:flutter/material.dart';
import 'package:tvium_design_system/tvium_design_system.dart';

final class SourceActionCard extends StatelessWidget {
  const SourceActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onActivate,
    required this.focusNode,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onActivate;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TviumFocusable(
      focusNode: focusNode,
      enabled: enabled,
      semanticLabel: title,
      onActivate: () {
        focusNode.requestFocus();
        onActivate();
      },
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(TviumSpacing.md),
        decoration: BoxDecoration(
          color: enabled
              ? TviumColors.surfaceDark
              : TviumColors.surfaceDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(TviumRadius.card),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(TviumRadius.control),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: TviumSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: TviumSpacing.xxs),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

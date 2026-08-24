import 'package:flutter/material.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_design_system/tvium_design_system.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

import '../../l10n/generated/app_localizations.dart';

final class SignalRail extends StatelessWidget {
  const SignalRail({required this.entries, super.key});

  final List<M3uEntry> entries;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final labels = <String>[
      localizations.liveTv,
      localizations.movies,
      localizations.tvShows,
    ];
    final kinds = <MediaKind>[
      MediaKind.live,
      MediaKind.movie,
      MediaKind.episode,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final cardWidth = available >= 760 ? (available - 24) / 3 : 220.0;
        return SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: TviumSpacing.sm),
            itemBuilder: (context, index) {
              final count = entries
                  .where((entry) => entry.kind == kinds[index])
                  .length;
              return Container(
                width: cardWidth,
                padding: const EdgeInsets.all(TviumSpacing.md),
                decoration: BoxDecoration(
                  color: TviumColors.surfaceDark,
                  borderRadius: BorderRadius.circular(TviumRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      labels[index],
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                    ),
                    const SizedBox(height: TviumSpacing.xs),
                    Container(
                      height: 2,
                      color: count == 0
                          ? TviumColors.mutedDark.withValues(alpha: 0.2)
                          : TviumColors.accentDark,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

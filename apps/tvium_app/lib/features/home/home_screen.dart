import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_design_system/tvium_design_system.dart';
import 'package:tvium_m3u/tvium_m3u.dart';
import 'package:tvium_playback/tvium_playback.dart';

import '../../l10n/generated/app_localizations.dart';
import '../import/playlist_import_controller.dart';
import '../import/playlist_import_provider.dart';
import 'signal_rail.dart';
import 'source_action_card.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlActionFocus = FocusNode(debugLabel: 'M3U URL action');
  final FocusNode _fileActionFocus = FocusNode(debugLabel: 'M3U file action');
  final FocusNode _xtreamActionFocus = FocusNode(debugLabel: 'Xtream action');
  var _showUrlField = false;
  String? _selectedGroup;
  M3uEntry? _selectedEntry;
  MediaKitPlaybackEngine? _playbackEngine;

  @override
  void dispose() {
    _urlController.dispose();
    _urlActionFocus.dispose();
    _fileActionFocus.dispose();
    _xtreamActionFocus.dispose();
    final engine = _playbackEngine;
    if (engine != null) {
      unawaited(engine.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(playlistImportControllerProvider);
    final state = controller.state;
    final ready = state.phase == PlaylistImportPhase.ready;
    return Scaffold(
      body: SafeArea(
        child: ready
            ? _LibraryView(
                state: state,
                selectedGroup: _selectedGroup,
                selectedEntry: _selectedEntry,
                playbackEngine: _playbackEngine,
                onGroupSelected: (group) =>
                    setState(() => _selectedGroup = group),
                onEntrySelected: _play,
              )
            : _buildOnboarding(controller, state),
      ),
    );
  }

  Widget _buildOnboarding(
    PlaylistImportController controller,
    PlaylistImportState state,
  ) {
    final strings = AppLocalizations.of(context);
    final importing = state.phase == PlaylistImportPhase.importing;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TviumSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                strings.appTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: TviumSpacing.xl),
              Text(
                strings.welcomeTitle,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: TviumSpacing.sm),
              Text(
                strings.welcomeBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: TviumSpacing.xs),
              Text(
                strings.disclaimer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: TviumSpacing.xl),
              FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      SourceActionCard(
                        key: const ValueKey<String>('m3u-url-action'),
                        title: strings.m3uUrl,
                        description: strings.analyzePlaylist,
                        icon: Icons.link_rounded,
                        focusNode: _urlActionFocus,
                        onActivate: () => setState(() => _showUrlField = true),
                      ),
                      const SizedBox(width: TviumSpacing.sm),
                      SourceActionCard(
                        key: const ValueKey<String>('m3u-file-action'),
                        title: strings.importLocalM3u,
                        description: '.m3u · .m3u8',
                        icon: Icons.folder_open_rounded,
                        focusNode: _fileActionFocus,
                        onActivate: () => unawaited(_pickLocalFile(controller)),
                      ),
                      const SizedBox(width: TviumSpacing.sm),
                      SourceActionCard(
                        title: strings.xtreamCodes,
                        description: strings.comingLater,
                        icon: Icons.dns_outlined,
                        focusNode: _xtreamActionFocus,
                        enabled: false,
                        onActivate: () {},
                      ),
                    ],
                  ),
                ),
              ),
              if (_showUrlField) ...<Widget>[
                const SizedBox(height: TviumSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        enabled: !importing,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: strings.urlHint,
                          prefixIcon: const Icon(Icons.language_rounded),
                        ),
                        onSubmitted: (_) => _analyzeUrl(controller),
                      ),
                    ),
                    const SizedBox(width: TviumSpacing.sm),
                    FilledButton(
                      onPressed: importing
                          ? null
                          : () => _analyzeUrl(controller),
                      child: Text(strings.analyzePlaylist),
                    ),
                  ],
                ),
              ],
              if (importing) ...<Widget>[
                const SizedBox(height: TviumSpacing.lg),
                const LinearProgressIndicator(),
                const SizedBox(height: TviumSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${strings.importing} ${state.parsedCount}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: controller.cancel,
                      child: Text(strings.cancel),
                    ),
                  ],
                ),
              ],
              if (state.phase == PlaylistImportPhase.failed) ...<Widget>[
                const SizedBox(height: TviumSpacing.lg),
                _InlineError(message: state.message ?? strings.importFailed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _analyzeUrl(PlaylistImportController controller) {
    final strings = AppLocalizations.of(context);
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      controller.reportValidationFailure(strings.invalidUrl);
      return;
    }
    unawaited(controller.importSource(M3uUrlSource(uri)));
  }

  Future<void> _pickLocalFile(PlaylistImportController controller) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['m3u', 'm3u8'],
    );
    if (file == null) {
      return;
    }
    final path = file.path;
    if (!kIsWeb && path != null) {
      await controller.importSource(M3uFileSource(path));
      return;
    }
    await controller.importSource(M3uBytesSource(await file.readAsBytes()));
  }

  Future<void> _play(M3uEntry entry) async {
    final engine = _playbackEngine ??= MediaKitPlaybackEngine();
    setState(() => _selectedEntry = entry);
    await engine.open(
      MediaSource(uri: entry.originalUri, title: entry.originalName),
    );
    await engine.play();
    if (mounted) {
      setState(() {});
    }
  }
}

final class _LibraryView extends StatelessWidget {
  const _LibraryView({
    required this.state,
    required this.selectedGroup,
    required this.selectedEntry,
    required this.playbackEngine,
    required this.onGroupSelected,
    required this.onEntrySelected,
  });

  final PlaylistImportState state;
  final String? selectedGroup;
  final M3uEntry? selectedEntry;
  final MediaKitPlaybackEngine? playbackEngine;
  final ValueChanged<String?> onGroupSelected;
  final ValueChanged<M3uEntry> onEntrySelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final groups =
        state.entries
            .map((entry) => entry.groupTitle ?? strings.unknownGroup)
            .toSet()
            .toList()
          ..sort();
    final visibleEntries = selectedGroup == null
        ? state.entries
        : state.entries
              .where(
                (entry) =>
                    (entry.groupTitle ?? strings.unknownGroup) == selectedGroup,
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.all(TviumSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                strings.appTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Spacer(),
              Text(
                strings.itemsReady(state.parsedCount),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: TviumSpacing.md),
              IconButton(
                tooltip: strings.search,
                onPressed: () {},
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                tooltip: strings.settings,
                onPressed: () {},
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: TviumSpacing.lg),
          SignalRail(entries: state.entries),
          const SizedBox(height: TviumSpacing.lg),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: 210,
                        child: _GroupList(
                          groups: groups,
                          selectedGroup: selectedGroup,
                          onSelected: onGroupSelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(
                        flex: 4,
                        child: _EntryList(
                          entries: visibleEntries,
                          onSelected: onEntrySelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(
                        flex: 5,
                        child: _PlayerPanel(
                          selectedEntry: selectedEntry,
                          engine: playbackEngine,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    SizedBox(
                      height: 44,
                      child: _GroupList(
                        groups: groups,
                        selectedGroup: selectedGroup,
                        onSelected: onGroupSelected,
                        horizontal: true,
                      ),
                    ),
                    const SizedBox(height: TviumSpacing.sm),
                    Expanded(
                      child: _EntryList(
                        entries: visibleEntries,
                        onSelected: onEntrySelected,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
    this.horizontal = false,
  });

  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onSelected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final allGroups = <String?>[null, ...groups];
    return ListView.separated(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      itemCount: allGroups.length,
      separatorBuilder: (context, index) => SizedBox(
        width: horizontal ? TviumSpacing.xs : 0,
        height: horizontal ? 0 : TviumSpacing.xxs,
      ),
      itemBuilder: (context, index) {
        final group = allGroups[index];
        final selected = group == selectedGroup;
        return ChoiceChip(
          selected: selected,
          label: Text(group ?? strings.all),
          onSelected: (_) => onSelected(group),
        );
      },
    );
  }
}

final class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.onSelected});

  final List<M3uEntry> entries;
  final ValueChanged<M3uEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).noItems));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemExtent: 72,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          leading: _Logo(entry: entry),
          title: Text(entry.originalName, maxLines: 1),
          subtitle: Text(entry.kind.name),
          trailing: const Icon(Icons.play_arrow_rounded),
          onTap: () => onSelected(entry),
        );
      },
    );
  }
}

final class _Logo extends StatelessWidget {
  const _Logo({required this.entry});

  final M3uEntry entry;

  @override
  Widget build(BuildContext context) {
    final uri = entry.logoUri;
    if (uri == null || !uri.hasScheme || uri.host.endsWith('.test')) {
      return _LogoFallback(name: entry.originalName);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(TviumRadius.control),
      child: CachedNetworkImage(
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        imageUrl: uri.toString(),
        placeholder: (context, url) => _LogoFallback(name: entry.originalName),
        errorWidget: (context, url, error) =>
            _LogoFallback(name: entry.originalName),
      ),
    );
  }
}

final class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '•' : name.trim()[0].toUpperCase();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TviumColors.raisedDark,
        borderRadius: BorderRadius.circular(TviumRadius.control),
      ),
      child: Text(initial, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

final class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.selectedEntry, required this.engine});

  final M3uEntry? selectedEntry;
  final MediaKitPlaybackEngine? engine;

  @override
  Widget build(BuildContext context) {
    final playbackEngine = engine;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(TviumRadius.surface),
      ),
      clipBehavior: Clip.antiAlias,
      child: playbackEngine == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(TviumSpacing.lg),
                child: Text(
                  AppLocalizations.of(context).chooseChannel,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                MediaKitPlaybackView(engine: playbackEngine),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.all(TviumSpacing.md),
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Text(selectedEntry?.originalName ?? ''),
                  ),
                ),
              ],
            ),
    );
  }
}

final class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TviumSpacing.md),
      decoration: BoxDecoration(
        color: TviumColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(TviumRadius.control),
        border: Border.all(color: TviumColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: TviumColors.error),
          const SizedBox(width: TviumSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

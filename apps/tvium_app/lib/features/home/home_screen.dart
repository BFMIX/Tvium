import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_design_system/tvium_design_system.dart';
import 'package:tvium_m3u/tvium_m3u.dart';
import 'package:tvium_playback/tvium_playback.dart';
import 'package:tvium_xtream/tvium_xtream.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/branding/tvium_brand_logo.dart';
import '../artwork/artwork_image.dart';
import '../artwork/artwork_reference_store.dart';
import '../epg/epg_import_controller.dart';
import '../epg/epg_now_next_provider.dart';
import '../epg/epg_source.dart';
import '../import/local_playlist_picker.dart';
import '../import/m3u_import_persistence.dart';
import '../import/playlist_import_controller.dart';
import '../import/playlist_import_provider.dart';
import '../import/xtream_m3u_detector.dart';
import '../library/library_bootstrap_controller.dart';
import '../library/live_country.dart';
import '../library/source_refresh_schedule.dart';
import '../library/user_overlays_controller.dart';
import '../metadata/metadata_details.dart';
import '../parental/parental_pin_service.dart';
import '../profiles/profile_switcher.dart';
import '../xtream/secure_xtream_profile_store.dart';
import '../xtream/xtream_connection_form.dart';
import '../xtream/xtream_connection_service.dart';
import 'source_action_card.dart';

typedef PlaybackEngineFactory = PlaybackEngine Function();
typedef PlaybackViewBuilder = Widget Function(PlaybackEngine engine);

final playbackEngineFactoryProvider = Provider<PlaybackEngineFactory>(
  (ref) => MediaKitPlaybackEngine.new,
);

final playbackViewBuilderProvider = Provider<PlaybackViewBuilder>(
  (ref) => (engine) {
    if (engine is! MediaKitPlaybackEngine) {
      throw StateError('Unsupported playback engine.');
    }
    return MediaKitPlaybackView(engine: engine);
  },
);

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlActionFocus = FocusNode(debugLabel: 'M3U URL action');
  final FocusNode _fileActionFocus = FocusNode(debugLabel: 'M3U file action');
  final FocusNode _xtreamActionFocus = FocusNode(debugLabel: 'Xtream action');
  var _showUrlField = false;
  var _showXtreamForm = false;
  var _obscureUrl = true;
  String? _selectedGroup;
  XtreamAddedProfile? _xtreamProfile;
  _LibraryEntry? _selectedEntry;
  PlaybackEngine? _playbackEngine;
  StreamSubscription<PlaybackState>? _playbackStateSubscription;
  MediaLocator? _activePlaybackLocator;
  MediaKind? _activePlaybackKind;
  Duration _lastCheckpointPosition = Duration.zero;
  Future<void> _checkpointTail = Future<void>.value();
  String? _playbackError;
  String? _unlockedParentalProfileId;
  var _profileSessionGeneration = 0;
  final _startupRefreshQueued = <String>{};
  Timer? _scheduledRefreshTimer;
  SourceRefreshRunner? _refreshRunner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduledRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_checkDueSources());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkDueSources());
  }

  @override
  void dispose() {
    _scheduledRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _urlActionFocus.dispose();
    _fileActionFocus.dispose();
    _xtreamActionFocus.dispose();
    final subscription = _playbackStateSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
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
    final persistedLibrary = ref.watch(libraryBootstrapProvider).asData?.value;
    if (persistedLibrary != null) {
      final sourceIds = persistedLibrary.sources.map((source) => source.id);
      final pending = persistedLibrary.sources
          .where((source) => !_startupRefreshQueued.contains(source.id))
          .toList(growable: false);
      _startupRefreshQueued.addAll(sourceIds);
      if (pending.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refreshDueSources(pending));
        });
      }
    }
    final profileId =
        persistedLibrary?.activeProfile.id ??
        _xtreamProfile?.targetProfileId ??
        'session.profile';
    final overlays = ref
        .watch(userOverlaysControllerProvider(profileId))
        .asData
        ?.value;
    final parentalPolicy = overlays?.parentalPolicy;
    final allEntries = _libraryEntries(state, persistedLibrary);
    final parentalUnlocked = _unlockedParentalProfileId == profileId;
    final entries = parentalPolicy != null && !parentalUnlocked
        ? allEntries
              .where(
                (entry) => !_blockedByParentalPolicy(
                  entry,
                  parentalPolicy.blockedContent,
                ),
              )
              .toList(growable: false)
        : allEntries;
    final sessionEpgEntries = _sessionEpgEntries(state);
    final epgSchedules = <String, EpgNowNext?>{};
    final epgEntries = <PersistedMediaEntry>[
      ...?persistedLibrary?.entries,
      ...sessionEpgEntries,
    ];
    final epgSourceIds = <String>{
      ...?persistedLibrary?.sources.map((source) => source.id),
      if (sessionEpgEntries.isNotEmpty) 'session.m3u',
    };
    if (epgEntries.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final minute = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      for (final sourceId in epgSourceIds) {
        final snapshot = ref
            .watch(
              epgNowNextProvider(
                EpgNowNextRequest(
                  profileId:
                      persistedLibrary?.activeProfile.id ?? 'session.profile',
                  sourceId: sourceId,
                  entries: epgEntries,
                  atUtc: minute,
                ),
              ),
            )
            .asData
            ?.value;
        if (snapshot != null) {
          for (final entry in epgEntries) {
            if (snapshot.containsEntry(entry.id)) {
              epgSchedules[entry.id] = snapshot.forEntry(entry.id);
            }
          }
        }
      }
    }
    final ready =
        state.phase == PlaylistImportPhase.ready ||
        _xtreamProfile != null ||
        (persistedLibrary?.sources.isNotEmpty ?? false);
    return Scaffold(
      body: SafeArea(
        child: ready
            ? Column(
                children: <Widget>[
                  if (_playbackError case final message?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TviumSpacing.lg,
                        TviumSpacing.sm,
                        TviumSpacing.lg,
                        0,
                      ),
                      child: _InlineError(message: message),
                    ),
                  Expanded(
                    child: _LibraryView(
                      entries: entries,
                      epgSchedules: epgSchedules,
                      selectedGroup: _selectedGroup,
                      selectedEntry: _selectedEntry,
                      playbackEngine: _playbackEngine,
                      profileId: profileId,
                      favorites: overlays?.favorites ?? const {},
                      history: overlays?.history ?? const [],
                      sources: persistedLibrary?.sources ?? const [],
                      onGroupSelected: (group) =>
                          setState(() => _selectedGroup = group),
                      onEntrySelected: (entry) => _play(profileId, entry),
                      onFavoriteToggled: (entry) =>
                          _toggleFavorite(profileId, entry),
                      onProfileChanged: _resetProfileSession,
                      onSourcesRemoved: _removeOrphanedSources,
                      onAddPlaylist: () => _showAddPlaylist(controller),
                      onRenameSource: _renameSource,
                      onRemoveSource: (source) =>
                          _removeSource(profileId, source),
                      onImportEpgFile: _importEpgFile,
                      onImportEpgUrl: _importEpgUrl,
                      onRefreshSource: _refreshSource,
                      onRefreshSources: _refreshSources,
                      refreshIntervalFor: (source) => ref
                          .read(sourceRefreshScheduleProvider)
                          .intervalFor(source.id),
                      lastRefreshAttemptFor: (source) => ref
                          .read(sourceRefreshScheduleProvider)
                          .lastAttemptFor(source.id),
                      onRefreshIntervalChanged: (source, interval) => ref
                          .read(sourceRefreshScheduleProvider)
                          .setInterval(source.id, interval),
                      parentalConfigured: parentalPolicy != null,
                      parentalUnlocked: parentalUnlocked,
                      onSaveParentalPin: (pin, blockedContent) =>
                          _saveParentalPin(profileId, pin, blockedContent),
                      onUnlockParental: (pin) =>
                          _unlockParental(parentalPolicy, pin),
                    ),
                  ),
                ],
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
              Row(
                children: <Widget>[
                  TviumBrandLogo(
                    key: const ValueKey<String>('tvium-brand-logo'),
                    semanticLabel: strings.appTitle,
                    height: 36,
                  ),
                  const Spacer(),
                  ProfileSwitcher(
                    onProfileChanged: _resetProfileSession,
                    onSourcesRemoved: _removeOrphanedSources,
                  ),
                ],
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 600;
                    final cardWidth = compact ? double.infinity : 210.0;
                    final cards = <Widget>[
                      SourceActionCard(
                        key: const ValueKey<String>('m3u-url-action'),
                        title: strings.m3uUrl,
                        description: strings.analyzePlaylist,
                        icon: Icons.link_rounded,
                        focusNode: _urlActionFocus,
                        autofocus: !compact,
                        width: cardWidth,
                        onActivate: () => setState(() {
                          _showUrlField = true;
                          _showXtreamForm = false;
                        }),
                      ),
                      SourceActionCard(
                        key: const ValueKey<String>('m3u-file-action'),
                        title: strings.importLocalM3u,
                        description: '.m3u · .m3u8',
                        icon: Icons.folder_open_rounded,
                        focusNode: _fileActionFocus,
                        width: cardWidth,
                        onActivate: () => unawaited(_pickLocalFile(controller)),
                      ),
                      SourceActionCard(
                        key: const ValueKey<String>('xtream-action'),
                        title: strings.xtreamCodes,
                        description: strings.connectProvider,
                        icon: Icons.dns_outlined,
                        focusNode: _xtreamActionFocus,
                        width: cardWidth,
                        onActivate: () => setState(() {
                          _showUrlField = false;
                          _showXtreamForm = true;
                        }),
                      ),
                    ];
                    if (compact) {
                      return Column(spacing: TviumSpacing.sm, children: cards);
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(spacing: TviumSpacing.sm, children: cards),
                    );
                  },
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
                        obscureText: _obscureUrl,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: strings.urlHint,
                          prefixIcon: const Icon(Icons.language_rounded),
                          suffixIcon: IconButton(
                            key: const ValueKey<String>(
                              'url-visibility-toggle',
                            ),
                            tooltip: _obscureUrl
                                ? strings.showPlaylistUrl
                                : strings.hidePlaylistUrl,
                            onPressed: () =>
                                setState(() => _obscureUrl = !_obscureUrl),
                            icon: Icon(
                              _obscureUrl
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
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
              if (_showXtreamForm) ...<Widget>[
                const SizedBox(height: TviumSpacing.lg),
                XtreamConnectionForm(
                  onPlaylistAdded: (profile) =>
                      unawaited(_openXtreamLibrary(profile)),
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
    unawaited(_importM3uUrl(controller, uri));
  }

  Future<void> _pickLocalFile(PlaylistImportController controller) async {
    final strings = AppLocalizations.of(context);
    try {
      final source = await ref.read(localPlaylistPickerProvider)();
      if (source != null) {
        final descriptor = source is M3uFileSource
            ? M3uSourceDescriptor.file(
                displayName: source.displayName ?? _fileName(source.path),
                location: source.path,
                identityLocation: source.originalPath,
              )
            : null;
        await controller.importSource(source, descriptor: descriptor);
        ref.invalidate(libraryBootstrapProvider);
      }
    } on Object {
      controller.reportValidationFailure(strings.filePickerFailed);
    }
  }

  Future<void> _showAddPlaylist(PlaylistImportController controller) =>
      showDialog<void>(
        context: context,
        builder: (context) => _AddPlaylistDialog(
          onLocalM3u: () => _pickLocalFile(controller),
          onM3uUrl: (uri) => _importM3uUrl(controller, uri),
          onXtreamAdded: _openXtreamLibrary,
        ),
      );

  Future<void> _importM3uUrl(
    PlaylistImportController controller,
    Uri uri,
  ) async {
    final candidate = detectXtreamM3u(uri);
    if (candidate != null) {
      try {
        final profile = await ref
            .read(xtreamConnectionServiceProvider)
            .addPlaylist(
              XtreamConnectionInput(
                profileName: uri.host,
                serverUri: candidate.serverUri,
                credentials: candidate.credentials,
              ),
            );
        if (mounted) await _openXtreamLibrary(profile);
        return;
      } on Object {
        // A URL shape is only a hint. Keep the original M3U path on failure.
      }
    }
    await controller.importSource(
      M3uUrlSource(uri),
      descriptor: M3uSourceDescriptor.url(
        displayName: uri.host,
        location: uri.toString(),
      ),
    );
    ref.invalidate(libraryBootstrapProvider);
  }

  Future<void> _renameSource(IptvSource source, String name) async {
    final repository = await ref.read(libraryRepositoryProvider.future);
    await repository.renameSource(source.id, name);
    ref.invalidate(libraryBootstrapProvider);
  }

  Future<void> _removeSource(String profileId, IptvSource source) async {
    final repository = await ref.read(libraryRepositoryProvider.future);
    final orphan = await repository.unlinkSource(profileId, source.id);
    if (orphan != null) await _removeOrphanedSources(<IptvSource>[orphan]);
    _resetProfileSession();
    ref.invalidate(libraryBootstrapProvider);
  }

  Future<void> _removeOrphanedSources(List<IptvSource> sources) async {
    final m3uStore = SecureM3uSourceStore();
    final xtreamStore = SecureXtreamProfileStore();
    final refreshSchedule = ref.read(sourceRefreshScheduleProvider);
    for (final source in sources) {
      final descriptor = await m3uStore.read(source.secretReference);
      if (descriptor != null && descriptor.kind == M3uSourceKind.file) {
        await deleteRetainedLocalPlaylist(descriptor.location);
      }
      await m3uStore.delete(source.secretReference);
      await xtreamStore.delete(source.secretReference);
      try {
        await ArtworkReferenceStore().delete(source.id);
      } on Object {
        // Optional artwork cleanup does not block source removal.
      }
      try {
        await refreshSchedule.remove(source.id);
      } on Object {
        // Source removal must not depend on deleting optional schedule data.
      }
    }
  }

  String _fileName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty || parts.last.isEmpty ? 'Local playlist' : parts.last;
  }

  Future<void> _openXtreamLibrary(XtreamAddedProfile profile) async {
    ref.invalidate(libraryBootstrapProvider);
    final targetProfileId = profile.targetProfileId;
    if (targetProfileId != null) {
      final repository = await ref.read(libraryRepositoryProvider.future);
      final activeProfile = await repository.activeProfile();
      if (!mounted || activeProfile.id != targetProfileId) {
        return;
      }
    }
    setState(() {
      _xtreamProfile = profile;
      _selectedGroup = null;
      _selectedEntry = null;
      _playbackError = null;
      _showXtreamForm = false;
    });
  }

  Future<String> _importEpgFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xml', 'xmltv'],
      );
      if (file == null) return 'Import cancelled.';
      final bytes = await file.readAsBytes();
      return await _importEpg(EpgBytesSource.local(bytes));
    } on Object {
      return 'The programme guide could not be read.';
    }
  }

  Future<String> _importEpgUrl(Uri uri) => _importEpg(EpgHttpsSource(uri));

  Future<String> _importEpg(EpgSource source) async {
    final library = await ref.read(libraryRepositoryProvider.future);
    final EpgRepository epgRepository;
    if (library case final EpgRepository repository) {
      epgRepository = repository;
    } else {
      return 'Programme guide storage is unavailable on this device.';
    }
    final controller = EpgImportController(
      epgRepository: epgRepository,
      libraryRepository: library,
    );
    final playlistState = ref.read(playlistImportControllerProvider).state;
    await controller.importSource(
      source,
      additionalEntries: _sessionEpgEntries(playlistState),
    );
    if (controller.state.phase != EpgImportPhase.ready) {
      return controller.state.message ??
          'The programme guide could not be imported.';
    }
    ref.invalidate(epgNowNextProvider);
    return 'Programme guide imported: ${controller.state.programmeCount} programmes, '
        '${controller.state.matchedChannelCount} matched channels.';
  }

  Future<String> _refreshSources() async {
    try {
      final repository = await ref.read(libraryRepositoryProvider.future);
      final profile = await repository.activeProfile();
      final sources = await repository.sourcesForProfile(profile.id);
      if (sources.isEmpty) return 'No connected source to refresh.';
      final service = ref.read(xtreamConnectionServiceProvider);
      final XtreamSourceRefreshService? refreshService =
          service is XtreamSourceRefreshService
          ? service as XtreamSourceRefreshService
          : null;
      var added = 0;
      var changed = 0;
      var removed = 0;
      var m3uRefreshed = 0;
      var upgraded = 0;
      final m3uRefresh = ref.read(m3uSourceRefreshProvider);
      for (final source in sources) {
        if (await _tryUpgradeM3uSource(source)) {
          upgraded++;
          continue;
        }
        final refreshedEntries = await m3uRefresh.refresh(
          source.secretReference,
        );
        if (refreshedEntries != null) {
          m3uRefreshed++;
          await _recordRefreshAttempt(source.id);
          continue;
        }
        if (refreshService == null) {
          return 'Some connected sources cannot be refreshed in this build.';
        }
        final result = await refreshService.refreshSource(source.id);
        await _recordRefreshAttempt(source.id);
        added += result.addedCount;
        changed += result.changedCount;
        removed += result.removedCount;
      }
      ref.invalidate(libraryBootstrapProvider);
      ref.invalidate(epgNowNextProvider);
      return 'Sources refreshed: $m3uRefreshed M3U, $upgraded upgraded, $added added, '
          '$changed updated, $removed removed.';
    } on Object {
      return 'Sources could not be refreshed. The existing library was kept.';
    }
  }

  Future<String> _refreshSource(IptvSource source) async {
    try {
      if (await _tryUpgradeM3uSource(source)) {
        return 'Playlist upgraded to Xtream. The library is ready.';
      }
      final refreshedEntries = await ref
          .read(m3uSourceRefreshProvider)
          .refresh(source.secretReference);
      if (refreshedEntries != null) {
        await _recordRefreshAttempt(source.id);
        ref.invalidate(libraryBootstrapProvider);
        ref.invalidate(epgNowNextProvider);
        return 'Playlist refreshed: M3U catalog updated.';
      }
      final service = ref.read(xtreamConnectionServiceProvider);
      if (service is! XtreamSourceRefreshService) {
        return 'This playlist cannot be refreshed in this build.';
      }
      final refreshService = service as XtreamSourceRefreshService;
      final result = await refreshService.refreshSource(source.id);
      await _recordRefreshAttempt(source.id);
      ref.invalidate(libraryBootstrapProvider);
      ref.invalidate(epgNowNextProvider);
      return 'Playlist refreshed: ${result.addedCount} added, '
          '${result.changedCount} updated, ${result.removedCount} removed.';
    } on Object {
      return 'Playlist refresh failed. The existing library was kept.';
    }
  }

  Future<bool> _tryUpgradeM3uSource(IptvSource source) async {
    final descriptor = await SecureM3uSourceStore().read(
      source.secretReference,
    );
    if (descriptor == null || descriptor.kind != M3uSourceKind.url) {
      return false;
    }
    final uri = Uri.tryParse(descriptor.location);
    final candidate = uri == null ? null : detectXtreamM3u(uri);
    if (candidate == null) return false;
    try {
      await ref
          .read(xtreamConnectionServiceProvider)
          .addPlaylist(
            XtreamConnectionInput(
              profileName: source.displayName,
              serverUri: candidate.serverUri,
              credentials: candidate.credentials,
            ),
          );
      final repository = await ref.read(libraryRepositoryProvider.future);
      final active = await repository.activeProfile();
      final orphan = await repository.unlinkSource(active.id, source.id);
      if (orphan != null) await _removeOrphanedSources(<IptvSource>[orphan]);
      ref.invalidate(libraryBootstrapProvider);
      ref.invalidate(epgNowNextProvider);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _refreshDueSources(List<IptvSource> sources) async {
    final sourceById = {for (final source in sources) source.id: source};
    final runner = _refreshRunner ??= SourceRefreshRunner(
      ref.read(sourceRefreshScheduleProvider),
    );
    await runner.check(sourceById.keys, (sourceId) async {
      if (!mounted) return;
      final source = sourceById[sourceId];
      if (source != null) await _refreshSource(source);
    });
  }

  Future<void> _checkDueSources() async {
    if (!mounted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    try {
      final snapshot = await ref.read(libraryBootstrapProvider.future);
      if (mounted) await _refreshDueSources(snapshot.sources);
    } on Object {
      // The cached catalog remains available when a background check fails.
    }
  }

  Future<void> _recordRefreshAttempt(String sourceId) async {
    try {
      await ref.read(sourceRefreshScheduleProvider).markAttempt(sourceId);
    } on Object {
      // A successful catalog refresh remains successful if settings storage fails.
    }
  }

  List<PersistedMediaEntry> _sessionEpgEntries(PlaylistImportState state) {
    if (state.phase != PlaylistImportPhase.ready) return const [];
    return [
      for (final entry in state.entries)
        PersistedMediaEntry(
          id: entry.id,
          playlistId: 'session.m3u',
          sourceReference: 'session-only',
          originalName: entry.originalName,
          displayName: entry.originalName,
          groupName: entry.groupTitle,
          kind: entry.kind,
          epgChannelId: entry.attributes['tvg-id'],
        ),
    ];
  }

  void _resetProfileSession() {
    final engine = _playbackEngine;
    setState(() {
      _profileSessionGeneration += 1;
      _xtreamProfile = null;
      _selectedGroup = null;
      _selectedEntry = null;
      _playbackEngine = null;
      _playbackError = null;
      _unlockedParentalProfileId = null;
    });
    if (engine != null) {
      unawaited(engine.dispose());
    }
  }

  List<_LibraryEntry> _libraryEntries(
    PlaylistImportState state,
    LibrarySnapshot? persistedLibrary,
  ) {
    final xtreamProfile = _xtreamProfile;
    if (xtreamProfile == null) {
      if (persistedLibrary?.sources.isNotEmpty ?? false) {
        return persistedLibrary!.entries
            .map(
              (entry) => _LibraryEntry.fromPersisted(
                entry,
                persistedLibrary.artwork[entry.playlistId]?[entry.id],
              ),
            )
            .toList(growable: false);
      }
      if (state.phase == PlaylistImportPhase.ready) {
        return state.entries.map(_LibraryEntry.fromM3u).toList(growable: false);
      }
      return (persistedLibrary?.entries ?? const <PersistedMediaEntry>[])
          .map(
            (entry) => _LibraryEntry.fromPersisted(
              entry,
              persistedLibrary?.artwork[entry.playlistId]?[entry.id],
            ),
          )
          .toList(growable: false);
    }

    final catalog = xtreamProfile.catalog;
    final categories = <String, String>{
      for (final category in <XtreamCategory>[
        ...catalog.liveCategories,
        ...catalog.movieCategories,
        ...catalog.seriesCategories,
      ])
        category.id: category.name,
    };
    return <_LibraryEntry>[
      for (final item in <XtreamMediaItem>[
        ...catalog.liveStreams,
        ...catalog.movies,
      ])
        _LibraryEntry.fromXtream(
          profileId: xtreamProfile.profileId,
          item: item,
          group: item.categoryId == null ? null : categories[item.categoryId],
        ),
      for (final series in catalog.series)
        _LibraryEntry.fromSeries(
          series,
          profileId: xtreamProfile.profileId,
          group: series.categoryId == null
              ? null
              : categories[series.categoryId],
        ),
    ];
  }

  Future<void> _play(String profileId, _LibraryEntry entry) async {
    final sessionGeneration = _profileSessionGeneration;
    try {
      _activePlaybackLocator = null;
      _activePlaybackKind = null;
      final locator = entry.locator(profileId);
      final overlays = await ref.read(
        userOverlaysControllerProvider(profileId).future,
      );
      final previous = overlays.history
          .where((item) => item.media == locator)
          .firstOrNull;
      final uri = await entry.resolveUri(
        ref.read(xtreamConnectionServiceProvider),
        ref.read(m3uPlaybackResolverProvider),
      );
      if (uri == null || sessionGeneration != _profileSessionGeneration) {
        return;
      }
      var engine = _playbackEngine;
      if (engine == null) {
        engine = ref.read(playbackEngineFactoryProvider)();
        _playbackEngine = engine;
        _playbackStateSubscription = engine.state.listen(_checkpointPlayback);
      }
      setState(() {
        _selectedEntry = entry;
        _playbackError = null;
      });
      await engine.open(MediaSource(uri: uri, title: entry.name));
      if (sessionGeneration != _profileSessionGeneration) return;
      final resumePosition = _resumePositionFor(previous);
      if (resumePosition > Duration.zero) {
        await engine.seek(resumePosition);
      }
      await engine.play();
      if (sessionGeneration != _profileSessionGeneration) return;
      await ref
          .read(userOverlaysControllerProvider(profileId).notifier)
          .recordPlayback(
            PlaybackHistoryEntry(
              media: locator,
              lastPlayedAtUtc: DateTime.now().toUtc(),
              position: resumePosition,
              duration: previous?.duration ?? Duration.zero,
            ),
          );
      _activePlaybackLocator = locator;
      _activePlaybackKind = entry.kind;
      _lastCheckpointPosition = resumePosition;
      if (mounted) {
        setState(() {});
      }
    } on Object {
      if (mounted) {
        setState(() {
          _selectedEntry = null;
          _playbackError = AppLocalizations.of(context).playbackUnavailable;
        });
      }
    }
  }

  void _checkpointPlayback(PlaybackState state) {
    final locator = _activePlaybackLocator;
    if (!mounted ||
        locator == null ||
        _activePlaybackKind == MediaKind.live ||
        state.duration <= Duration.zero) {
      return;
    }
    final delta = (state.position - _lastCheckpointPosition).abs();
    final force =
        state.phase == PlaybackPhase.paused ||
        state.phase == PlaybackPhase.ended;
    if (!force && delta < const Duration(seconds: 15)) return;
    _lastCheckpointPosition = state.position;
    final checkpoint = PlaybackHistoryEntry(
      media: locator,
      lastPlayedAtUtc: DateTime.now().toUtc(),
      position: state.position,
      duration: state.duration,
    );
    _checkpointTail = _checkpointTail.then((_) async {
      if (!mounted) return;
      await ref
          .read(
            userOverlaysControllerProvider(checkpoint.media.profileId).notifier,
          )
          .recordPlayback(checkpoint);
    });
    unawaited(_checkpointTail);
  }

  Future<void> _toggleFavorite(String profileId, _LibraryEntry entry) => ref
      .read(userOverlaysControllerProvider(profileId).notifier)
      .toggleFavorite(entry.locator(profileId));

  Future<String> _saveParentalPin(
    String profileId,
    String pin,
    Set<String> blockedContent,
  ) async {
    try {
      final digest = await compute(_hashParentalPin, pin);
      await ref
          .read(userOverlaysControllerProvider(profileId).notifier)
          .saveParentalPolicy(
            ParentalPolicy(
              profileId: profileId,
              pinDigest: digest,
              blockedContent: blockedContent,
            ),
          );
      if (mounted) setState(() => _unlockedParentalProfileId = null);
      return 'Parental controls enabled.';
    } on ArgumentError {
      return 'Use a PIN containing 4 to 8 digits.';
    }
  }

  Future<String> _unlockParental(ParentalPolicy? policy, String pin) async {
    if (policy == null) return 'Set a parental PIN first.';
    final verified = await compute(_verifyParentalPin, (
      pin: pin,
      digest: policy.pinDigest,
    ));
    if (!verified) return 'Incorrect PIN.';
    if (mounted) {
      setState(() => _unlockedParentalProfileId = policy.profileId);
    }
    return 'Protected content unlocked for this session.';
  }

  bool _blockedByParentalPolicy(
    _LibraryEntry entry,
    Set<String> blockedContent,
  ) {
    final group = entry.group?.trim().toLowerCase();
    final value = '${entry.group ?? ''} ${entry.name}'.toLowerCase();
    if (blockedContent.contains('adult') &&
        const <String>['adult', 'xxx', '18+', 'porn'].any(value.contains)) {
      return true;
    }
    return group != null && blockedContent.contains(group);
  }
}

String _hashParentalPin(String pin) => ParentalPinService().hash(pin);

bool _verifyParentalPin(({String pin, String digest}) input) =>
    ParentalPinService().verify(input.pin, input.digest);

final class _AddPlaylistDialog extends StatefulWidget {
  const _AddPlaylistDialog({
    required this.onLocalM3u,
    required this.onM3uUrl,
    required this.onXtreamAdded,
  });

  final Future<void> Function() onLocalM3u;
  final Future<void> Function(Uri uri) onM3uUrl;
  final Future<void> Function(XtreamAddedProfile profile) onXtreamAdded;

  @override
  State<_AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

final class _AddPlaylistDialogState extends State<_AddPlaylistDialog> {
  final _urlController = TextEditingController();
  var _mode = _AddPlaylistMode.choices;
  String? _validation;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add playlist'),
    content: SizedBox(
      width: 520,
      child: switch (_mode) {
        _AddPlaylistMode.choices => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const ValueKey('add-local-m3u'),
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Import local M3U'),
              onTap: () async {
                Navigator.of(context).pop();
                await widget.onLocalM3u();
              },
            ),
            ListTile(
              key: const ValueKey('add-m3u-url'),
              leading: const Icon(Icons.link_rounded),
              title: const Text('Add M3U URL'),
              onTap: () => setState(() => _mode = _AddPlaylistMode.url),
            ),
            ListTile(
              key: const ValueKey('add-xtream'),
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Connect Xtream Codes'),
              onTap: () => setState(() => _mode = _AddPlaylistMode.xtream),
            ),
          ],
        ),
        _AddPlaylistMode.url => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const ValueKey('add-m3u-url-field'),
              controller: _urlController,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'M3U URL',
                errorText: _validation,
              ),
            ),
            const SizedBox(height: TviumSpacing.md),
            FilledButton(
              onPressed: _submitUrl,
              child: const Text('Add playlist'),
            ),
          ],
        ),
        _AddPlaylistMode.xtream => XtreamConnectionForm(
          onPlaylistAdded: (profile) async {
            Navigator.of(context).pop();
            await widget.onXtreamAdded(profile);
          },
        ),
      },
    ),
    actions: <Widget>[
      if (_mode != _AddPlaylistMode.choices)
        TextButton(
          onPressed: () => setState(() => _mode = _AddPlaylistMode.choices),
          child: const Text('Back'),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );

  Future<void> _submitUrl() async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _validation = 'Enter a valid HTTP or HTTPS URL.');
      return;
    }
    Navigator.of(context).pop();
    await widget.onM3uUrl(uri);
  }
}

enum _AddPlaylistMode { choices, url, xtream }

final class _LibraryView extends ConsumerStatefulWidget {
  const _LibraryView({
    required this.entries,
    required this.epgSchedules,
    required this.selectedGroup,
    required this.selectedEntry,
    required this.playbackEngine,
    required this.profileId,
    required this.favorites,
    required this.history,
    required this.sources,
    required this.onGroupSelected,
    required this.onEntrySelected,
    required this.onFavoriteToggled,
    required this.onProfileChanged,
    required this.onSourcesRemoved,
    required this.onAddPlaylist,
    required this.onRenameSource,
    required this.onRemoveSource,
    required this.onImportEpgFile,
    required this.onImportEpgUrl,
    required this.onRefreshSource,
    required this.onRefreshSources,
    required this.refreshIntervalFor,
    required this.lastRefreshAttemptFor,
    required this.onRefreshIntervalChanged,
    required this.parentalConfigured,
    required this.parentalUnlocked,
    required this.onSaveParentalPin,
    required this.onUnlockParental,
  });

  final List<_LibraryEntry> entries;
  final Map<String, EpgNowNext?> epgSchedules;
  final String? selectedGroup;
  final _LibraryEntry? selectedEntry;
  final PlaybackEngine? playbackEngine;
  final String profileId;
  final Set<MediaLocator> favorites;
  final List<PlaybackHistoryEntry> history;
  final List<IptvSource> sources;
  final ValueChanged<String?> onGroupSelected;
  final ValueChanged<_LibraryEntry> onEntrySelected;
  final ValueChanged<_LibraryEntry> onFavoriteToggled;
  final VoidCallback onProfileChanged;
  final Future<void> Function(List<IptvSource> sources) onSourcesRemoved;
  final Future<void> Function() onAddPlaylist;
  final Future<void> Function(IptvSource source, String name) onRenameSource;
  final Future<void> Function(IptvSource source) onRemoveSource;
  final Future<String> Function() onImportEpgFile;
  final Future<String> Function(Uri uri) onImportEpgUrl;
  final Future<String> Function(IptvSource source) onRefreshSource;
  final Future<String> Function() onRefreshSources;
  final Future<SourceRefreshInterval> Function(IptvSource source)
  refreshIntervalFor;
  final Future<DateTime?> Function(IptvSource source) lastRefreshAttemptFor;
  final Future<void> Function(IptvSource source, SourceRefreshInterval interval)
  onRefreshIntervalChanged;
  final bool parentalConfigured;
  final bool parentalUnlocked;
  final Future<String> Function(String pin, Set<String> blockedContent)
  onSaveParentalPin;
  final Future<String> Function(String pin) onUnlockParental;

  @override
  ConsumerState<_LibraryView> createState() => _LibraryViewState();
}

final class _LibraryViewState extends ConsumerState<_LibraryView> {
  var _destination = _CatalogDestination.home;
  String? _selectedCountryCode;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF071A2A),
                Color(0xFF06101B),
                Color(0xFF03080E),
              ],
            ),
          ),
          child: Column(
            children: <Widget>[
              _CatalogHeader(
                wide: wide,
                destination: _destination,
                searching: _searching,
                onDestinationSelected: _selectDestination,
                onSearch: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
                onSettings: () => showSettingsPages(
                  context,
                  openSection: (section) => showLibrarySettings(
                    context,
                    section: section,
                    configured: ref.read(metadataGatewayProvider) != null,
                    onImportEpgFile: widget.onImportEpgFile,
                    onImportEpgUrl: widget.onImportEpgUrl,
                    onRefreshSource: widget.onRefreshSource,
                    onRefreshSources: widget.onRefreshSources,
                    refreshIntervalFor: widget.refreshIntervalFor,
                    lastRefreshAttemptFor: widget.lastRefreshAttemptFor,
                    onRefreshIntervalChanged: widget.onRefreshIntervalChanged,
                    sources: widget.sources,
                    onAddPlaylist: widget.onAddPlaylist,
                    onRenameSource: widget.onRenameSource,
                    onRemoveSource: widget.onRemoveSource,
                    parentalConfigured: widget.parentalConfigured,
                    parentalUnlocked: widget.parentalUnlocked,
                    availableParentalCategories:
                        widget.entries
                            .map((entry) => entry.group?.trim())
                            .whereType<String>()
                            .where((group) => group.isNotEmpty)
                            .toSet()
                            .toList()
                          ..sort(),
                    initialBlockedContent:
                        ref
                            .watch(
                              userOverlaysControllerProvider(widget.profileId),
                            )
                            .asData
                            ?.value
                            .parentalPolicy
                            ?.blockedContent ??
                        const {'adult'},
                    onSaveParentalPin: widget.onSaveParentalPin,
                    onUnlockParental: widget.onUnlockParental,
                  ),
                ),
                onProfileChanged: widget.onProfileChanged,
                onSourcesRemoved: widget.onSourcesRemoved,
              ),
              if (_searching && _destination != _CatalogDestination.home)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TviumSpacing.lg,
                    0,
                    TviumSpacing.lg,
                    TviumSpacing.sm,
                  ),
                  child: TextField(
                    key: const ValueKey('library-search'),
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search this section',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: switch (_destination) {
                    _CatalogDestination.home => _DestinationHome(
                      key: const ValueKey('page-home'),
                      entries: entries,
                      profileId: widget.profileId,
                      history: widget.history,
                      onSelected: _selectDestination,
                      onPlay: widget.onEntrySelected,
                      onDetails: (entry) => _showTitleDetails(
                        context,
                        entry,
                        widget.onEntrySelected,
                        ref.read(xtreamConnectionServiceProvider),
                      ),
                    ),
                    _CatalogDestination.live => _CatalogPage(
                      key: const ValueKey('page-live'),
                      destination: _destination,
                      entries: _entriesFor(_destination),
                      epgSchedules: widget.epgSchedules,
                      query: _query,
                      selectedGroup: widget.selectedGroup,
                      selectedEntry: widget.selectedEntry,
                      playbackEngine: widget.playbackEngine,
                      onGroupSelected: widget.onGroupSelected,
                      selectedCountryCode: _selectedCountryCode,
                      onCountrySelected: (code) {
                        setState(() => _selectedCountryCode = code);
                        widget.onGroupSelected(null);
                      },
                      onPlay: widget.onEntrySelected,
                      profileId: widget.profileId,
                      favorites: widget.favorites,
                      history: widget.history,
                      onFavoriteToggled: widget.onFavoriteToggled,
                    ),
                    _CatalogDestination.movies => _CatalogPage(
                      key: const ValueKey('page-movies'),
                      destination: _destination,
                      entries: _entriesFor(_destination),
                      epgSchedules: widget.epgSchedules,
                      query: _query,
                      selectedGroup: widget.selectedGroup,
                      selectedEntry: widget.selectedEntry,
                      playbackEngine: widget.playbackEngine,
                      onGroupSelected: widget.onGroupSelected,
                      onPlay: widget.onEntrySelected,
                      profileId: widget.profileId,
                      favorites: widget.favorites,
                      history: widget.history,
                      onFavoriteToggled: widget.onFavoriteToggled,
                    ),
                    _CatalogDestination.shows => _CatalogPage(
                      key: const ValueKey('page-shows'),
                      destination: _destination,
                      entries: _entriesFor(_destination),
                      epgSchedules: widget.epgSchedules,
                      query: _query,
                      selectedGroup: widget.selectedGroup,
                      selectedEntry: widget.selectedEntry,
                      playbackEngine: widget.playbackEngine,
                      onGroupSelected: widget.onGroupSelected,
                      onPlay: widget.onEntrySelected,
                      profileId: widget.profileId,
                      favorites: widget.favorites,
                      history: widget.history,
                      onFavoriteToggled: widget.onFavoriteToggled,
                    ),
                  },
                ),
              ),
              if (!wide)
                NavigationBar(
                  key: const ValueKey('compact-navigation'),
                  selectedIndex: _destination.index,
                  onDestinationSelected: (index) =>
                      _selectDestination(_CatalogDestination.values[index]),
                  destinations: const <NavigationDestination>[
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.live_tv_outlined),
                      selectedIcon: Icon(Icons.live_tv_rounded),
                      label: 'Live TV',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie_rounded),
                      label: 'Movies',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tv_outlined),
                      selectedIcon: Icon(Icons.tv_rounded),
                      label: 'TV Shows',
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  List<_LibraryEntry> _entriesFor(_CatalogDestination destination) {
    final entries = widget.entries
        .where(
          (entry) => switch (destination) {
            _CatalogDestination.live => entry.kind == MediaKind.live,
            _CatalogDestination.movies => entry.kind == MediaKind.movie,
            _CatalogDestination.shows => entry.kind == MediaKind.episode,
            _CatalogDestination.home => false,
          },
        )
        .toList(growable: false);
    return destination == _CatalogDestination.shows
        ? _groupSeriesEntries(entries)
        : entries;
  }

  void _selectDestination(_CatalogDestination destination) {
    setState(() {
      _destination = destination;
      _selectedCountryCode = null;
      _query = '';
      _searching = false;
    });
    widget.onGroupSelected(null);
  }
}

enum _CatalogDestination { home, live, movies, shows }

final class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({
    required this.wide,
    required this.destination,
    required this.searching,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onSettings,
    required this.onProfileChanged,
    required this.onSourcesRemoved,
  });

  final bool wide;
  final _CatalogDestination destination;
  final bool searching;
  final ValueChanged<_CatalogDestination> onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onProfileChanged;
  final Future<void> Function(List<IptvSource> sources) onSourcesRemoved;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final actions = _HeaderActions(
      searchTooltip: strings.search,
      settingsTooltip: strings.settings,
      searchEnabled: destination != _CatalogDestination.home,
      searching: searching,
      onSearch: onSearch,
      onSettings: onSettings,
      onProfileChanged: onProfileChanged,
      onSourcesRemoved: onSourcesRemoved,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : TviumSpacing.md,
        TviumSpacing.md,
        wide ? 32 : TviumSpacing.md,
        TviumSpacing.sm,
      ),
      child: wide
          ? SizedBox(
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14283B).withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(TviumRadius.pill),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final item in const <_CatalogDestination>[
                          _CatalogDestination.home,
                          _CatalogDestination.live,
                        ])
                          _HeaderDestination(
                            destination: item,
                            selected: destination == item,
                            onPressed: () => onDestinationSelected(item),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: TviumBrandLogo(
                            key: const ValueKey<String>('tvium-brand-logo'),
                            semanticLabel: strings.appTitle,
                            height: 38,
                          ),
                        ),
                        for (final item in const <_CatalogDestination>[
                          _CatalogDestination.movies,
                          _CatalogDestination.shows,
                        ])
                          _HeaderDestination(
                            destination: item,
                            selected: destination == item,
                            onPressed: () => onDestinationSelected(item),
                          ),
                      ],
                    ),
                  ),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              ),
            )
          : Row(
              children: <Widget>[
                TviumBrandLogo(
                  key: const ValueKey<String>('tvium-brand-logo'),
                  semanticLabel: strings.appTitle,
                  height: 30,
                ),
                const Spacer(),
                actions,
              ],
            ),
    );
  }
}

final class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.searchTooltip,
    required this.settingsTooltip,
    required this.searchEnabled,
    required this.searching,
    required this.onSearch,
    required this.onSettings,
    required this.onProfileChanged,
    required this.onSourcesRemoved,
  });

  final String searchTooltip;
  final String settingsTooltip;
  final bool searchEnabled;
  final bool searching;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onProfileChanged;
  final Future<void> Function(List<IptvSource> sources) onSourcesRemoved;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: searchTooltip,
          onPressed: searchEnabled ? onSearch : null,
          isSelected: searching,
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          tooltip: settingsTooltip,
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
        ProfileSwitcher(
          onProfileChanged: onProfileChanged,
          onSourcesRemoved: onSourcesRemoved,
        ),
      ],
    );
  }
}

final class _HeaderDestination extends StatelessWidget {
  const _HeaderDestination({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _CatalogDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        icon: Icon(_destinationIcon(destination), size: 20),
        label: Text(_destinationLabel(destination)),
      ),
    );
  }
}

final class _DestinationHome extends StatefulWidget {
  const _DestinationHome({
    super.key,
    required this.entries,
    required this.profileId,
    required this.history,
    required this.onSelected,
    required this.onPlay,
    required this.onDetails,
  });

  final List<_LibraryEntry> entries;
  final String profileId;
  final List<PlaybackHistoryEntry> history;
  final ValueChanged<_CatalogDestination> onSelected;
  final ValueChanged<_LibraryEntry> onPlay;
  final ValueChanged<_LibraryEntry> onDetails;

  @override
  State<_DestinationHome> createState() => _DestinationHomeState();
}

final class _DestinationHomeState extends State<_DestinationHome> {
  Timer? _heroTimer;
  var _heroIndex = 0;
  bool? _reduceHeroMotion;
  List<_LibraryEntry>? _countedEntries;
  var _showCount = 0;

  int _countShows(List<_LibraryEntry> entries) {
    if (!identical(_countedEntries, entries)) {
      _countedEntries = entries;
      _showCount = _groupSeriesEntries(
        entries
            .where((entry) => entry.kind == MediaKind.episode)
            .toList(growable: false),
      ).length;
    }
    return _showCount;
  }

  List<_LibraryEntry> get _heroEntries {
    final playable = widget.entries
        .where((entry) => entry.kind != MediaKind.live && entry.isPlayable)
        .toList(growable: false);
    return <_LibraryEntry>[
      ...playable.where((entry) => entry.imageUri?.hasScheme == true),
      ...playable.where((entry) => entry.imageUri?.hasScheme != true),
    ].take(5).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceHeroMotion != reduceMotion) {
      _reduceHeroMotion = reduceMotion;
      _startHeroTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _DestinationHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousIds = oldWidget.entries
        .map((entry) => entry.id)
        .join('\u0000');
    final currentIds = widget.entries.map((entry) => entry.id).join('\u0000');
    if (previousIds != currentIds) {
      _heroIndex = 0;
      _startHeroTimer();
    }
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_reduceHeroMotion != false || _heroEntries.length < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _heroIndex = (_heroIndex + 1) % _heroEntries.length);
    });
  }

  void _selectHero(int index) {
    final entries = _heroEntries;
    if (entries.isEmpty) return;
    final selected = index % entries.length;
    setState(
      () => _heroIndex = selected < 0 ? selected + entries.length : selected,
    );
    _startHeroTimer();
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final showCount = _countShows(entries);
    final destinations = const <_CatalogDestination>[
      _CatalogDestination.live,
      _CatalogDestination.movies,
      _CatalogDestination.shows,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TviumSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 720;
              final cards = <Widget>[
                for (final destination in destinations)
                  _DestinationCard(
                    key: ValueKey('destination-${destination.name}'),
                    destination: destination,
                    count: switch (destination) {
                      _CatalogDestination.live =>
                        entries
                            .where((entry) => entry.kind == MediaKind.live)
                            .length,
                      _CatalogDestination.movies =>
                        entries
                            .where((entry) => entry.kind == MediaKind.movie)
                            .length,
                      _CatalogDestination.shows => showCount,
                      _CatalogDestination.home => 0,
                    },
                    onPressed: () => widget.onSelected(destination),
                  ),
              ];
              final heroEntries = _heroEntries;
              final hero = heroEntries.isEmpty
                  ? null
                  : _HomeHero(
                      entry: heroEntries[_heroIndex % heroEntries.length],
                      entries: heroEntries,
                      selectedIndex: _heroIndex % heroEntries.length,
                      onSelected: _selectHero,
                      onPrevious: () => _selectHero(_heroIndex - 1),
                      onNext: () => _selectHero(_heroIndex + 1),
                      onPlay: widget.onPlay,
                      onDetails: widget.onDetails,
                    );
              final destinationCards = horizontal
                  ? SizedBox(
                      height: 240,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (
                            var index = 0;
                            index < cards.length;
                            index++
                          ) ...<Widget>[
                            Expanded(child: cards[index]),
                            if (index != cards.length - 1)
                              const SizedBox(width: TviumSpacing.md),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < cards.length;
                          index++
                        ) ...<Widget>[
                          SizedBox(height: 160, child: cards[index]),
                          if (index != cards.length - 1)
                            const SizedBox(height: TviumSpacing.md),
                        ],
                      ],
                    );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  destinationCards,
                  if (hero != null) ...<Widget>[
                    SizedBox(height: horizontal ? 48 : 28),
                    SizedBox(
                      height: horizontal
                          ? MediaQuery.sizeOf(context).height >= 760
                                ? 330
                                : 260
                          : 260,
                      child: hero,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.entry,
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPrevious,
    required this.onNext,
    required this.onPlay,
    required this.onDetails,
  });

  final _LibraryEntry entry;
  final List<_LibraryEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_LibraryEntry> onPlay;
  final ValueChanged<_LibraryEntry> onDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('home-hero'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: entries.length < 2
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -120) onNext();
              if (velocity > 120) onPrevious();
            },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TviumRadius.hero),
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          child: Stack(
            key: ValueKey('home-hero-${entry.id}'),
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset(
                'assets/destinations/hero-home.png',
                key: const ValueKey('home-hero-backdrop'),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: <Color>[
                      Color(0x22081422),
                      Color(0xE00A1B2B),
                      Color(0xFF06101B),
                    ],
                  ),
                ),
              ),
              if (entry.imageUri?.hasScheme == true &&
                  MediaQuery.sizeOf(context).width >= 920)
                Positioned(
                  key: const ValueKey('home-hero-poster'),
                  right: 84,
                  top: 48,
                  bottom: 30,
                  width: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: const Color(0x99071320),
                      child: ArtworkImage(
                        sourceId: entry.sourceId,
                        entryId: entry.id,
                        role: 'poster',
                        uri: entry.imageUri,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              _HomeHeroContent(
                entry: entry,
                entries: entries,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
                onPlay: onPlay,
                onDetails: onDetails,
              ),
              if (entries.length > 1) ...<Widget>[
                Positioned(
                  right: TviumSpacing.xs,
                  top: TviumSpacing.xs,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton.filledTonal(
                        key: const ValueKey('home-hero-previous'),
                        tooltip: 'Previous feature',
                        onPressed: onPrevious,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('home-hero-next'),
                        tooltip: 'Next feature',
                        onPressed: onNext,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _HomeHeroContent extends StatelessWidget {
  const _HomeHeroContent({
    required this.entry,
    required this.entries,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
    required this.onDetails,
  });

  final _LibraryEntry entry;
  final List<_LibraryEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<_LibraryEntry> onPlay;
  final ValueChanged<_LibraryEntry> onDetails;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 300 || constraints.maxWidth < 600;
        return Padding(
          padding: EdgeInsets.all(compact ? TviumSpacing.md : TviumSpacing.xl),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!compact) ...<Widget>[
                    Text(
                      entry.kind == MediaKind.movie
                          ? 'Featured movie'
                          : 'Featured series',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: TviumColors.accentDark),
                    ),
                    const SizedBox(height: TviumSpacing.xs),
                  ],
                  Text(
                    entry.displayName,
                    key: const ValueKey('home-hero-title'),
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displaySmall,
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: TviumSpacing.xs),
                    Text(
                      entry.group ?? 'Your library',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  SizedBox(height: compact ? TviumSpacing.sm : TviumSpacing.md),
                  Wrap(
                    spacing: TviumSpacing.sm,
                    runSpacing: TviumSpacing.xs,
                    children: <Widget>[
                      FilledButton.icon(
                        key: const ValueKey('home-hero-play'),
                        onPressed: () => onPlay(entry),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('home-hero-details'),
                        onPressed: () => onDetails(entry),
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('View details'),
                      ),
                    ],
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: TviumSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (var index = 0; index < entries.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: InkWell(
                              key: ValueKey('home-hero-page-$index'),
                              borderRadius: BorderRadius.circular(
                                TviumRadius.pill,
                              ),
                              onTap: () => onSelected(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: index == selectedIndex ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == selectedIndex
                                      ? TviumColors.accentDark
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(
                                    TviumRadius.pill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Duration _resumePositionFor(PlaybackHistoryEntry? previous) {
  if (previous == null ||
      previous.position < const Duration(seconds: 30) ||
      previous.duration <= Duration.zero ||
      previous.position.inMilliseconds * 10 >=
          previous.duration.inMilliseconds * 9) {
    return Duration.zero;
  }
  return previous.position;
}

final class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    super.key,
    required this.destination,
    required this.count,
    required this.onPressed,
  });

  final _CatalogDestination destination;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10283C),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        focusColor: Theme.of(context).colorScheme.primary
            .withValues(alpha: 0.18),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              switch (destination) {
                _CatalogDestination.live =>
                  'assets/destinations/hero-live-tv.png',
                _CatalogDestination.movies =>
                  'assets/destinations/hero-movies.png',
                _CatalogDestination.shows =>
                  'assets/destinations/hero-tv-shows.png',
                _CatalogDestination.home => 'assets/destinations/hero-home.png',
              },
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x2219C8E6), Color(0xF2071019)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TviumSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Icon(_destinationIcon(destination), size: 38),
                  const SizedBox(height: TviumSpacing.sm),
                  Text(
                    _destinationLabel(destination),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '$count ${count == 1 ? 'title' : 'titles'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CatalogPage extends ConsumerWidget {
  const _CatalogPage({
    super.key,
    required this.destination,
    required this.entries,
    required this.epgSchedules,
    required this.query,
    required this.selectedGroup,
    required this.selectedEntry,
    required this.playbackEngine,
    required this.onGroupSelected,
    this.selectedCountryCode,
    this.onCountrySelected,
    required this.onPlay,
    required this.profileId,
    required this.favorites,
    required this.history,
    required this.onFavoriteToggled,
  });

  final _CatalogDestination destination;
  final List<_LibraryEntry> entries;
  final Map<String, EpgNowNext?> epgSchedules;
  final String query;
  final String? selectedGroup;
  final _LibraryEntry? selectedEntry;
  final PlaybackEngine? playbackEngine;
  final ValueChanged<String?> onGroupSelected;
  final String? selectedCountryCode;
  final ValueChanged<String?>? onCountrySelected;
  final ValueChanged<_LibraryEntry> onPlay;
  final String profileId;
  final Set<MediaLocator> favorites;
  final List<PlaybackHistoryEntry> history;
  final ValueChanged<_LibraryEntry> onFavoriteToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unknownGroup = AppLocalizations.of(context).unknownGroup;
    final shortWindow = MediaQuery.sizeOf(context).height < 700;
    final countryByGroup = destination == _CatalogDestination.live
        ? <String?, LiveCountry?>{
            for (final group in entries.map((entry) => entry.group).toSet())
              group: countryForGroup(group),
          }
        : const <String?, LiveCountry?>{};
    final countries = destination == _CatalogDestination.live
        ? countriesForGroups(countryByGroup.keys)
        : const <LiveCountry>[];
    final activeCountryCode = countries.length < 2
        ? 'ALL'
        : selectedCountryCode == 'ALL' ||
              countries.any((country) => country.code == selectedCountryCode)
        ? selectedCountryCode!
        : countries.first.code;
    final countryEntries = activeCountryCode == 'ALL'
        ? entries
        : entries
              .where(
                (entry) =>
                    countryByGroup[entry.group]?.code == activeCountryCode,
              )
              .toList(growable: false);
    final groups =
        countryEntries
            .map((entry) => entry.group ?? unknownGroup)
            .toSet()
            .toList()
          ..sort();
    final visible = countryEntries
        .where((entry) {
          final inGroup =
              selectedGroup == null ||
              (entry.group ?? unknownGroup) == selectedGroup;
          final normalizedQuery = query.toLowerCase();
          return inGroup &&
              (normalizedQuery.isEmpty ||
                  entry.displayName.toLowerCase().contains(normalizedQuery));
        })
        .toList(growable: false);
    final showPlayer =
        selectedEntry != null &&
        switch (destination) {
          _CatalogDestination.live => selectedEntry!.kind == MediaKind.live,
          _CatalogDestination.movies => selectedEntry!.kind == MediaKind.movie,
          _CatalogDestination.shows => selectedEntry!.kind == MediaKind.episode,
          _CatalogDestination.home => false,
        };
    final liveChannels = destination == _CatalogDestination.live
        ? visible.where((entry) => entry.isPlayable).toList(growable: false)
        : const <_LibraryEntry>[];
    final selectedLiveLocator = selectedEntry?.locator(profileId);
    final selectedLiveIndex = selectedLiveLocator == null
        ? -1
        : liveChannels.indexWhere(
            (entry) => entry.locator(profileId) == selectedLiveLocator,
          );
    void zapChannel(int offset) {
      if (selectedLiveIndex < 0 || liveChannels.length < 2) return;
      final index =
          (selectedLiveIndex + offset + liveChannels.length) %
          liveChannels.length;
      onPlay(liveChannels[index]);
    }

    void openChannelSwitcher() =>
        _showChannelSwitcher(context, liveChannels, onPlay);

    final entriesByLocator = <MediaLocator, _LibraryEntry>{
      for (final entry in entries) ...<MediaLocator, _LibraryEntry>{
        entry.locator(profileId): entry,
        for (final episode in entry.seriesEpisodes)
          episode.locator(profileId): episode,
      },
    };
    final continueWatching =
        destination == _CatalogDestination.movies ||
            destination == _CatalogDestination.shows
        ? history
              .map((item) {
                final entry = entriesByLocator[item.media];
                return entry == null ||
                        entry.kind !=
                            (destination == _CatalogDestination.movies
                                ? MediaKind.movie
                                : MediaKind.episode) ||
                        !entry.isPlayable ||
                        _resumePositionFor(item) == Duration.zero
                    ? null
                    : (entry: entry, history: item);
              })
              .whereType<
                ({_LibraryEntry entry, PlaybackHistoryEntry history})
              >()
              .take(8)
              .toList(growable: false)
        : const <({_LibraryEntry entry, PlaybackHistoryEntry history})>[];
    final media = visible.isEmpty
        ? Center(child: Text(AppLocalizations.of(context).noItems))
        : destination == _CatalogDestination.live
        ? ListView.separated(
            key: const ValueKey('live-channel-list'),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: TviumSpacing.xs),
            itemBuilder: (context, index) {
              final entry = visible[index];
              return _LiveMediaRow(
                key: ValueKey('media-row-${entry.id}'),
                entry: entry,
                schedule: epgSchedules[entry.id],
                favorite: favorites.contains(entry.locator(profileId)),
                onFavorite: () => onFavoriteToggled(entry),
                onTap: entry.isPlayable ? () => onPlay(entry) : null,
              );
            },
          )
        : GridView.builder(
            key: const ValueKey('poster-grid'),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisSpacing: TviumSpacing.sm,
              crossAxisSpacing: TviumSpacing.sm,
              childAspectRatio: 0.62,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final entry = visible[index];
              return _MediaCard(
                key: index == 0 && destination == _CatalogDestination.movies
                    ? const ValueKey('media-card-movie')
                    : ValueKey('media-card-${entry.id}'),
                entry: entry,
                schedule: epgSchedules[entry.id],
                destination: destination,
                favorite: favorites.contains(entry.locator(profileId)),
                onFavorite: () => onFavoriteToggled(entry),
                onTap: () => _showTitleDetails(
                  context,
                  entry,
                  onPlay,
                  ref.read(xtreamConnectionServiceProvider),
                ),
              );
            },
          );
    final catalog = Column(
      children: <Widget>[
        if (continueWatching.isNotEmpty && !showPlayer) ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Continue watching',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: TviumSpacing.sm),
          SizedBox(
            height: shortWindow ? 86 : 110,
            child: ListView.separated(
              key: ValueKey(
                destination == _CatalogDestination.movies
                    ? 'movies-continue-watching'
                    : 'shows-continue-watching',
              ),
              scrollDirection: Axis.horizontal,
              itemCount: continueWatching.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: TviumSpacing.sm),
              itemBuilder: (context, index) {
                final item = continueWatching[index];
                final duration = item.history.duration.inMilliseconds;
                final progress = duration <= 0
                    ? 0.0
                    : (item.history.position.inMilliseconds / duration).clamp(
                        0.0,
                        1.0,
                      );
                return SizedBox(
                  width: 240,
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF102638),
                    child: InkWell(
                      onTap: () => onPlay(item.entry),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          _CatalogArtwork(
                            key: ValueKey('continue-artwork-${item.entry.id}'),
                            entry: item.entry,
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Color(0x2207111B),
                                  Color(0xF007111B),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(TviumSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item.entry.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.play_arrow_rounded),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                LinearProgressIndicator(
                                  key: ValueKey(
                                    'continue-progress-${item.entry.id}',
                                  ),
                                  value: progress,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: TviumSpacing.md),
        ],
        if (showPlayer) ...<Widget>[
          SizedBox(
            key: const ValueKey('catalog-player'),
            height: 210,
            child: _PlayerPanel(
              selectedEntry: selectedEntry,
              engine: playbackEngine,
              onOpenChannelSwitcher: liveChannels.isNotEmpty
                  ? openChannelSwitcher
                  : null,
              onPreviousChannel:
                  selectedLiveIndex >= 0 && liveChannels.length > 1
                  ? () => zapChannel(-1)
                  : null,
              onNextChannel: selectedLiveIndex >= 0 && liveChannels.length > 1
                  ? () => zapChannel(1)
                  : null,
            ),
          ),
          const SizedBox(height: TviumSpacing.md),
        ],
        Expanded(child: media),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TviumSpacing.lg,
        TviumSpacing.sm,
        TviumSpacing.lg,
        TviumSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (shortWindow)
            SizedBox(
              height: 42,
              child: Text(
                _destinationLabel(destination),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else
            SizedBox(
              height: MediaQuery.sizeOf(context).width >= 720 ? 132 : 94,
              child: _CatalogBanner(
                destination: destination,
                count: entries.length,
              ),
            ),
          const SizedBox(height: TviumSpacing.md),
          if (countries.length >= 2) ...<Widget>[
            SizedBox(
              height: 58,
              child: ListView(
                key: const ValueKey('live-country-rail'),
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final country in <LiveCountry?>[null, ...countries])
                    Padding(
                      padding: const EdgeInsets.only(right: TviumSpacing.sm),
                      child: ChoiceChip(
                        key: ValueKey('country-${country?.code ?? 'all'}'),
                        label: Text(
                          country == null
                              ? 'All countries'
                              : '${country.flag}  ${country.name}',
                        ),
                        selected: (country?.code ?? 'ALL') == activeCountryCode,
                        onSelected: (_) =>
                            onCountrySelected?.call(country?.code ?? 'ALL'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: TviumSpacing.xs),
          ],
          if (destination != _CatalogDestination.live &&
              groups.isNotEmpty) ...<Widget>[
            SizedBox(
              height: shortWindow ? 44 : 56,
              child: ListView.separated(
                key: const ValueKey('catalog-category-chips'),
                scrollDirection: Axis.horizontal,
                itemCount: groups.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TviumSpacing.sm),
                itemBuilder: (context, index) {
                  final group = index == 0 ? null : groups[index - 1];
                  return ChoiceChip(
                    label: Text(group ?? 'All categories'),
                    selected: group == selectedGroup,
                    onSelected: (_) => onGroupSelected(group),
                  );
                },
              ),
            ),
            const SizedBox(height: TviumSpacing.xs),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (destination != _CatalogDestination.live) return catalog;
                if (constraints.maxWidth >= 1100 &&
                    destination == _CatalogDestination.live &&
                    showPlayer) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        key: const ValueKey('catalog-group-sidebar'),
                        width: 220,
                        child: _GroupSidebar(
                          groups: groups,
                          selectedGroup: selectedGroup,
                          onSelected: onGroupSelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(child: media),
                      const SizedBox(width: TviumSpacing.md),
                      SizedBox(
                        key: const ValueKey('catalog-player'),
                        width: constraints.maxWidth * 0.32,
                        child: _PlayerPanel(
                          selectedEntry: selectedEntry,
                          engine: playbackEngine,
                          onOpenChannelSwitcher: liveChannels.isNotEmpty
                              ? openChannelSwitcher
                              : null,
                          onPreviousChannel:
                              selectedLiveIndex >= 0 && liveChannels.length > 1
                              ? () => zapChannel(-1)
                              : null,
                          onNextChannel:
                              selectedLiveIndex >= 0 && liveChannels.length > 1
                              ? () => zapChannel(1)
                              : null,
                        ),
                      ),
                    ],
                  );
                }
                if (constraints.maxWidth >= 720) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        key: const ValueKey('catalog-group-sidebar'),
                        width: 220,
                        child: _GroupSidebar(
                          groups: groups,
                          selectedGroup: selectedGroup,
                          onSelected: onGroupSelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(child: catalog),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DropdownButtonFormField<String?>(
                      key: const ValueKey('catalog-group-menu'),
                      isExpanded: true,
                      initialValue: selectedGroup,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_list_rounded),
                        labelText: 'Category',
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          child: Text('All categories'),
                        ),
                        for (final group in groups)
                          DropdownMenuItem<String?>(
                            value: group,
                            child: Text(
                              group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: onGroupSelected,
                    ),
                    const SizedBox(height: TviumSpacing.sm),
                    Expanded(child: catalog),
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

final class _CatalogBanner extends StatelessWidget {
  const _CatalogBanner({required this.destination, required this.count});

  final _CatalogDestination destination;
  final int count;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const ValueKey('catalog-page-banner'),
    borderRadius: BorderRadius.circular(TviumRadius.hero),
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          switch (destination) {
            _CatalogDestination.live => 'assets/destinations/hero-live-tv.png',
            _CatalogDestination.movies => 'assets/destinations/hero-movies.png',
            _CatalogDestination.shows =>
              'assets/destinations/hero-tv-shows.png',
            _CatalogDestination.home => 'assets/destinations/hero-home.png',
          },
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xF2071320),
                Color(0x99071320),
                Color(0x22071320),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TviumSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _destinationLabel(destination),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '$count ${count == 1 ? 'title' : 'titles'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _GroupSidebar extends StatelessWidget {
  const _GroupSidebar({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...groups];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB30A1A2A),
        borderRadius: BorderRadius.circular(TviumRadius.surface),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TviumSpacing.md,
              TviumSpacing.md,
              TviumSpacing.md,
              TviumSpacing.sm,
            ),
            child: Text(
              'Categories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                TviumSpacing.xs,
                0,
                TviumSpacing.xs,
                TviumSpacing.sm,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final group = options[index];
                final selected = group == selectedGroup;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: TviumColors.accentDark.withValues(
                        alpha: 0.16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          TviumRadius.control,
                        ),
                      ),
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                      ),
                      title: Text(
                        group ?? 'All categories',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(group),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _LiveMediaRow extends StatelessWidget {
  const _LiveMediaRow({
    super.key,
    required this.entry,
    required this.schedule,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final _LibraryEntry entry;
  final EpgNowNext? schedule;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF102133),
      child: ListTile(
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TviumSpacing.sm,
          vertical: TviumSpacing.xs,
        ),
        onTap: onTap,
        leading: SizedBox.square(
          dimension: 56,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TviumRadius.control),
            child: _CatalogArtwork(entry: entry),
          ),
        ),
        title: Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              schedule?.current?.title ?? 'Program guide unavailable',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (schedule?.next case final next?)
              Text(
                'Next: ${next.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: ValueKey('favorite-${entry.id}'),
              tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: onFavorite,
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
            const SizedBox(width: TviumSpacing.xs),
            Icon(
              Icons.play_circle_outline_rounded,
              color: onTap == null
                  ? Theme.of(context).disabledColor
                  : TviumColors.accentDark,
            ),
          ],
        ),
      ),
    );
  }
}

final class _MediaCard extends StatelessWidget {
  const _MediaCard({
    super.key,
    required this.entry,
    required this.schedule,
    required this.destination,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final _LibraryEntry entry;
  final EpgNowNext? schedule;
  final _CatalogDestination destination;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final live = destination == _CatalogDestination.live;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF102133),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _CatalogArtwork(entry: entry),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton.filledTonal(
                      key: ValueKey('favorite-${entry.id}'),
                      tooltip: favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TviumSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  if (live) ...<Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(Icons.circle, color: Color(0xFFFF4057), size: 8),
                        SizedBox(width: 6),
                        Text('Live'),
                      ],
                    ),
                    Text(
                      schedule?.current?.title ?? 'Program guide unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (schedule?.next case final next?)
                      Text(
                        'Next: ${next.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ] else
                    Text(
                      entry.group ?? _destinationLabel(destination),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CatalogArtwork extends StatelessWidget {
  const _CatalogArtwork({super.key, required this.entry});

  final _LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final uri = entry.imageUri;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF163D58), Color(0xFF09141F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Icon(
              _mediaIcon(entry.kind),
              size: 46,
              color: Colors.white54,
            ),
          ),
          ArtworkImage(
            sourceId: entry.sourceId,
            entryId: entry.id,
            role: entry.kind == MediaKind.live ? 'logo' : 'poster',
            uri: uri,
          ),
        ],
      ),
    );
  }
}

Future<void> _showTitleDetails(
  BuildContext context,
  _LibraryEntry entry,
  ValueChanged<_LibraryEntry> onPlay,
  XtreamConnectionService service,
) {
  if (entry.seriesEpisodes.isNotEmpty) {
    return _showLocalSeriesDetails(context, entry, onPlay);
  }
  final XtreamSeriesService? seriesService = service is XtreamSeriesService
      ? service as XtreamSeriesService
      : null;
  final seriesId = entry.xtreamSeriesId;
  if (seriesId != null &&
      entry.xtreamProfileId != null &&
      seriesService != null) {
    return _showSeriesDetails(context, entry, onPlay, seriesService, seriesId);
  }
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('title-details'),
      title: Text(entry.displayName),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.group ??
                  (entry.kind == MediaKind.movie ? 'Movie' : 'TV show'),
            ),
            const SizedBox(height: TviumSpacing.sm),
            const Text(
              'Online descriptions and ratings are optional and do not affect playback.',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: entry.isPlayable
              ? () {
                  Navigator.of(dialogContext).pop();
                  onPlay(entry);
                }
              : null,
          child: const Text('Play now'),
        ),
      ],
    ),
  );
}

Future<void> _showLocalSeriesDetails(
  BuildContext context,
  _LibraryEntry entry,
  ValueChanged<_LibraryEntry> onPlay,
) {
  final seasons = <int, List<_LibraryEntry>>{};
  const normalizer = PlaylistTitleNormalizer();
  for (final episode in entry.seriesEpisodes) {
    final metadata = normalizer.normalize(episode.name, kind: episode.kind);
    seasons
        .putIfAbsent(metadata.season ?? 0, () => <_LibraryEntry>[])
        .add(episode);
  }
  final seasonNumbers = seasons.keys.toList()..sort();
  for (final episodes in seasons.values) {
    episodes.sort((left, right) {
      final leftNumber = normalizer
          .normalize(left.name, kind: left.kind)
          .episode;
      final rightNumber = normalizer
          .normalize(right.name, kind: right.kind)
          .episode;
      return (leftNumber ?? 0).compareTo(rightNumber ?? 0);
    });
  }
  final firstEpisode = seasons[seasonNumbers.first]!.first;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('title-details'),
      title: Text(entry.displayName),
      content: SizedBox(
        width: 560,
        height: 480,
        child: ListView(
          children: <Widget>[
            for (final seasonNumber in seasonNumbers)
              ExpansionTile(
                key: ValueKey('season-$seasonNumber'),
                initiallyExpanded: seasonNumber == seasonNumbers.first,
                title: Text(
                  seasonNumber == 0 ? 'Specials' : 'Season $seasonNumber',
                ),
                subtitle: Text(
                  '${seasons[seasonNumber]!.length} '
                  '${seasons[seasonNumber]!.length == 1 ? 'episode' : 'episodes'}',
                ),
                children: <Widget>[
                  for (final episode in seasons[seasonNumber]!)
                    Builder(
                      builder: (context) {
                        final metadata = normalizer.normalize(
                          episode.name,
                          kind: episode.kind,
                        );
                        return ListTile(
                          key: ValueKey('local-episode-${episode.id}'),
                          leading: Text('${metadata.episode ?? '–'}'),
                          title: Text('Episode ${metadata.episode ?? '–'}'),
                          subtitle: Text(
                            episode.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onPlay(episode);
                          },
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onPlay(firstEpisode);
          },
          child: const Text('Play now'),
        ),
      ],
    ),
  );
}

Future<void> _showSeriesDetails(
  BuildContext context,
  _LibraryEntry entry,
  ValueChanged<_LibraryEntry> onPlay,
  XtreamSeriesService service,
  String seriesId,
) {
  final profileId = entry.xtreamProfileId!;
  final details = service.loadSeriesDetails(profileId, seriesId);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('title-details'),
      title: Text(entry.displayName),
      content: SizedBox(
        width: 560,
        height: 480,
        child: FutureBuilder<XtreamSeriesDetails>(
          future: details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final series = snapshot.data;
            if (series == null) {
              return const Center(
                child: Text('Episodes are temporarily unavailable.'),
              );
            }
            return ListView(
              children: <Widget>[
                if (series.plot case final plot?) ...<Widget>[
                  Text(plot),
                  const SizedBox(height: TviumSpacing.sm),
                ],
                for (final season in series.seasons)
                  ExpansionTile(
                    key: ValueKey('season-${season.number}'),
                    initiallyExpanded: season == series.seasons.first,
                    title: Text(season.name),
                    subtitle: Text(
                      '${season.episodes.length} ${season.episodes.length == 1 ? 'episode' : 'episodes'}',
                    ),
                    children: <Widget>[
                      for (final episode in season.episodes)
                        ListTile(
                          key: ValueKey('episode-${episode.id}'),
                          leading: Text('${episode.number}'),
                          title: Text(episode.title),
                          subtitle: episode.duration == null
                              ? null
                              : Text('${episode.duration!.inMinutes} min'),
                          trailing: const Icon(Icons.play_arrow_rounded),
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            onPlay(
                              _LibraryEntry.fromEpisode(
                                profileId: profileId,
                                seriesId: seriesId,
                                seriesName: series.name,
                                episode: episode,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _destinationLabel(_CatalogDestination destination) =>
    switch (destination) {
      _CatalogDestination.home => 'Home',
      _CatalogDestination.live => 'Live TV',
      _CatalogDestination.movies => 'Movies',
      _CatalogDestination.shows => 'TV Shows',
    };

IconData _destinationIcon(_CatalogDestination destination) =>
    switch (destination) {
      _CatalogDestination.home => Icons.home_rounded,
      _CatalogDestination.live => Icons.live_tv_rounded,
      _CatalogDestination.movies => Icons.movie_rounded,
      _CatalogDestination.shows => Icons.tv_rounded,
    };

IconData _mediaIcon(MediaKind kind) => switch (kind) {
  MediaKind.live => Icons.live_tv_rounded,
  MediaKind.movie => Icons.movie_rounded,
  MediaKind.episode => Icons.tv_rounded,
  MediaKind.unclassified => Icons.play_circle_outline_rounded,
};

Future<void> _showChannelSwitcher(
  BuildContext context,
  List<_LibraryEntry> channels,
  ValueChanged<_LibraryEntry> onPlay,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) {
    var query = '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final matches = channels
            .where(
              (entry) =>
                  entry.displayName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList(growable: false);
        void chooseChannel(_LibraryEntry entry) {
          Navigator.of(dialogContext).pop();
          onPlay(entry);
        }

        return AlertDialog(
          key: const ValueKey('live-channel-switcher'),
          title: const Text('Switch channel'),
          content: SizedBox(
            width: 440,
            height: (MediaQuery.sizeOf(context).height * 0.55).clamp(
              180.0,
              420.0,
            ),
            child: Column(
              children: <Widget>[
                TextField(
                  key: const ValueKey('live-channel-switcher-search'),
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search channels',
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                  onSubmitted: (value) {
                    final submitted = value.toLowerCase();
                    final first = channels
                        .where(
                          (entry) => entry.displayName.toLowerCase().contains(
                            submitted,
                          ),
                        )
                        .firstOrNull;
                    if (first != null) chooseChannel(first);
                  },
                ),
                const SizedBox(height: TviumSpacing.sm),
                Expanded(
                  child: matches.isEmpty
                      ? const Center(child: Text('No matching channels'))
                      : ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final entry = matches[index];
                            return ListTile(
                              key: ValueKey('switch-channel-${entry.id}'),
                              title: Text(
                                entry.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => chooseChannel(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

final class _PlayerPanel extends ConsumerWidget {
  const _PlayerPanel({
    required this.selectedEntry,
    required this.engine,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onOpenChannelSwitcher,
  });

  final _LibraryEntry? selectedEntry;
  final PlaybackEngine? engine;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onOpenChannelSwitcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackEngine = engine;
    return Focus(
      key: const ValueKey('live-player-focus'),
      canRequestFocus: onNextChannel != null,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || onNextChannel == null) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.pageUp) {
          onPreviousChannel?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.pageDown) {
          onNextChannel?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
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
                  ref.watch(playbackViewBuilderProvider)(playbackEngine),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.all(TviumSpacing.md),
                      color: Colors.black.withValues(alpha: 0.65),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              selectedEntry?.name ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (onOpenChannelSwitcher != null)
                            IconButton(
                              key: const ValueKey(
                                'live-channel-switcher-button',
                              ),
                              tooltip: 'Switch channel',
                              onPressed: onOpenChannelSwitcher,
                              icon: const Icon(Icons.search_rounded),
                            ),
                          if (onPreviousChannel != null) ...<Widget>[
                            IconButton(
                              key: const ValueKey('live-previous-channel'),
                              tooltip: 'Previous channel',
                              onPressed: onPreviousChannel,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            IconButton(
                              key: const ValueKey('live-next-channel'),
                              tooltip: 'Next channel',
                              onPressed: onNextChannel,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

List<_LibraryEntry> _groupSeriesEntries(List<_LibraryEntry> entries) {
  const normalizer = PlaylistTitleNormalizer();
  final groupKeys = <_LibraryEntry, String>{};
  final buckets = <String, List<_LibraryEntry>>{};
  final names = <String, String>{};
  for (final entry in entries) {
    if (entry.xtreamSeriesId != null && entry.xtreamEpisode == null) continue;
    final metadata = normalizer.normalize(entry.name, kind: entry.kind);
    if (metadata.season == null ||
        metadata.episode == null ||
        metadata.title.isEmpty) {
      continue;
    }
    final key = '${entry.sourceId}\u0000${metadata.title.toLowerCase()}';
    groupKeys[entry] = key;
    buckets.putIfAbsent(key, () => <_LibraryEntry>[]).add(entry);
    names[key] = metadata.title;
  }

  final result = <_LibraryEntry>[];
  final emitted = <String>{};
  for (final entry in entries) {
    final key = groupKeys[entry];
    if (key == null) {
      result.add(entry);
      continue;
    }
    if (!emitted.add(key)) continue;
    final episodes = buckets[key]!;
    result.add(
      _LibraryEntry.seriesCollection(
        name: names[key]!,
        group: episodes.first.group,
        episodes: episodes,
      ),
    );
  }
  return result;
}

final class _LibraryEntry {
  const _LibraryEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.group,
    required this.imageUri,
    required this.m3uUri,
    required this.m3uSourceReference,
    required this.xtreamProfileId,
    required this.xtreamItem,
    required this.xtreamSeriesId,
    required this.xtreamEpisode,
    required this.sourceId,
    this.seriesEpisodes = const <_LibraryEntry>[],
  });

  factory _LibraryEntry.seriesCollection({
    required String name,
    required String? group,
    required List<_LibraryEntry> episodes,
  }) {
    Uri? artwork;
    for (final episode in episodes) {
      if (episode.imageUri != null) {
        artwork = episode.imageUri;
        break;
      }
    }
    final sourceId = episodes.first.sourceId;
    final identity = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return _LibraryEntry(
      id: 'local-series:$sourceId:$identity',
      name: name,
      kind: MediaKind.episode,
      group: group,
      imageUri: artwork,
      m3uUri: null,
      m3uSourceReference: null,
      xtreamProfileId: null,
      xtreamItem: null,
      xtreamSeriesId: null,
      xtreamEpisode: null,
      sourceId: sourceId,
      seriesEpisodes: List<_LibraryEntry>.unmodifiable(episodes),
    );
  }

  factory _LibraryEntry.fromM3u(M3uEntry entry) => _LibraryEntry(
    id: entry.id,
    name: entry.originalName,
    kind: entry.kind,
    group: entry.groupTitle,
    imageUri: entry.logoUri,
    m3uUri: entry.originalUri,
    m3uSourceReference: null,
    xtreamProfileId: null,
    xtreamItem: null,
    xtreamSeriesId: null,
    xtreamEpisode: null,
    sourceId: 'session.m3u',
  );

  factory _LibraryEntry.fromXtream({
    required String profileId,
    required XtreamMediaItem item,
    required String? group,
  }) => _LibraryEntry(
    id: '${item.kind.name}:${item.id}',
    name: item.name,
    kind: item.kind,
    group: group,
    imageUri: item.imageUri,
    m3uUri: null,
    m3uSourceReference: null,
    xtreamProfileId: profileId,
    xtreamItem: item,
    xtreamSeriesId: null,
    xtreamEpisode: null,
    sourceId: profileId,
  );

  factory _LibraryEntry.fromSeries(
    XtreamSeriesSummary series, {
    required String profileId,
    required String? group,
  }) => _LibraryEntry(
    id: 'series:${series.id}',
    name: series.name,
    kind: MediaKind.episode,
    group: group,
    imageUri: series.coverUri,
    m3uUri: null,
    m3uSourceReference: null,
    xtreamProfileId: profileId,
    xtreamItem: null,
    xtreamSeriesId: series.id,
    xtreamEpisode: null,
    sourceId: profileId,
  );

  factory _LibraryEntry.fromEpisode({
    required String profileId,
    required String seriesId,
    required String seriesName,
    required XtreamEpisode episode,
  }) => _LibraryEntry(
    id: 'episode:${episode.id}',
    name: episode.title,
    kind: MediaKind.episode,
    group: seriesName,
    imageUri: episode.imageUri,
    m3uUri: null,
    m3uSourceReference: null,
    xtreamProfileId: profileId,
    xtreamItem: null,
    xtreamSeriesId: seriesId,
    xtreamEpisode: episode,
    sourceId: profileId,
  );

  factory _LibraryEntry.fromPersisted(PersistedMediaEntry entry, Uri? artwork) {
    final externalId = entry.externalId;
    final playable =
        externalId != null &&
        (entry.kind == MediaKind.live || entry.kind == MediaKind.movie);
    return _LibraryEntry(
      id: entry.id,
      name: entry.originalName,
      kind: entry.kind,
      group: entry.groupName,
      imageUri: artwork,
      m3uUri: null,
      m3uSourceReference: externalId == null ? entry.sourceReference : null,
      xtreamProfileId: externalId == null ? null : entry.sourceReference,
      xtreamItem: playable
          ? XtreamMediaItem(
              id: externalId,
              name: entry.displayName,
              kind: entry.kind,
              categoryId: null,
              imageUri: artwork,
              containerExtension: entry.containerExtension,
              epgChannelId: entry.epgChannelId,
            )
          : null,
      xtreamSeriesId: !playable && entry.kind == MediaKind.episode
          ? externalId
          : null,
      xtreamEpisode: null,
      sourceId: entry.playlistId,
    );
  }

  final String id;
  final String name;
  final MediaKind kind;
  final String? group;
  final Uri? imageUri;
  final Uri? m3uUri;
  final String? m3uSourceReference;
  final String? xtreamProfileId;
  final XtreamMediaItem? xtreamItem;
  final String? xtreamSeriesId;
  final XtreamEpisode? xtreamEpisode;
  final String sourceId;
  final List<_LibraryEntry> seriesEpisodes;

  bool get isPlayable =>
      m3uUri != null ||
      m3uSourceReference != null ||
      xtreamItem != null ||
      xtreamEpisode != null;

  String get displayName =>
      const PlaylistTitleNormalizer().normalize(name, kind: kind).title;

  MediaLocator locator(String profileId) =>
      MediaLocator(profileId: profileId, sourceId: sourceId, entryId: id);

  Future<Uri?> resolveUri(
    XtreamConnectionService service,
    M3uPlaybackResolver m3uResolver,
  ) {
    final directUri = m3uUri;
    if (directUri != null) {
      return Future<Uri?>.value(directUri);
    }
    final sourceReference = m3uSourceReference;
    if (sourceReference != null) {
      return m3uResolver.resolve(sourceReference, id);
    }
    final profileId = xtreamProfileId;
    final episode = xtreamEpisode;
    if (profileId != null && episode != null) {
      final XtreamSeriesService? seriesService = service is XtreamSeriesService
          ? service as XtreamSeriesService
          : null;
      if (seriesService != null) {
        return seriesService.resolveEpisodeStreamUri(profileId, episode);
      }
    }
    final item = xtreamItem;
    if (profileId == null || item == null) {
      return Future<Uri?>.value();
    }
    return service.resolveStreamUri(profileId, item);
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

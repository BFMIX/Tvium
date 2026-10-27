import 'dart:async';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_design_system/tvium_design_system.dart';
import 'package:tvium_epg/tvium_epg.dart';
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
import '../import/qr_pairing.dart';
import '../import/qr_pairing_web.dart'
    if (dart.library.io) '../import/qr_pairing_io.dart'
    as qr_pairing;
import '../import/xtream_m3u_detector.dart';
import '../import/xtream_m3u_reconciliation.dart';
import '../library/library_bootstrap_controller.dart';
import '../library/live_country.dart';
import '../library/source_refresh_schedule.dart';
import '../library/user_overlays_controller.dart';
import '../metadata/metadata_details.dart';
import '../metadata/metadata_gateway_client.dart';
import '../metadata/metadata_overlay_store.dart';
import '../parental/parental_pin_service.dart';
import '../parental/parental_unlock_lease.dart';
import '../profiles/profile_switcher.dart';
import '../sources/source_identity_service.dart';
import '../updates/update_checker.dart';
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

final qrPairingStarterProvider = Provider<Future<QrPairingSession> Function()>(
  (ref) => qr_pairing.startQrPairing,
);

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey _urlFieldKey = GlobalKey();
  final GlobalKey _xtreamFormKey = GlobalKey();
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
  final ParentalUnlockLease _parentalUnlock = ParentalUnlockLease(
    clock: DateTime.now,
  );
  Timer? _parentalUnlockTimer;
  var _profileSessionGeneration = 0;
  final _startupRefreshQueued = <String>{};
  Timer? _scheduledRefreshTimer;
  SourceRefreshRunner? _refreshRunner;
  final UpdateCheckSchedule _updateCheckSchedule = UpdateCheckSchedule();
  String? _lastAnnouncedUpdateTag;
  _CatalogDestination _activeDestination = _CatalogDestination.home;
  LibrarySnapshot? _mappedLibrarySnapshot;
  LibrarySnapshot? _mappingLibrarySnapshot;
  List<_LibraryEntry>? _mappedLibraryEntries;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreMetadataConsent());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForAppUpdate());
    });
    WidgetsBinding.instance.addObserver(this);
    _scheduledRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_checkDueSources());
    });
  }

  Future<void> _restoreMetadataConsent() async {
    try {
      final enabled = await ref.read(metadataConsentStoreProvider).read();
      if (mounted) metadataEnabled.value = enabled;
    } on Object {
      // A missing secure store leaves the default preference unchanged.
    }
  }

  Future<void> _checkForAppUpdate() async {
    final currentTag = ref.read(installedReleaseTagProvider);
    if (currentTag.isEmpty ||
        !_updateCheckSchedule.shouldCheck(ref.read(updateClockProvider)())) {
      return;
    }
    try {
      final update = await ref.read(updateCheckerProvider).check(currentTag);
      if (!mounted || update == null || update.tag == _lastAnnouncedUpdateTag) {
        return;
      }
      _lastAnnouncedUpdateTag = update.tag;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tvium ${update.tag} is available'),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Updates',
            onPressed: () => showSettingsPages(
              context,
              openSection: (section) => showLibrarySettings(
                context,
                configured: ref.read(metadataGatewayProvider) != null,
                metadataConsentStore: ref.read(metadataConsentStoreProvider),
                section: section,
              ),
            ),
          ),
        ),
      );
    } on UpdateCheckException {
      // Update availability is optional and never blocks the local library.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _clearParentalUnlock();
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkDueSources());
      unawaited(_checkForAppUpdate());
    }
  }

  @override
  void dispose() {
    _parentalUnlockTimer?.cancel();
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
    final libraryState = ref.watch(libraryBootstrapProvider);
    if (libraryState.isLoading &&
        ref.watch(libraryRepositoryProvider).asData != null &&
        state.phase == PlaylistImportPhase.empty &&
        _xtreamProfile == null) {
      return _libraryLoading('library-loading', 'Opening your library…');
    }
    final persistedLibrary = libraryState.asData?.value;
    if (persistedLibrary != null &&
        persistedLibrary.sources.isNotEmpty &&
        _xtreamProfile == null &&
        !identical(_mappedLibrarySnapshot, persistedLibrary)) {
      if (!identical(_mappingLibrarySnapshot, persistedLibrary)) {
        _mappingLibrarySnapshot = persistedLibrary;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_mapSavedLibrary(persistedLibrary));
        });
      }
      return _libraryLoading('library-organizing', 'Organizing your library…');
    }
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
    final parentalUnlocked = _parentalUnlock.isUnlocked(profileId);
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
    final epgBySource = <String, List<PersistedMediaEntry>>{};
    for (final entry
        in (persistedLibrary?.entries ?? const <PersistedMediaEntry>[])
            .followedBy(sessionEpgEntries)) {
      if (entry.kind != MediaKind.live ||
          entry.epgChannelId?.isNotEmpty != true) {
        continue;
      }
      epgBySource.putIfAbsent(entry.playlistId, () => []).add(entry);
    }
    if (epgBySource.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final minute = DateTime.utc(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      for (final sourceEntries in epgBySource.entries) {
        final snapshot = ref
            .watch(
              epgNowNextProvider(
                EpgNowNextRequest(
                  profileId:
                      persistedLibrary?.activeProfile.id ?? 'session.profile',
                  sourceId: sourceEntries.key,
                  entries: sourceEntries.value,
                  atUtc: minute,
                ),
              ),
            )
            .asData
            ?.value;
        if (snapshot != null) {
          for (final entry in sourceEntries.value) {
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
                      catalogGeneration: persistedLibrary,
                      initialDestination: _activeDestination,
                      catalogTotals:
                          persistedLibrary?.catalogTotals ?? const {},
                      catalogArtwork: persistedLibrary?.artwork ?? const {},
                      onGroupSelected: (group) =>
                          setState(() => _selectedGroup = group),
                      onDestinationSelected: (destination) => setState(() {
                        _activeDestination = destination;
                      }),
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

  Widget _libraryLoading(String key, String message) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          key: ValueKey(key),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const TviumBrandLogo(height: 52, semanticLabel: 'Tvium'),
            const SizedBox(height: TviumSpacing.lg),
            const Icon(Icons.hourglass_top_rounded, size: 32),
            const SizedBox(height: TviumSpacing.md),
            Text(message),
          ],
        ),
      ),
    ),
  );

  Future<void> _mapSavedLibrary(LibrarySnapshot snapshot) async {
    // A post-frame callback paints the loading surface before conversion.
    final mapped = <_LibraryEntry>[];
    for (var index = 0; index < snapshot.entries.length; index++) {
      if (!mounted || !identical(_mappingLibrarySnapshot, snapshot)) return;
      final entry = snapshot.entries[index];
      mapped.add(
        _LibraryEntry.fromPersisted(
          entry,
          snapshot.artwork[entry.playlistId]?[entry.id],
        ),
      );
      if (index % 256 == 255) await Future<void>.delayed(Duration.zero);
    }
    if (!mounted || !identical(_mappingLibrarySnapshot, snapshot)) return;
    setState(() {
      _mappedLibrarySnapshot = snapshot;
      _mappedLibraryEntries = mapped;
    });
    if (snapshot.catalogTotals.values.fold<int>(0, (a, b) => a + b) > 1000) {
      unawaited(_loadInitialArtwork(snapshot));
    }
  }

  Future<void> _loadInitialArtwork(LibrarySnapshot snapshot) async {
    final artwork = <String, Map<String, Uri>>{};
    for (final source in snapshot.sources) {
      final ids = snapshot.entries
          .where((entry) => entry.playlistId == source.id)
          .map((entry) => entry.id)
          .toSet();
      if (ids.isEmpty) continue;
      try {
        artwork[source.id] = await ref
            .read(artworkReferenceStoreProvider)
            .readSelected(source.id, ids);
      } on Object {
        artwork[source.id] = const {};
      }
    }
    if (!mounted || !identical(_mappedLibrarySnapshot, snapshot)) return;
    setState(() {
      _mappedLibraryEntries = [
        for (final entry in snapshot.entries)
          _LibraryEntry.fromPersisted(
            entry,
            artwork[entry.playlistId]?[entry.id],
          ),
      ];
    });
  }

  Widget _buildOnboarding(
    PlaylistImportController controller,
    PlaylistImportState state,
  ) {
    final strings = AppLocalizations.of(context);
    final importing =
        state.phase == PlaylistImportPhase.importing ||
        state.phase == PlaylistImportPhase.saving;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ImageFiltered(
          key: const ValueKey('onboarding-backdrop-blur'),
          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Image.asset(
            'assets/destinations/hero-home.png',
            key: const ValueKey('onboarding-backdrop'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            excludeFromSemantics: true,
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFA061421),
                Color(0xE0071B2B),
                Color(0x77051322),
                Color(0x44051322),
              ],
              stops: <double>[0, 0.38, 0.72, 1],
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) => Opacity(
            key: const ValueKey('onboarding-entrance'),
            opacity: progress,
            alwaysIncludeSemantics: true,
            child: child,
          ),
          child: Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TviumSpacing.lg),
              child: Container(
                key: const ValueKey('onboarding-panel'),
                constraints: const BoxConstraints(maxWidth: 900),
                padding: const EdgeInsets.all(TviumSpacing.xl),
                decoration: BoxDecoration(
                  color: const Color(0xB8081A2B),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  borderRadius: BorderRadius.circular(TviumRadius.surface),
                ),
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
                    Container(
                      width: 48,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: TviumSpacing.md),
                    Text(
                      strings.welcomeTitle,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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
                          final cardWidth = compact ? double.infinity : 250.0;
                          final cards = <Widget>[
                            SourceActionCard(
                              key: const ValueKey<String>('m3u-url-action'),
                              title: strings.m3uUrl,
                              description: strings.analyzePlaylist,
                              icon: Icons.link_rounded,
                              focusNode: _urlActionFocus,
                              autofocus: !compact,
                              width: cardWidth,
                              compact: compact,
                              onActivate: () {
                                setState(() {
                                  _showUrlField = true;
                                  _showXtreamForm = false;
                                });
                                _revealOnboardingForm(_urlFieldKey);
                              },
                            ),
                            SourceActionCard(
                              key: const ValueKey<String>('m3u-file-action'),
                              title: strings.importLocalM3u,
                              description: '.m3u · .m3u8',
                              icon: Icons.folder_open_rounded,
                              focusNode: _fileActionFocus,
                              width: cardWidth,
                              compact: compact,
                              onActivate: () =>
                                  unawaited(_pickLocalFile(controller)),
                            ),
                            SourceActionCard(
                              key: const ValueKey<String>('xtream-action'),
                              title: strings.xtreamCodes,
                              description: strings.connectProvider,
                              icon: Icons.dns_outlined,
                              focusNode: _xtreamActionFocus,
                              width: cardWidth,
                              compact: compact,
                              onActivate: () {
                                setState(() {
                                  _showUrlField = false;
                                  _showXtreamForm = true;
                                });
                                _revealOnboardingForm(_xtreamFormKey);
                              },
                            ),
                          ];
                          if (compact) {
                            return Column(
                              spacing: TviumSpacing.sm,
                              children: cards,
                            );
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              spacing: TviumSpacing.sm,
                              children: cards,
                            ),
                          );
                        },
                      ),
                    ),
                    if (!kIsWeb) ...<Widget>[
                      const SizedBox(height: TviumSpacing.lg),
                      Row(
                        key: const ValueKey('qr-pairing-separator'),
                        children: <Widget>[
                          const Expanded(child: Divider()),
                          Flexible(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: TviumSpacing.sm,
                              ),
                              child: Text(
                                strings.orAddWithPhone,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: TviumSpacing.sm),
                      Center(
                        child: OutlinedButton.icon(
                          key: const ValueKey('qr-pairing-action'),
                          onPressed: () =>
                              unawaited(_showQrPairing(controller)),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: Text(strings.pairWithPhone),
                        ),
                      ),
                    ],
                    if (_showUrlField) ...<Widget>[
                      const SizedBox(height: TviumSpacing.lg),
                      Row(
                        key: _urlFieldKey,
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
                                  onPressed: () => setState(
                                    () => _obscureUrl = !_obscureUrl,
                                  ),
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
                        key: _xtreamFormKey,
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
                              state.phase == PlaylistImportPhase.saving
                                  ? strings.savingPlaylist
                                  : '${strings.importing} ${state.parsedCount}',
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
                      _InlineError(
                        message: state.message ?? strings.importFailed,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _revealOnboardingForm(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.85,
        ),
      );
    });
  }

  Future<void> _showQrPairing(PlaylistImportController controller) async {
    final QrPairingSession session;
    try {
      session = await ref.read(qrPairingStarterProvider)();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).pairingUnavailable),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      await session.close();
      return;
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final strings = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(strings.pairWithPhone),
            content: SizedBox(
              width: 340,
              child: FutureBuilder<QrPairingSubmission?>(
                future: session.submission,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Text(strings.pairingExpired);
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        QrImageView(
                          key: const ValueKey('qr-pairing-code'),
                          data: session.pairingUrl,
                          size: 250,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: TviumSpacing.md),
                        Text(strings.pairingInstructions),
                      ],
                    );
                  }
                  final proposal = snapshot.data!;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: TviumSpacing.md),
                      Text(strings.pairingReceived),
                      const SizedBox(height: TviumSpacing.sm),
                      Text(
                        proposal is QrXtreamSubmission
                            ? strings.xtreamCodes
                            : strings.m3uUrl,
                        key: const ValueKey('qr-pairing-source-type'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: TviumSpacing.md),
                      FilledButton(
                        key: const ValueKey('qr-pairing-confirm'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          unawaited(_acceptQrSubmission(controller, proposal));
                        },
                        child: Text(strings.addPlaylist),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(strings.cancel),
              ),
            ],
          );
        },
      );
    } finally {
      await session.close();
    }
  }

  Future<void> _acceptQrSubmission(
    PlaylistImportController controller,
    QrPairingSubmission proposal,
  ) async {
    switch (proposal) {
      case QrM3uSubmission(:final url):
        await _importM3uUrl(controller, url);
      case QrXtreamSubmission(:final server, :final username, :final password):
        try {
          final profile = await ref
              .read(xtreamConnectionServiceProvider)
              .addPlaylist(
                XtreamConnectionInput(
                  profileName: server.host,
                  serverUri: server,
                  credentials: XtreamCredentials(
                    username: username,
                    password: password,
                  ),
                ),
              );
          if (mounted) await _openXtreamLibrary(profile);
        } on Object {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).connectionFailed),
              ),
            );
          }
        }
    }
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
      // Persisted Xtream entries are read in pages from SQLite. Keeping the
      // network catalog here duplicates the entire source in memory and makes
      // every Home rebuild map all of its channels, movies, and series.
      _xtreamProfile = targetProfileId == null ? profile : null;
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
      final service = ref.read(xtreamConnectionServiceProvider);
      if (service is! XtreamCatalogPreviewService) return false;
      final previewService = service as XtreamCatalogPreviewService;
      final repository = await ref.read(libraryRepositoryProvider.future);
      if (repository is! UserOverlayRepository) return false;
      final overlays = repository as UserOverlayRepository;
      final digest = await SourceIdentityService(FlutterSecureKeyValueStore())
          .xtreamDigest(candidate.serverUri, candidate.credentials.username);
      if (await repository.sourceByIdentity(digest) != null) return false;
      final saved = await repository.entriesForPlaylist(source.id);
      if (await _hasSavedSourceOverlays(repository, overlays, source.id)) {
        return false;
      }
      final input = XtreamConnectionInput(
        profileName: source.displayName,
        serverUri: candidate.serverUri,
        credentials: candidate.credentials,
      );
      final preview = await previewService.previewCatalog(input);
      if (!canReplaceSavedM3u(saved, preview)) return false;
      final profile = await service.addPlaylist(input);
      if (profile.wasExisting ||
          !canReplaceSavedM3u(saved, profile.catalog) ||
          !canReplaceSavedM3u(
            await repository.entriesForPlaylist(source.id),
            profile.catalog,
          ) ||
          await _hasSavedSourceOverlays(repository, overlays, source.id)) {
        if (!profile.wasAlreadyLinked) {
          final active = await repository.activeProfile();
          final orphan = await repository.unlinkSource(
            active.id,
            profile.sourceId,
          );
          if (orphan != null) {
            await _removeOrphanedSources(<IptvSource>[orphan]);
          }
        }
        return false;
      }
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

  Future<bool> _hasSavedSourceOverlays(
    ProfileSourceRepository repository,
    UserOverlayRepository overlays,
    String sourceId,
  ) async {
    final profiles = await repository.profiles();
    for (final profile in profiles) {
      final favorites = await overlays.favoritesForProfile(profile.id);
      if (favorites.any((item) => item.sourceId == sourceId)) return true;
      final history = await overlays.historyForProfile(profile.id, limit: 1001);
      if (history.length >= 1001 ||
          history.any((item) => item.media.sourceId == sourceId)) {
        return true;
      }
    }
    return false;
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
      _parentalUnlock.clear();
      _parentalUnlockTimer?.cancel();
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
        return _mappedLibraryEntries ?? const <_LibraryEntry>[];
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
      if (mounted) _clearParentalUnlock();
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
      setState(() => _parentalUnlock.unlock(policy.profileId));
      _parentalUnlockTimer?.cancel();
      _parentalUnlockTimer = Timer(ParentalUnlockLease.duration, () {
        if (mounted) _clearParentalUnlock();
      });
    }
    return 'Protected content unlocked for 15 minutes.';
  }

  void _clearParentalUnlock() {
    _parentalUnlockTimer?.cancel();
    _parentalUnlock.clear();
    if (mounted) setState(() {});
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
    required this.catalogGeneration,
    required this.initialDestination,
    required this.catalogTotals,
    required this.catalogArtwork,
    required this.onGroupSelected,
    required this.onDestinationSelected,
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
  final LibrarySnapshot? catalogGeneration;
  final _CatalogDestination initialDestination;
  final Map<MediaKind, int> catalogTotals;
  final Map<String, Map<String, Uri>> catalogArtwork;
  final ValueChanged<String?> onGroupSelected;
  final ValueChanged<_CatalogDestination> onDestinationSelected;
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
  final _catalogPages = <MediaKind, List<_LibraryEntry>>{};
  final _catalogOffsets = <MediaKind, int>{};
  bool _catalogPageLoading = false;
  String? _selectedCountryCode;
  String _query = '';
  bool _searching = false;
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
  }

  @override
  void didUpdateWidget(covariant _LibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        !identical(oldWidget.catalogGeneration, widget.catalogGeneration) ||
        !listEquals(
          oldWidget.sources.map((s) => s.id).toList(),
          widget.sources.map((s) => s.id).toList(),
        )) {
      _catalogPages.clear();
      _catalogOffsets.clear();
    }
  }

  Future<void> _showCatalogPage(MediaKind kind, int offset) async {
    if (_catalogPageLoading ||
        offset < 0 ||
        offset >= (widget.catalogTotals[kind] ?? 0)) {
      return;
    }
    final repository = await ref.read(libraryRepositoryProvider.future);
    if (repository is! PagedProfileSourceRepository) return;
    setState(() => _catalogPageLoading = true);
    try {
      final rows = await readCatalogPage(
        repository as PagedProfileSourceRepository,
        widget.sources,
        kind,
        offset: offset,
      );
      final artwork = <String, Map<String, Uri>>{};
      for (final source in widget.sources) {
        final ids = rows
            .where((entry) => entry.playlistId == source.id)
            .map((entry) => entry.id)
            .toSet();
        if (ids.isEmpty) continue;
        try {
          artwork[source.id] = await ref
              .read(artworkReferenceStoreProvider)
              .readSelected(source.id, ids);
        } on Object {
          artwork[source.id] = const {};
        }
      }
      if (!mounted) return;
      setState(() {
        _catalogPages[kind] = rows
            .map(
              (entry) => _LibraryEntry.fromPersisted(
                entry,
                artwork[entry.playlistId]?[entry.id] ??
                    widget.catalogArtwork[entry.playlistId]?[entry.id],
              ),
            )
            .toList(growable: false);
        _catalogOffsets[kind] = offset;
        _selectedCountryCode = null;
      });
      widget.onGroupSelected(null);
    } finally {
      if (mounted) setState(() => _catalogPageLoading = false);
    }
  }

  MediaKind? _kindFor(_CatalogDestination destination) => switch (destination) {
    _CatalogDestination.live => MediaKind.live,
    _CatalogDestination.movies => MediaKind.movie,
    _CatalogDestination.shows => MediaKind.episode,
    _CatalogDestination.home => null,
  };

  Widget _pagedCatalog(_CatalogDestination destination) {
    final kind = _kindFor(destination)!;
    return _CatalogPage(
      key: ValueKey('page-${destination.name}'),
      destination: destination,
      entries: _entriesFor(destination),
      epgSchedules: widget.epgSchedules,
      query: _query,
      channelSearchController: destination == _CatalogDestination.live
          ? _queryController
          : null,
      onQueryChanged: destination == _CatalogDestination.live
          ? (value) => setState(() => _query = value.trim())
          : null,
      showLocalChannelSearch:
          destination == _CatalogDestination.live && !_searching,
      selectedGroup: widget.selectedGroup,
      selectedEntry: widget.selectedEntry,
      playbackEngine: widget.playbackEngine,
      onGroupSelected: widget.onGroupSelected,
      selectedCountryCode: _selectedCountryCode,
      onCountrySelected: destination == _CatalogDestination.live
          ? (code) {
              setState(() => _selectedCountryCode = code);
              widget.onGroupSelected(null);
            }
          : null,
      onPlay: widget.onEntrySelected,
      profileId: widget.profileId,
      favorites: widget.favorites,
      history: widget.history,
      onFavoriteToggled: widget.onFavoriteToggled,
      totalEntries: widget.catalogTotals[kind] ?? 0,
      pageOffset: _catalogOffsets[kind] ?? 0,
      pageLoading: _catalogPageLoading,
      onPageRequested: (offset) => _showCatalogPage(kind, offset),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

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
          child: Stack(
            children: <Widget>[
              if (_destination == _CatalogDestination.live) ...<Widget>[
                Positioned.fill(
                  child: Image.asset(
                    'assets/destinations/hero-live-tv.png',
                    key: const ValueKey('live-page-background'),
                    fit: BoxFit.cover,
                  ),
                ),
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xB8071422)),
                ),
              ] else if (_destination == _CatalogDestination.movies ||
                  _destination == _CatalogDestination.shows) ...<Widget>[
                Positioned.fill(
                  child: ImageFiltered(
                    key: const ValueKey('catalog-page-background'),
                    imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Image.asset(
                      _destination == _CatalogDestination.movies
                          ? 'assets/destinations/hero-movies.png'
                          : 'assets/destinations/hero-tv-shows.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xD4071422)),
                ),
              ],
              Column(
                children: <Widget>[
                  _CatalogHeader(
                    wide: wide,
                    destination: _destination,
                    searching: _searching,
                    onDestinationSelected: _selectDestination,
                    onSearch: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _query = '';
                        _queryController.clear();
                      }
                    }),
                    onSettings: () => showSettingsPages(
                      context,
                      openSection: (section) => showLibrarySettings(
                        context,
                        section: section,
                        configured: ref.read(metadataGatewayProvider) != null,
                        metadataConsentStore: ref.read(
                          metadataConsentStoreProvider,
                        ),
                        onImportEpgFile: widget.onImportEpgFile,
                        onImportEpgUrl: widget.onImportEpgUrl,
                        onRefreshSource: widget.onRefreshSource,
                        onRefreshSources: widget.onRefreshSources,
                        refreshIntervalFor: widget.refreshIntervalFor,
                        lastRefreshAttemptFor: widget.lastRefreshAttemptFor,
                        onRefreshIntervalChanged:
                            widget.onRefreshIntervalChanged,
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
                                  userOverlaysControllerProvider(
                                    widget.profileId,
                                  ),
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
                        controller: _queryController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search this section',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
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
                          onSelected: _selectDestination,
                        ),
                        _CatalogDestination.live => _pagedCatalog(_destination),
                        _CatalogDestination.movies => _pagedCatalog(
                          _destination,
                        ),
                        _CatalogDestination.shows => _pagedCatalog(
                          _destination,
                        ),
                      },
                    ),
                  ),
                  if (!wide)
                    NavigationBar(
                      key: const ValueKey('compact-navigation'),
                      height: MediaQuery.sizeOf(context).height < 500 ? 56 : 64,
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
            ],
          ),
        );
      },
    );
  }

  List<_LibraryEntry> _entriesFor(_CatalogDestination destination) {
    final kind = _kindFor(destination);
    final entries =
        (kind == null ? widget.entries : _catalogPages[kind] ?? widget.entries)
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
    _queryController.clear();
    widget.onDestinationSelected(destination);
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
    required this.onSelected,
  });

  final List<_LibraryEntry> entries;
  final ValueChanged<_CatalogDestination> onSelected;

  @override
  State<_DestinationHome> createState() => _DestinationHomeState();
}

final class _DestinationHomeState extends State<_DestinationHome> {
  Timer? _heroTimer;
  var _heroIndex = 0;
  bool? _reduceHeroMotion;
  List<_LibraryEntry>? _countedEntries;
  var _showCount = 0;
  List<_LibraryEntry>? _heroSource;
  List<_LibraryEntry>? _cachedHeroEntries;

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
    if (identical(_heroSource, widget.entries) && _cachedHeroEntries != null) {
      return _cachedHeroEntries!;
    }
    final playable = widget.entries
        .where((entry) => entry.kind != MediaKind.live && entry.isPlayable)
        .toList(growable: false);
    const normalizer = PlaylistTitleNormalizer();
    final seenSeries = <String>{};
    final distinct = playable
        .where((entry) {
          if (entry.kind != MediaKind.episode) return true;
          final title = normalizer.normalize(entry.name, kind: entry.kind);
          if (title.season == null || title.episode == null) return true;
          return seenSeries.add(
            '${entry.sourceId}\u0000${title.title.toLowerCase()}',
          );
        })
        .toList(growable: false);
    final selected = <_LibraryEntry>[
      ...distinct.where(
        (entry) =>
            entry.kind == MediaKind.movie && entry.imageUri?.hasScheme == true,
      ),
      ...distinct.where(
        (entry) =>
            entry.kind != MediaKind.movie || entry.imageUri?.hasScheme != true,
      ),
    ].take(5).toList(growable: false);
    _heroSource = widget.entries;
    _cachedHeroEntries = selected;
    return selected;
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
      _heroSource = null;
      _cachedHeroEntries = null;
      _heroIndex = 0;
      _startHeroTimer();
    }
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    if (_reduceHeroMotion != false || _heroEntries.length < 2) return;
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      setState(() => _heroIndex = (_heroIndex + 1) % _heroEntries.length);
    });
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
    final heroEntries = _heroEntries;
    final currentEntry = heroEntries.isEmpty
        ? null
        : heroEntries[_heroIndex % heroEntries.length];
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: metadataEnabled,
            builder: (context, enabled, _) => _HomeBackdrop(
              entry: currentEntry,
              metadataEnabled: enabled,
              slideIndex: _heroIndex,
            ),
          ),
        ),
        Center(
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
                  return destinationCards;
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _HomeBackdrop extends ConsumerWidget {
  const _HomeBackdrop({
    required this.entry,
    required this.metadataEnabled,
    required this.slideIndex,
  });

  final _LibraryEntry? entry;
  final bool metadataEnabled;
  final int slideIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = entry;
    final overlay = selected == null
        ? null
        : ref
              .watch(
                metadataHeroOverlayProvider((
                  sourceId: selected.sourceId,
                  entryId: selected.id,
                  title: selected.name,
                  kind: selected.kind,
                  enabled: metadataEnabled,
                )),
              )
              .value;
    final backdrop = overlay?.backdropUri;
    const fallbackArtwork = <String>[
      'assets/destinations/hero-home.png',
      'assets/destinations/hero-movies.png',
      'assets/destinations/hero-tv-shows.png',
    ];
    return RepaintBoundary(
      key: const ValueKey('home-page-backdrop'),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ImageFiltered(
            key: const ValueKey('home-backdrop-blur'),
            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              child: backdrop != null && selected != null
                  ? ArtworkImage(
                      key: ValueKey('home-backdrop-${selected.id}'),
                      sourceId: selected.sourceId,
                      entryId: selected.id,
                      role: 'backdrop',
                      uri: backdrop,
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      fallbackArtwork[slideIndex % fallbackArtwork.length],
                      key: const ValueKey('home-backdrop-fallback'),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xBB06111D),
                  Color(0xD906111D),
                  Color(0xEE06111D),
                ],
              ),
            ),
          ),
        ],
      ),
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
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(_destinationIcon(destination), size: 38),
                    const SizedBox(height: TviumSpacing.sm),
                    Text(
                      _destinationLabel(destination),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(switch (destination) {
                      _CatalogDestination.live =>
                        '$count TV ${count == 1 ? 'channel' : 'channels'}',
                      _CatalogDestination.movies =>
                        '$count ${count == 1 ? 'movie' : 'movies'}',
                      _CatalogDestination.shows => '$count TV series',
                      _CatalogDestination.home => '',
                    }, style: Theme.of(context).textTheme.bodyMedium),
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

final class _CatalogPage extends ConsumerWidget {
  const _CatalogPage({
    super.key,
    required this.destination,
    required this.entries,
    required this.epgSchedules,
    required this.query,
    this.channelSearchController,
    this.onQueryChanged,
    this.showLocalChannelSearch = false,
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
    this.totalEntries = 0,
    this.pageOffset = 0,
    this.pageLoading = false,
    this.onPageRequested,
  });

  final _CatalogDestination destination;
  final List<_LibraryEntry> entries;
  final Map<String, EpgNowNext?> epgSchedules;
  final String query;
  final TextEditingController? channelSearchController;
  final ValueChanged<String>? onQueryChanged;
  final bool showLocalChannelSearch;
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
  final int totalEntries;
  final int pageOffset;
  final bool pageLoading;
  final ValueChanged<int>? onPageRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unknownGroup = AppLocalizations.of(context).unknownGroup;
    final shortWindow = MediaQuery.sizeOf(context).height < 700;
    final compactWidth = MediaQuery.sizeOf(context).width < 720;
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
    final featureEntry = destination == _CatalogDestination.live
        ? null
        : visible
                  .where(
                    (entry) =>
                        entry.imageUri?.hasScheme == true &&
                        (destination == _CatalogDestination.movies ||
                            entry.xtreamSeriesId != null),
                  )
                  .firstOrNull ??
              visible.firstOrNull;
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
    final previewEntry = showPlayer ? selectedEntry : liveChannels.firstOrNull;
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
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: shortWindow ? 150 : 210,
              mainAxisSpacing: TviumSpacing.sm,
              crossAxisSpacing: TviumSpacing.sm,
              childAspectRatio: shortWindow ? 0.72 : 0.62,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final entry = visible[index];
              return _MediaCard(
                key: index == 0 && destination == _CatalogDestination.movies
                    ? const ValueKey('media-card-movie')
                    : ValueKey('media-card-${entry.id}'),
                entry: entry,
                prefetchMetadata: true,
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
    final catalog =
        destination == _CatalogDestination.live &&
            showPlayer &&
            shortWindow &&
            !compactWidth
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: media),
              const SizedBox(width: TviumSpacing.sm),
              SizedBox(
                key: const ValueKey('catalog-player'),
                width: (MediaQuery.sizeOf(context).width * 0.36).clamp(
                  220.0,
                  340.0,
                ),
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
          )
        : Column(
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
                          : (item.history.position.inMilliseconds / duration)
                                .clamp(0.0, 1.0);
                      return SizedBox(
                        width: 240,
                        child: Material(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0x44B8E8FF)),
                          ),
                          color: const Color(0xB8102638),
                          child: InkWell(
                            onTap: () => onPlay(item.entry),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                _CatalogArtwork(
                                  key: ValueKey(
                                    'continue-artwork-${item.entry.id}',
                                  ),
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
                                  padding: const EdgeInsets.all(
                                    TviumSpacing.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                  height: compactWidth ? 168 : 210,
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
                const SizedBox(height: TviumSpacing.md),
              ],
              Expanded(child: media),
            ],
          );
    final pageContent = Padding(
      padding: EdgeInsets.fromLTRB(
        shortWindow ? TviumSpacing.sm : TviumSpacing.lg,
        shortWindow ? 0 : TviumSpacing.sm,
        shortWindow ? TviumSpacing.sm : TviumSpacing.lg,
        shortWindow ? TviumSpacing.sm : TviumSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (shortWindow ||
              (compactWidth && destination != _CatalogDestination.live))
            SizedBox(
              height: shortWindow ? 28 : 42,
              child: Text(
                _destinationLabel(destination),
                style: shortWindow
                    ? Theme.of(context).textTheme.titleLarge
                    : Theme.of(context).textTheme.headlineMedium,
              ),
            )
          else if (destination == _CatalogDestination.live)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TviumSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LIVE TV',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    'Brings the world closer',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: MediaQuery.sizeOf(context).width < 720 ? 300 : 220,
              child: _CatalogFeature(
                destination: destination,
                entry: featureEntry,
                count: visible.length,
                onPlay: onPlay,
                onDetails: featureEntry == null
                    ? null
                    : () => _showTitleDetails(
                        context,
                        featureEntry,
                        onPlay,
                        ref.read(xtreamConnectionServiceProvider),
                      ),
              ),
            ),
          const SizedBox(height: TviumSpacing.md),
          if (onPageRequested != null &&
              totalEntries > libraryPageSize) ...<Widget>[
            Row(
              key: const ValueKey('catalog-pagination'),
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  key: const ValueKey('catalog-previous-page'),
                  tooltip: 'Previous titles',
                  onPressed: pageLoading || pageOffset == 0
                      ? null
                      : () => onPageRequested!(pageOffset - libraryPageSize),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${pageOffset + 1}–${(pageOffset + libraryPageSize).clamp(0, totalEntries)} / $totalEntries',
                ),
                IconButton(
                  key: const ValueKey('catalog-next-page'),
                  tooltip: 'Next titles',
                  onPressed:
                      pageLoading ||
                          pageOffset + libraryPageSize >= totalEntries
                      ? null
                      : () => onPageRequested!(pageOffset + libraryPageSize),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
          if (countries.length >= 2 &&
              MediaQuery.sizeOf(context).width < 1100) ...<Widget>[
            SizedBox(
              height: shortWindow ? 40 : 58,
              child: ListView(
                key: const ValueKey('live-country-rail'),
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (final country in <LiveCountry?>[null, ...countries])
                    Padding(
                      padding: const EdgeInsets.only(right: TviumSpacing.sm),
                      child: ChoiceChip(
                        key: ValueKey('country-${country?.code ?? 'all'}'),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (country == null)
                              const Icon(Icons.public_rounded, size: 22)
                            else
                              ClipOval(
                                child: Image.asset(
                                  country.flagAsset,
                                  key: ValueKey(
                                    'country-flag-rail-${country.code}',
                                  ),
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(width: TviumSpacing.xs),
                            Text(country?.name ?? 'All countries'),
                          ],
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
              groups.isNotEmpty &&
              MediaQuery.sizeOf(context).width < 720) ...<Widget>[
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
                if (destination != _CatalogDestination.live) {
                  if (constraints.maxWidth < 720) return catalog;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        key: const ValueKey('catalog-group-sidebar'),
                        width: constraints.maxWidth < 1050 ? 180 : 220,
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
                if (constraints.maxWidth >= 1050) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        key: const ValueKey('live-country-sidebar'),
                        width: constraints.maxWidth < 1250 ? 170 : 190,
                        child: _CountrySidebar(
                          countries: countries,
                          selectedCode: activeCountryCode,
                          onSelected: onCountrySelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      SizedBox(
                        key: const ValueKey('catalog-group-sidebar'),
                        width: constraints.maxWidth < 1250 ? 170 : 210,
                        child: _GroupSidebar(
                          groups: groups,
                          selectedGroup: selectedGroup,
                          onSelected: onGroupSelected,
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              'Channels · ${visible.length}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (showLocalChannelSearch) ...<Widget>[
                              const SizedBox(height: TviumSpacing.sm),
                              TextField(
                                key: const ValueKey('live-channel-search'),
                                controller: channelSearchController,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search_rounded),
                                  hintText: 'Search channels',
                                  isDense: true,
                                ),
                                onChanged: onQueryChanged,
                              ),
                            ],
                            const SizedBox(height: TviumSpacing.sm),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  TviumRadius.surface,
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: ColoredBox(
                                    key: const ValueKey('live-channel-glass'),
                                    color: const Color(0x400B2131),
                                    child: media,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: TviumSpacing.md),
                      SizedBox(
                        key: const ValueKey('catalog-player'),
                        width: constraints.maxWidth * 0.27,
                        child: _LivePreviewPanel(
                          entry: previewEntry,
                          schedule: epgSchedules[previewEntry?.id],
                          selectedEntry: selectedEntry,
                          engine: playbackEngine,
                          onPlay: previewEntry?.isPlayable == true
                              ? () => onPlay(previewEntry!)
                              : null,
                          favorite:
                              previewEntry != null &&
                              favorites.contains(
                                previewEntry.locator(profileId),
                              ),
                          onFavorite: previewEntry == null
                              ? null
                              : () => onFavoriteToggled(previewEntry),
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
    return pageContent;
  }
}

final class _CatalogFeature extends ConsumerWidget {
  const _CatalogFeature({
    required this.destination,
    required this.entry,
    required this.count,
    required this.onPlay,
    required this.onDetails,
  });

  final _CatalogDestination destination;
  final _LibraryEntry? entry;
  final int count;
  final ValueChanged<_LibraryEntry> onPlay;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: metadataEnabled,
      builder: (context, enabled, _) => _buildFeature(context, ref, enabled),
    );
  }

  Widget _buildFeature(BuildContext context, WidgetRef ref, bool enabled) {
    final item = entry;
    final overlay = item == null || !enabled
        ? null
        : ref
              .watch(
                metadataHeroOverlayProvider((
                  sourceId: item.sourceId,
                  entryId: item.id,
                  title: item.name,
                  kind: item.kind,
                  enabled: true,
                )),
              )
              .value;
    final posterUri = overlay?.posterUri ?? item?.imageUri;
    final hasPoster =
        posterUri?.hasScheme == true &&
        (overlay?.posterUri != null ||
            destination == _CatalogDestination.movies ||
            item?.xtreamSeriesId != null);
    return DecoratedBox(
      key: const ValueKey('catalog-feature'),
      decoration: const BoxDecoration(color: Color(0xFF071A2A)),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (overlay?.backdropUri case final backdrop?)
            ArtworkImage(
              key: const ValueKey('catalog-feature-backdrop'),
              sourceId: item!.sourceId,
              entryId: item.id,
              role: 'verified-backdrop',
              uri: backdrop,
              fit: BoxFit.cover,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: overlay?.backdropUri == null
                    ? const <Color>[Color(0xFF102D42), Color(0xFF071A2A)]
                    : const <Color>[Color(0xE6102D42), Color(0xF2071A2A)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TviumSpacing.sm),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(TviumRadius.control),
                    child: hasPoster
                        ? ArtworkImage(
                            key: const ValueKey('catalog-feature-poster'),
                            sourceId: item!.sourceId,
                            entryId: item.id,
                            role: overlay?.posterUri == null
                                ? 'poster'
                                : 'verified-poster',
                            uri: posterUri,
                            fit: BoxFit.cover,
                          )
                        : const ColoredBox(
                            color: Color(0xFF163044),
                            child: Center(
                              child: Icon(Icons.movie_outlined, size: 44),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: TviumSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        _destinationLabel(destination),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: TviumColors.accentDark),
                      ),
                      const SizedBox(height: TviumSpacing.xs),
                      Text(
                        item?.displayName ?? 'No titles available',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: TviumSpacing.xs),
                      Text('$count ${count == 1 ? 'title' : 'titles'}'),
                      if (overlay?.overview case final overview?) ...<Widget>[
                        const SizedBox(height: TviumSpacing.xs),
                        Text(
                          overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (item != null) ...<Widget>[
                        const SizedBox(height: TviumSpacing.sm),
                        Wrap(
                          spacing: TviumSpacing.sm,
                          runSpacing: TviumSpacing.xs,
                          children: <Widget>[
                            if (destination == _CatalogDestination.movies &&
                                item.isPlayable)
                              FilledButton.icon(
                                onPressed: () => onPlay(item),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play'),
                              ),
                            OutlinedButton(
                              onPressed: onDetails,
                              child: const Text('View details'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _CountrySidebar extends StatefulWidget {
  const _CountrySidebar({
    required this.countries,
    required this.selectedCode,
    required this.onSelected,
  });

  final List<LiveCountry> countries;
  final String selectedCode;
  final ValueChanged<String>? onSelected;

  @override
  State<_CountrySidebar> createState() => _CountrySidebarState();
}

final class _CountrySidebarState extends State<_CountrySidebar> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final options = <LiveCountry?>[null, ...widget.countries]
        .where(
          (country) =>
              needle.isEmpty ||
              (country?.name.toLowerCase().contains(needle) ?? false) ||
              (country?.code.toLowerCase().contains(needle) ?? false),
        )
        .toList(growable: false);
    return Column(
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
            'Countries · ${widget.countries.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TviumSpacing.xs,
            0,
            TviumSpacing.xs,
            TviumSpacing.sm,
          ),
          child: TextField(
            key: const ValueKey('live-country-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search countries',
              isDense: true,
            ),
            onChanged: (value) => setState(() => query = value),
          ),
        ),
        Expanded(
          child: options.isEmpty
              ? const Center(child: Text('No countries found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    TviumSpacing.xs,
                    0,
                    TviumSpacing.xs,
                    TviumSpacing.sm,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final country = options[index];
                    final code = country?.code ?? 'ALL';
                    final selected = code == widget.selectedCode;
                    final artwork = countryArtwork[code];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: TviumSpacing.xs),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('country-${country?.code ?? 'all'}'),
                          onTap: () => widget.onSelected?.call(code),
                          borderRadius: BorderRadius.circular(
                            TviumRadius.control,
                          ),
                          child: Ink(
                            height: selected ? 150 : 68,
                            decoration: BoxDecoration(
                              color: const Color(0x88183044),
                              borderRadius: BorderRadius.circular(
                                TviumRadius.control,
                              ),
                              border: Border.all(
                                color: selected
                                    ? TviumColors.accentDark
                                    : Colors.white.withValues(alpha: 0.12),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                TviumRadius.control,
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  if (artwork != null)
                                    Image.asset(
                                      artwork,
                                      key: ValueKey('country-art-$code'),
                                      fit: BoxFit.cover,
                                    ),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: <Color>[
                                          Color(0x66071320),
                                          Color(0xEB071320),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(
                                      TviumSpacing.sm,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        if (country == null)
                                          Icon(
                                            Icons.public_rounded,
                                            size: selected ? 40 : 28,
                                          )
                                        else
                                          ClipOval(
                                            child: Image.asset(
                                              country.flagAsset,
                                              key: ValueKey(
                                                'country-flag-$code',
                                              ),
                                              width: selected ? 44 : 32,
                                              height: selected ? 44 : 32,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        const SizedBox(width: TviumSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            country?.name ?? 'All countries',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: selected ? 16 : 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

final class _LivePreviewPanel extends StatelessWidget {
  const _LivePreviewPanel({
    required this.entry,
    required this.schedule,
    required this.selectedEntry,
    required this.engine,
    this.onPlay,
    this.favorite = false,
    this.onFavorite,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onOpenChannelSwitcher,
  });

  final _LibraryEntry? entry;
  final EpgNowNext? schedule;
  final _LibraryEntry? selectedEntry;
  final PlaybackEngine? engine;
  final VoidCallback? onPlay;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onOpenChannelSwitcher;

  @override
  Widget build(BuildContext context) {
    final current = schedule?.current;
    final next = schedule?.next;
    final currentDuration = current == null
        ? Duration.zero
        : current.stopUtc.difference(current.startUtc);
    final currentProgress = currentDuration.inMilliseconds > 0
        ? (DateTime.now().toUtc().difference(current!.startUtc).inMilliseconds /
                  currentDuration.inMilliseconds)
              .clamp(0.0, 1.0)
        : null;
    String timeRange(EpgProgramme programme) {
      String time(DateTime utc) {
        final local = utc.toLocal();
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }

      return '${time(programme.startUtc)} – ${time(programme.stopUtc)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _PlayerPanel(
            selectedEntry: selectedEntry,
            engine: engine,
            onPreviousChannel: onPreviousChannel,
            onNextChannel: onNextChannel,
            onOpenChannelSwitcher: onOpenChannelSwitcher,
          ),
        ),
        const SizedBox(height: TviumSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('live-preview-info'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry?.displayName ?? 'Select a channel',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: TviumSpacing.sm),
                if (current == null)
                  const Text('Program guide unavailable')
                else ...<Widget>[
                  Text('Now · ${current.title}'),
                  const SizedBox(height: TviumSpacing.xs),
                  Text(timeRange(current)),
                  if (currentProgress != null) ...<Widget>[
                    const SizedBox(height: TviumSpacing.sm),
                    LinearProgressIndicator(
                      key: const ValueKey('live-preview-progress'),
                      value: currentProgress,
                    ),
                  ],
                  if (current.description case final description?) ...<Widget>[
                    const SizedBox(height: TviumSpacing.xs),
                    Text(description),
                  ],
                ],
                if (next != null) ...<Widget>[
                  const Divider(height: TviumSpacing.lg),
                  Text('Up next · ${next.title}'),
                  const SizedBox(height: TviumSpacing.xs),
                  Text(timeRange(next)),
                ] else if (current != null) ...<Widget>[
                  const Divider(height: TviumSpacing.lg),
                  const Text('Up next · Not available'),
                ],
                const SizedBox(height: TviumSpacing.md),
                Wrap(
                  spacing: TviumSpacing.sm,
                  runSpacing: TviumSpacing.sm,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const ValueKey('live-preview-play'),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('live-preview-guide'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('TV Guide'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(entry?.displayName ?? 'Select a channel'),
                              const SizedBox(height: TviumSpacing.md),
                              Text(
                                current == null
                                    ? 'Now · Not available'
                                    : 'Now · ${current.title}',
                              ),
                              const SizedBox(height: TviumSpacing.sm),
                              Text(
                                next == null
                                    ? 'Up next · Not available'
                                    : 'Up next · ${next.title}',
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.view_list_rounded),
                      label: const Text('TV Guide'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('live-preview-favorite'),
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                      label: Text(favorite ? 'Saved' : 'Favorite'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
    return Column(
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
                      borderRadius: BorderRadius.circular(TviumRadius.control),
                    ),
                    leading: Icon(
                      _liveCategoryIcon(
                        group == null ? '' : liveCategoryLabel(group),
                      ),
                      key: ValueKey(
                        'live-category-icon-${group == null ? 'all' : liveCategoryLabel(group).toLowerCase()}',
                      ),
                      size: 22,
                      color: selected ? TviumColors.accentDark : Colors.white70,
                    ),
                    title: Text(
                      group == null
                          ? 'All categories'
                          : liveCategoryLabel(group),
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
    );
  }
}

IconData _liveCategoryIcon(String label) {
  final value = label.toLowerCase();
  if (value.contains('sport')) return Icons.emoji_events_outlined;
  if (value.contains('news') || value.contains('info')) {
    return Icons.newspaper_rounded;
  }
  if (value.contains('movie') ||
      value.contains('cinema') ||
      value.contains('film')) {
    return Icons.movie_outlined;
  }
  if (value.contains('music')) return Icons.music_note_rounded;
  if (value.contains('kid') || value.contains('child')) {
    return Icons.child_care_rounded;
  }
  if (value.contains('document') || value.contains('nature')) {
    return Icons.eco_outlined;
  }
  if (value.contains('entertainment')) return Icons.tv_rounded;
  return label.isEmpty ? Icons.grid_view_rounded : Icons.category_outlined;
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xA8102133),
      child: ListTile(
        minTileHeight: compact ? 60 : 72,
        contentPadding: EdgeInsets.symmetric(
          horizontal: TviumSpacing.sm,
          vertical: compact ? 0 : TviumSpacing.xs,
        ),
        onTap: onTap,
        leading: SizedBox.square(
          dimension: compact ? 44 : 56,
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
    this.prefetchMetadata = false,
    required this.schedule,
    required this.destination,
    required this.onTap,
    required this.favorite,
    required this.onFavorite,
  });

  final _LibraryEntry entry;
  final bool prefetchMetadata;
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
      color: const Color(0xB8102638),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TviumRadius.surface),
        side: const BorderSide(color: Color(0x44B8E8FF)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _CatalogArtwork(
                    entry: entry,
                    prefetchMetadata: prefetchMetadata,
                  ),
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

final class _CatalogArtwork extends ConsumerWidget {
  const _CatalogArtwork({
    super.key,
    required this.entry,
    this.prefetchMetadata = false,
  });

  final _LibraryEntry entry;
  final bool prefetchMetadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool>(
      valueListenable: metadataEnabled,
      builder: (context, enabled, _) => _buildArtwork(context, ref, enabled),
    );
  }

  Widget _buildArtwork(BuildContext context, WidgetRef ref, bool enabled) {
    final live = entry.kind == MediaKind.live;
    final overlay = live || !enabled
        ? null
        : prefetchMetadata
        ? ref
              .watch(
                metadataVisibleOverlayProvider((
                  sourceId: entry.sourceId,
                  entryId: entry.id,
                  title: entry.name,
                  kind: entry.kind,
                  enabled: true,
                )),
              )
              .value
        : ref
              .watch(
                metadataCachedOverlayProvider((
                  sourceId: entry.sourceId,
                  entryId: entry.id,
                  title: entry.name,
                  kind: entry.kind,
                  enabled: true,
                )),
              )
              .value;
    final uri = overlay?.posterUri ?? entry.imageUri;
    final episodeStillIsNotSeriesPoster =
        entry.kind == MediaKind.episode &&
        entry.seriesEpisodes.isNotEmpty &&
        entry.xtreamSeriesId == null;
    final fallback = Center(
      key: episodeStillIsNotSeriesPoster
          ? const ValueKey('catalog-series-placeholder')
          : live
          ? const ValueKey('live-logo-fallback')
          : null,
      child: Icon(
        _mediaIcon(entry.kind),
        size: live ? 30 : 46,
        color: Colors.white54,
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF163D58), Color(0xFF09141F)],
        ),
      ),
      child: episodeStillIsNotSeriesPoster && overlay?.posterUri == null
          ? fallback
          : Padding(
              padding: EdgeInsets.all(live ? 4 : 0),
              child: ArtworkImage(
                sourceId: entry.sourceId,
                entryId: entry.id,
                role: live
                    ? 'logo'
                    : overlay?.posterUri != null
                    ? 'verified-poster'
                    : 'poster',
                uri: uri,
                fit: live ? BoxFit.contain : BoxFit.cover,
                fallback: fallback,
              ),
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
    builder: (dialogContext) {
      final wide = MediaQuery.sizeOf(dialogContext).width >= 720;
      final details = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.kind == MediaKind.movie ? 'MOVIE' : 'TV SHOW',
              style: Theme.of(dialogContext).textTheme.labelLarge
                  ?.copyWith(color: TviumColors.accentDark),
            ),
            const SizedBox(height: TviumSpacing.sm),
            Text(
              entry.displayName,
              key: const ValueKey('title-details-heading'),
              style: Theme.of(dialogContext).textTheme.headlineMedium,
            ),
            if (entry.group != null) ...<Widget>[
              const SizedBox(height: TviumSpacing.sm),
              Text(entry.group!),
            ],
            const SizedBox(height: TviumSpacing.md),
            OnlineMetadataSummary(
              originalTitle: entry.name,
              kind: entry.kind,
              sourceId: entry.sourceId,
              entryId: entry.id,
            ),
          ],
        ),
      );
      return AlertDialog(
        key: const ValueKey('title-details'),
        content: SizedBox(
          width: wide ? 680 : 320,
          height: wide ? 320 : 410,
          child: wide
              ? Row(
                  children: <Widget>[
                    SizedBox(
                      width: 190,
                      child: _TitleDetailsPoster(entry: entry),
                    ),
                    const SizedBox(width: TviumSpacing.lg),
                    Expanded(child: details),
                  ],
                )
              : Column(
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      height: 180,
                      child: _TitleDetailsPoster(entry: entry),
                    ),
                    const SizedBox(height: TviumSpacing.md),
                    Expanded(child: details),
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
      );
    },
  );
}

final class _TitleDetailsPoster extends StatelessWidget {
  const _TitleDetailsPoster({required this.entry});

  final _LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final usePoster =
        entry.imageUri?.hasScheme == true &&
        (entry.kind == MediaKind.movie || entry.xtreamSeriesId != null);
    return ClipRRect(
      key: const ValueKey('title-details-poster'),
      borderRadius: BorderRadius.circular(TviumRadius.control),
      child: ColoredBox(
        color: const Color(0xFF163044),
        child: usePoster
            ? ArtworkImage(
                sourceId: entry.sourceId,
                entryId: entry.id,
                role: 'poster',
                uri: entry.imageUri,
                fit: BoxFit.cover,
              )
            : Center(child: Icon(_mediaIcon(entry.kind), size: 44)),
      ),
    );
  }
}

final class _SeriesDetailsBody extends StatelessWidget {
  const _SeriesDetailsBody({required this.entry, required this.child});

  final _LibraryEntry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final height = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      300.0,
      480.0,
    );
    return SizedBox(
      width: wide ? 700 : 320,
      height: height,
      child: wide
          ? Row(
              children: <Widget>[
                SizedBox(width: 180, child: _TitleDetailsPoster(entry: entry)),
                const SizedBox(width: TviumSpacing.lg),
                Expanded(child: child),
              ],
            )
          : Column(
              children: <Widget>[
                SizedBox(
                  width: 100,
                  height: 150,
                  child: _TitleDetailsPoster(entry: entry),
                ),
                const SizedBox(height: TviumSpacing.sm),
                Expanded(child: child),
              ],
            ),
    );
  }
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
      content: _SeriesDetailsBody(
        entry: entry,
        child: ListView(
          children: <Widget>[
            OnlineMetadataSummary(
              originalTitle: entry.name,
              kind: entry.kind,
              sourceId: entry.sourceId,
              entryId: entry.id,
            ),
            const SizedBox(height: TviumSpacing.sm),
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
      content: _SeriesDetailsBody(
        entry: entry,
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
                OnlineMetadataSummary(
                  originalTitle: entry.name,
                  kind: entry.kind,
                  sourceId: entry.sourceId,
                  entryId: entry.id,
                ),
                const SizedBox(height: TviumSpacing.sm),
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

final class _PlayerPanel extends ConsumerStatefulWidget {
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
  ConsumerState<_PlayerPanel> createState() => _PlayerPanelState();
}

final class _PlayerPanelState extends ConsumerState<_PlayerPanel> {
  bool _fullScreen = false;
  double _volume = 1;

  Future<void> _openFullScreen() async {
    final engine = widget.engine;
    if (engine == null) return;
    setState(() => _fullScreen = true);
    final viewBuilder = ref.read(playbackViewBuilderProvider);
    Timer? hideControls;
    var controlsVisible = true;
    try {
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void scheduleHide() {
              hideControls?.cancel();
              hideControls = Timer(const Duration(seconds: 3), () {
                if (dialogContext.mounted) {
                  setDialogState(() => controlsVisible = false);
                }
              });
            }

            void revealControls() {
              if (!controlsVisible) {
                setDialogState(() => controlsVisible = true);
              }
              scheduleHide();
            }

            if (hideControls == null) scheduleHide();
            return Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.keyF) {
                  Navigator.of(dialogContext).pop();
                  return KeyEventResult.handled;
                }
                if (event is KeyDownEvent) revealControls();
                return KeyEventResult.ignored;
              },
              child: Dialog.fullscreen(
                child: Listener(
                  onPointerDown: (_) => revealControls(),
                  onPointerHover: (_) => revealControls(),
                  child: ColoredBox(
                    key: const ValueKey('live-fullscreen-player'),
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        viewBuilder(engine),
                        if (controlsVisible)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SafeArea(
                              child: _controls(
                                engine,
                                fullScreen: true,
                                onVolumeChanged: (value) {
                                  setDialogState(() => _volume = value);
                                  engine.setVolume(value);
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      hideControls?.cancel();
      if (mounted) setState(() => _fullScreen = false);
    }
  }

  Widget _controls(
    PlaybackEngine engine, {
    required bool fullScreen,
    ValueChanged<double>? onVolumeChanged,
  }) {
    return SizedBox(
      key: ValueKey(
        fullScreen ? 'live-fullscreen-controls' : 'live-preview-controls',
      ),
      height: 56,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: TviumSpacing.sm),
        color: Colors.black.withValues(alpha: 0.72),
        child: StreamBuilder<PlaybackState>(
          stream: engine.state,
          initialData: engine.currentState,
          builder: (context, snapshot) {
            final playing = snapshot.data?.phase == PlaybackPhase.playing;
            final leading = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  key: ValueKey(
                    fullScreen ? 'live-fullscreen-play' : 'live-player-play',
                  ),
                  tooltip: playing ? 'Pause' : 'Play',
                  onPressed: () => playing ? engine.pause() : engine.play(),
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                if (fullScreen) ...<Widget>[
                  const Icon(Icons.volume_up_rounded, size: 18),
                  SizedBox(
                    width: 110,
                    child: Slider(
                      key: const ValueKey('live-fullscreen-volume'),
                      value: _volume,
                      onChanged: onVolumeChanged,
                    ),
                  ),
                ] else if (widget.onOpenChannelSwitcher != null)
                  IconButton(
                    key: const ValueKey('live-channel-switcher-button'),
                    tooltip: 'Switch channel',
                    onPressed: widget.onOpenChannelSwitcher,
                    icon: const Icon(Icons.search_rounded),
                  ),
              ],
            );
            final channelControls = Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.onPreviousChannel != null) ...<Widget>[
                  IconButton(
                    key: const ValueKey('live-previous-channel'),
                    tooltip: 'Previous channel',
                    onPressed: widget.onPreviousChannel,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('live-next-channel'),
                    tooltip: 'Next channel',
                    onPressed: widget.onNextChannel,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ],
            );
            final fullScreenButton = !fullScreen
                ? IconButton(
                    key: const ValueKey('live-player-fullscreen'),
                    tooltip: 'Full screen',
                    onPressed: _openFullScreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                  )
                : IconButton(
                    key: const ValueKey('live-fullscreen-exit'),
                    tooltip: 'Exit full screen',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  );
            return LayoutBuilder(
              builder: (context, constraints) {
                // Equal side slots keep the channel buttons at the actual
                // center, regardless of the wider volume controls on the left.
                if (constraints.maxWidth < (fullScreen ? 450 : 300)) {
                  return Row(
                    children: <Widget>[
                      leading,
                      const Spacer(),
                      channelControls,
                      fullScreenButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: leading,
                      ),
                    ),
                    channelControls,
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: fullScreenButton,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackEngine = widget.engine;
    return Focus(
      key: const ValueKey('live-player-focus'),
      canRequestFocus: widget.onNextChannel != null,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.keyF &&
            playbackEngine != null) {
          unawaited(_openFullScreen());
          return KeyEventResult.handled;
        }
        if (widget.onNextChannel == null) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.pageUp) {
          widget.onPreviousChannel?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.pageDown) {
          widget.onNextChannel?.call();
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
            : _fullScreen
            ? const SizedBox.expand()
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ref.watch(playbackViewBuilderProvider)(playbackEngine),
                  if (widget.selectedEntry != null)
                    Positioned(
                      top: TviumSpacing.xs,
                      left: TviumSpacing.sm,
                      right: TviumSpacing.sm,
                      child: Text(
                        widget.selectedEntry!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          shadows: <Shadow>[
                            Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _controls(playbackEngine, fullScreen: false),
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

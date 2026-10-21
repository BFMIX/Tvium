import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';
import 'package:tvium_database/tvium_database.dart';

import '../artwork/artwork_image.dart';
import '../library/source_refresh_schedule.dart';
import '../updates/update_checker.dart';
import 'metadata_gateway_client.dart';
import 'metadata_overlay_store.dart';

final metadataEnabled = ValueNotifier<bool>(false);

Future<void> _persistMetadataConsent(
  BuildContext context,
  MetadataConsentStore store,
  bool enabled,
) async {
  try {
    await store.write(enabled);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not save metadata preference.')),
      );
    }
  }
}

enum SettingsSection { playlists, metadata, parental, guide, updates, about }

Future<void> showSettingsPages(
  BuildContext context, {
  required Future<void> Function(SettingsSection section) openSection,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          for (final (section, title, icon)
              in <(SettingsSection, String, IconData)>[
                (
                  SettingsSection.playlists,
                  'Playlists',
                  Icons.playlist_play_rounded,
                ),
                (
                  SettingsSection.metadata,
                  'Metadata',
                  Icons.movie_filter_outlined,
                ),
                (
                  SettingsSection.parental,
                  'Parental controls',
                  Icons.shield_outlined,
                ),
                (
                  SettingsSection.guide,
                  'Programme guide',
                  Icons.calendar_month_outlined,
                ),
                (
                  SettingsSection.updates,
                  'Updates',
                  Icons.system_update_rounded,
                ),
                (
                  SettingsSection.about,
                  'About and licenses',
                  Icons.info_outline_rounded,
                ),
              ])
            ListTile(
              key: ValueKey('settings-page-${section.name}'),
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openSection(section),
            ),
        ],
      ),
    ),
  ),
);
Future<String?> _renameSource(
  BuildContext context,
  IptvSource source,
  Future<void> Function(IptvSource source, String name) onRename,
) => showDialog<String>(
  context: context,
  builder: (context) => _RenameSourceDialog(source: source, onRename: onRename),
);

final class _RenameSourceDialog extends StatefulWidget {
  const _RenameSourceDialog({required this.source, required this.onRename});

  final IptvSource source;
  final Future<void> Function(IptvSource source, String name) onRename;

  @override
  State<_RenameSourceDialog> createState() => _RenameSourceDialogState();
}

final class _RenameSourceDialogState extends State<_RenameSourceDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.source.displayName,
  );
  String? _validation;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename playlist'),
    content: TextField(
      key: const ValueKey('source-name-field'),
      controller: _controller,
      autofocus: true,
      maxLength: 120,
      decoration: InputDecoration(
        labelText: 'Playlist name',
        errorText: _validation,
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () async {
          final name = _controller.text.trim();
          if (name.isEmpty) {
            setState(() => _validation = 'Enter a playlist name.');
            return;
          }
          await widget.onRename(widget.source, name);
          if (context.mounted) Navigator.of(context).pop(name);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

Future<bool> _confirmRemoveSource(
  BuildContext context,
  IptvSource source,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove playlist?'),
        content: Text(
          'Remove ${source.displayName} from this profile? It remains available to other profiles using it.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ) ??
    false;

Future<void> showLibrarySettings(
  BuildContext context, {
  required bool configured,
  MetadataConsentStore? metadataConsentStore,
  SettingsSection? section,
  Future<String> Function()? onImportEpgFile,
  Future<String> Function(Uri uri)? onImportEpgUrl,
  Future<String> Function()? onRefreshSources,
  Future<String> Function(IptvSource source)? onRefreshSource,
  Future<SourceRefreshInterval> Function(IptvSource source)? refreshIntervalFor,
  Future<DateTime?> Function(IptvSource source)? lastRefreshAttemptFor,
  Future<void> Function(IptvSource source, SourceRefreshInterval interval)?
  onRefreshIntervalChanged,
  List<IptvSource> sources = const <IptvSource>[],
  Future<void> Function()? onAddPlaylist,
  Future<void> Function(IptvSource source, String name)? onRenameSource,
  Future<void> Function(IptvSource source)? onRemoveSource,
  bool parentalConfigured = false,
  bool parentalUnlocked = false,
  List<String> availableParentalCategories = const <String>[],
  Set<String> initialBlockedContent = const <String>{'adult'},
  Future<String> Function(String pin, Set<String> blockedContent)?
  onSaveParentalPin,
  Future<String> Function(String pin)? onUnlockParental,
}) async {
  final epgUrlController = TextEditingController();
  final parentalPinController = TextEditingController();
  String? epgStatus;
  String? parentalStatus;
  String? updateStatus;
  AvailableUpdate? availableUpdate;
  var checkingUpdates = false;
  var importingEpg = false;
  String? refreshingSourceId;
  var dialogParentalConfigured = parentalConfigured;
  var dialogParentalUnlocked = parentalUnlocked;
  final dialogBlockedContent = initialBlockedContent
      .map((value) => value.trim().toLowerCase())
      .where((value) => value.isNotEmpty)
      .toSet();
  final dialogSources = List<IptvSource>.of(sources);
  final title = switch (section) {
    SettingsSection.playlists => 'Playlists',
    SettingsSection.metadata => 'Metadata',
    SettingsSection.parental => 'Parental controls',
    SettingsSection.guide => 'Programme guide',
    SettingsSection.updates => 'Updates',
    SettingsSection.about => 'About and licenses',
    null => 'Settings',
  };
  Widget buildSettings(BuildContext routeContext) => StatefulBuilder(
    builder: (context, setDialogState) {
      final content = SizedBox(
        width: section == null ? 440 : 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section == null ||
                  section == SettingsSection.playlists) ...<Widget>[
                const Text(
                  'Titles are organized locally. Original playlist data is preserved.',
                ),
                if (onAddPlaylist != null || dialogSources.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Playlists',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final source in dialogSources)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.displayName),
                      subtitle:
                          refreshIntervalFor == null &&
                              lastRefreshAttemptFor == null
                          ? null
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (refreshIntervalFor != null)
                                  FutureBuilder<SourceRefreshInterval>(
                                    future: refreshIntervalFor(source),
                                    builder: (context, snapshot) => Text(
                                      'Refresh: ${snapshot.data?.label ?? 'Loading'}',
                                    ),
                                  ),
                                if (lastRefreshAttemptFor != null)
                                  FutureBuilder<DateTime?>(
                                    future: lastRefreshAttemptFor(source),
                                    builder: (context, snapshot) {
                                      final checked = snapshot.data;
                                      final label =
                                          snapshot.connectionState !=
                                              ConnectionState.done
                                          ? 'Loading check time…'
                                          : checked == null
                                          ? 'Never checked'
                                          : 'Last checked: ${checked.toLocal().toString().substring(0, 16)}';
                                      return Text(label);
                                    },
                                  ),
                              ],
                            ),
                      trailing: Wrap(
                        spacing: 4,
                        children: <Widget>[
                          if (onRefreshIntervalChanged != null)
                            PopupMenuButton<SourceRefreshInterval>(
                              key: ValueKey('refresh-interval-${source.id}'),
                              tooltip: 'Refresh schedule',
                              icon: const Icon(Icons.schedule_rounded),
                              onSelected: (interval) async {
                                await onRefreshIntervalChanged(
                                  source,
                                  interval,
                                );
                                if (context.mounted) setDialogState(() {});
                              },
                              itemBuilder: (context) => [
                                for (final interval
                                    in SourceRefreshInterval.values)
                                  PopupMenuItem(
                                    value: interval,
                                    child: Text(interval.label),
                                  ),
                              ],
                            ),
                          IconButton(
                            key: ValueKey('refresh-source-${source.id}'),
                            tooltip: 'Refresh playlist',
                            onPressed:
                                onRefreshSource == null ||
                                    importingEpg ||
                                    refreshingSourceId != null
                                ? null
                                : () async {
                                    setDialogState(() {
                                      refreshingSourceId = source.id;
                                      epgStatus = 'Refreshing playlist…';
                                    });
                                    final message = await onRefreshSource(
                                      source,
                                    );
                                    if (context.mounted) {
                                      setDialogState(() {
                                        refreshingSourceId = null;
                                        epgStatus = message;
                                      });
                                    }
                                  },
                            icon: refreshingSourceId == source.id
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded),
                          ),
                          IconButton(
                            key: ValueKey('rename-source-${source.id}'),
                            tooltip: 'Rename playlist',
                            onPressed: onRenameSource == null
                                ? null
                                : () async {
                                    final renamed = await _renameSource(
                                      context,
                                      source,
                                      onRenameSource,
                                    );
                                    if (renamed != null && context.mounted) {
                                      setDialogState(() {
                                        final index = dialogSources.indexWhere(
                                          (candidate) =>
                                              candidate.id == source.id,
                                        );
                                        dialogSources[index] = IptvSource(
                                          id: source.id,
                                          displayName: renamed,
                                          identityDigest: source.identityDigest,
                                          secretReference:
                                              source.secretReference,
                                        );
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            key: ValueKey('remove-source-${source.id}'),
                            tooltip: 'Remove playlist',
                            onPressed: onRemoveSource == null
                                ? null
                                : () async {
                                    final confirmed =
                                        await _confirmRemoveSource(
                                          context,
                                          source,
                                        );
                                    if (!confirmed) return;
                                    await onRemoveSource(source);
                                    if (context.mounted) {
                                      setDialogState(
                                        () => dialogSources.removeWhere(
                                          (candidate) =>
                                              candidate.id == source.id,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  if (onAddPlaylist != null)
                    OutlinedButton.icon(
                      key: const ValueKey('add-playlist'),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await onAddPlaylist();
                      },
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Add playlist'),
                    ),
                ],
                if (onRefreshSources != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('refresh-sources'),
                    onPressed: importingEpg
                        ? null
                        : () async {
                            setDialogState(() {
                              importingEpg = true;
                              epgStatus = 'Refreshing connected sources…';
                            });
                            final message = await onRefreshSources();
                            if (context.mounted) {
                              setDialogState(() {
                                importingEpg = false;
                                epgStatus = message;
                              });
                            }
                          },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Refresh connected sources'),
                  ),
                ],
                if (refreshingSourceId != null) const LinearProgressIndicator(),
                if (epgStatus != null &&
                    section == SettingsSection.playlists) ...[
                  const SizedBox(height: 8),
                  Text(
                    epgStatus!,
                    key: const ValueKey('playlist-refresh-status'),
                  ),
                ],
              ],
              if (section == null ||
                  section == SettingsSection.metadata) ...<Widget>[
                ValueListenableBuilder<bool>(
                  valueListenable: metadataEnabled,
                  builder: (context, enabled, _) => SwitchListTile(
                    key: const ValueKey('online-metadata-toggle'),
                    title: const Text('Online metadata'),
                    subtitle: Text(
                      configured
                          ? 'Send cleaned titles, content type, year and language when viewing details or featured artwork. Saved on this device.'
                          : 'Online metadata is not configured in this build.',
                    ),
                    value: enabled,
                    onChanged: configured
                        ? (value) {
                            metadataEnabled.value = value;
                            if (metadataConsentStore != null) {
                              unawaited(
                                _persistMetadataConsent(
                                  context,
                                  metadataConsentStore,
                                  value,
                                ),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ],
              if (section == null ||
                  section == SettingsSection.parental) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  'Parental controls',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  dialogParentalConfigured
                      ? dialogParentalUnlocked
                            ? 'Protected content is unlocked for this session.'
                            : 'Protected categories are hidden.'
                      : 'Set a PIN to hide protected categories.',
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('parental-adult-labels'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hide adult-labelled content'),
                  value: dialogBlockedContent.contains('adult'),
                  onChanged: (selected) => setDialogState(() {
                    if (selected) {
                      dialogBlockedContent.add('adult');
                    } else {
                      dialogBlockedContent.remove('adult');
                    }
                  }),
                ),
                if (availableParentalCategories.isNotEmpty) ...<Widget>[
                  const Text('Protected categories'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final category in availableParentalCategories)
                        FilterChip(
                          key: ValueKey(
                            'parental-category-${category.toLowerCase()}',
                          ),
                          label: Text(category),
                          selected: dialogBlockedContent.contains(
                            category.toLowerCase(),
                          ),
                          onSelected: (selected) => setDialogState(() {
                            final value = category.toLowerCase();
                            if (selected) {
                              dialogBlockedContent.add(value);
                            } else {
                              dialogBlockedContent.remove(value);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  key: const ValueKey('parental-pin-field'),
                  controller: parentalPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: '4 to 8 digit PIN',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      key: const ValueKey('parental-primary-action'),
                      onPressed:
                          (dialogParentalConfigured && !dialogParentalUnlocked
                              ? onUnlockParental == null
                              : onSaveParentalPin == null)
                          ? null
                          : () async {
                              final unlocking =
                                  dialogParentalConfigured &&
                                  !dialogParentalUnlocked;
                              final message = unlocking
                                  ? await onUnlockParental!(
                                      parentalPinController.text,
                                    )
                                  : await onSaveParentalPin!(
                                      parentalPinController.text,
                                      Set<String>.unmodifiable(
                                        dialogBlockedContent,
                                      ),
                                    );
                              parentalPinController.clear();
                              if (context.mounted) {
                                setDialogState(() {
                                  parentalStatus = message;
                                  if (message == 'Parental controls enabled.') {
                                    dialogParentalConfigured = true;
                                    dialogParentalUnlocked = false;
                                  } else if (message ==
                                      'Protected content unlocked for this session.') {
                                    dialogParentalUnlocked = true;
                                  }
                                });
                              }
                            },
                      icon: Icon(
                        dialogParentalConfigured && !dialogParentalUnlocked
                            ? Icons.lock_open_rounded
                            : Icons.shield_outlined,
                      ),
                      label: Text(
                        dialogParentalConfigured && !dialogParentalUnlocked
                            ? 'Unlock'
                            : dialogParentalConfigured
                            ? 'Change PIN'
                            : 'Enable',
                      ),
                    ),
                  ],
                ),
                if (parentalStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(parentalStatus!),
                  ),
              ],
              if (section == null ||
                  section == SettingsSection.guide) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  'Programme guide',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('epg-url-field'),
                  controller: epgUrlController,
                  obscureText: true,
                  enabled: !importingEpg,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS XMLTV URL',
                    hintText: 'Kept private on this device',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('epg-import-file'),
                      onPressed: importingEpg || onImportEpgFile == null
                          ? null
                          : () async {
                              setDialogState(() => importingEpg = true);
                              final message = await onImportEpgFile();
                              if (context.mounted) {
                                setDialogState(() {
                                  importingEpg = false;
                                  epgStatus = message;
                                });
                              }
                            },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Import XMLTV file'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('epg-import-url'),
                      onPressed: importingEpg || onImportEpgUrl == null
                          ? null
                          : () async {
                              final uri = Uri.tryParse(
                                epgUrlController.text.trim(),
                              );
                              if (uri == null ||
                                  uri.scheme != 'https' ||
                                  !uri.hasAuthority) {
                                setDialogState(
                                  () => epgStatus = 'Enter a valid HTTPS URL.',
                                );
                                return;
                              }
                              setDialogState(() => importingEpg = true);
                              final message = await onImportEpgUrl(uri);
                              if (context.mounted) {
                                setDialogState(() {
                                  importingEpg = false;
                                  epgStatus = message;
                                  epgUrlController.clear();
                                });
                              }
                            },
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: const Text('Import guide'),
                    ),
                  ],
                ),
                if (importingEpg) const LinearProgressIndicator(),
                if (epgStatus != null && section != SettingsSection.playlists)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(epgStatus!),
                  ),
              ],
              if (section == null ||
                  section == SettingsSection.updates) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  installedReleaseTag.isEmpty
                      ? 'This is a development build. Update checks start with a tagged release.'
                      : 'Installed release: $installedReleaseTag',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('check-for-updates'),
                  onPressed: installedReleaseTag.isEmpty || checkingUpdates
                      ? null
                      : () async {
                          setDialogState(() => checkingUpdates = true);
                          final checker = UpdateChecker();
                          try {
                            final result = await checker.check(
                              installedReleaseTag,
                            );
                            if (context.mounted) {
                              setDialogState(() {
                                availableUpdate = result;
                                updateStatus = result == null
                                    ? 'You are up to date.'
                                    : 'New release available: ${result.tag}';
                              });
                            }
                          } on UpdateCheckException {
                            if (context.mounted) {
                              setDialogState(
                                () => updateStatus = 'Could not check for updates. Try again later.',
                              );
                            }
                          } finally {
                            checker.close();
                            if (context.mounted) {
                              setDialogState(() => checkingUpdates = false);
                            }
                          }
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check for updates'),
                ),
                if (checkingUpdates) const LinearProgressIndicator(),
                if (updateStatus != null) Text(updateStatus!),
                if (availableUpdate != null) ...<Widget>[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: availableUpdate!.page.toString()),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy release link'),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Automatic installation will be available after signed update packages are configured for each platform.',
                ),
              ],
              if (section == null ||
                  section == SettingsSection.about) ...<Widget>[
                const SizedBox(height: 16),
                const Text(
                  'Data sources',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'This product uses the TMDB API but is not endorsed or certified by TMDB.\n'
                  'TVmaze: CC BY-SA. Wikidata structured data: CC0. IPTV-org channel reference: Unlicense.\n'
                  'Artwork may have separate rights. Source and licensing information accompany each result.',
                ),
              ],
            ],
          ),
        ),
      );
      if (section != null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: content),
            ),
          ),
        );
      }
      return AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
  if (section == null) {
    await showDialog<void>(context: context, builder: buildSettings);
  } else {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: buildSettings));
  }
  epgUrlController.dispose();
  parentalPinController.dispose();
}

final class OnlineMetadataSummary extends ConsumerStatefulWidget {
  const OnlineMetadataSummary({
    required this.originalTitle,
    required this.kind,
    this.sourceId,
    this.entryId,
    super.key,
  });

  final String originalTitle;
  final MediaKind kind;
  final String? sourceId;
  final String? entryId;

  @override
  ConsumerState<OnlineMetadataSummary> createState() =>
      _OnlineMetadataSummaryState();
}

final class _OnlineMetadataSummaryState
    extends ConsumerState<OnlineMetadataSummary> {
  EnrichedMetadata? _result;
  bool _uncertain = false;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (metadataEnabled.value) Future.microtask(_restoreThenLookup);
  }

  Future<void> _restoreThenLookup() async {
    final sourceId = widget.sourceId;
    final entryId = widget.entryId;
    if (sourceId != null && entryId != null) {
      try {
        final cached = await ref
            .read(metadataOverlayStoreProvider)
            .read(sourceId: sourceId, entryId: entryId);
        if (cached != null && mounted) {
          setState(() {
            _result = EnrichedMetadata(
              candidate: MetadataCandidate(
                provider: cached.provider,
                id: cached.providerId,
                title: cached.title,
                kind: widget.kind,
              ),
              overview: cached.overview,
              posterUri: cached.posterUri,
              backdropUri: cached.backdropUri,
            );
          });
        }
      } on Object {
        // Optional cached data must not prevent an online lookup.
      }
    }
    await _lookup();
  }

  Future<void> _lookup() async {
    final client = ref.read(metadataGatewayProvider);
    if (!mounted || !metadataEnabled.value || client == null) return;
    final query = const PlaylistTitleNormalizer().normalize(
      widget.originalTitle,
      kind: widget.kind,
    );
    setState(() => _loading = true);
    try {
      final rows = await client.search(query);
      final match = const MetadataMatcher().match(
        query,
        rows.map((row) => row.candidate),
      );
      if (!mounted) return;
      setState(() {
        _uncertain = match.status == MetadataMatchStatus.ambiguous;
        final resolved = match.candidate == null
            ? rows.length == 1 && _uncertain
                  ? rows.single
                  : null
            : rows
                  .where(
                    (row) =>
                        row.candidate.id == match.candidate!.id &&
                        row.candidate.provider == match.candidate!.provider,
                  )
                  .firstOrNull;
        _result = resolved ?? _result;
        _message = _result == null
            ? 'No reliable information found for this title.'
            : null;
      });
      final result = _result;
      final sourceId = widget.sourceId;
      final entryId = widget.entryId;
      if (match.status == MetadataMatchStatus.matched &&
          result != null &&
          sourceId != null &&
          entryId != null) {
        try {
          await ref
              .read(metadataOverlayStoreProvider)
              .write(
                sourceId: sourceId,
                entryId: entryId,
                overlay: MetadataOverlay(
                  provider: result.candidate.provider,
                  providerId: result.candidate.id,
                  title: result.candidate.title,
                  overview: result.overview,
                  posterUri: result.posterUri,
                  backdropUri: result.backdropUri,
                  verified: true,
                ),
              );
          if (mounted) {
            ref.invalidate(
              metadataHeroOverlayProvider((
                sourceId: sourceId,
                entryId: entryId,
                title: widget.originalTitle,
                kind: widget.kind,
                enabled: true,
              )),
            );
          }
        } on Object {
          // Metadata remains visible if the optional cache is unavailable.
        }
      }
    } on Object {
      if (mounted && _result == null) {
        setState(() => _message = const MetadataLookupException().toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!metadataEnabled.value) {
      return const Text('Online details are off in Settings.');
    }
    if (ref.watch(metadataGatewayProvider) == null && _result == null) {
      return const Text('The local metadata service is not configured.');
    }
    final result = _result;
    if (_loading && result == null) return const LinearProgressIndicator();
    if (result == null) return Text(_message ?? 'Searching for details…');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_loading) const LinearProgressIndicator(),
        if (_uncertain)
          const Text(
            'Possible match — verify the title before relying on these details.',
          ),
        if (result.backdropUri case final backdrop?)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: SizedBox(
              key: const ValueKey('metadata-backdrop'),
              height: 96,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ArtworkImage(
                  sourceId: 'metadata',
                  entryId:
                      '${result.candidate.provider}:${result.candidate.id}',
                  role: 'backdrop',
                  uri: backdrop,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        if (result.posterUri case final poster?)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: SizedBox(
              width: 72,
              height: 108,
              child: ArtworkImage(
                sourceId: 'metadata',
                entryId: '${result.candidate.provider}:${result.candidate.id}',
                role: 'poster',
                uri: poster,
                fit: BoxFit.contain,
              ),
            ),
          ),
        if (result.overview case final overview?) Text(overview),
        Text('Source: ${result.candidate.provider}'),
      ],
    );
  }
}

final class MetadataDetails extends ConsumerStatefulWidget {
  const MetadataDetails({
    required this.originalTitle,
    required this.kind,
    super.key,
  });
  final String originalTitle;
  final MediaKind kind;
  @override
  ConsumerState<MetadataDetails> createState() => _MetadataDetailsState();
}

final class _MetadataDetailsState extends ConsumerState<MetadataDetails> {
  late final NormalizedPlaylistTitle normalized =
      const PlaylistTitleNormalizer().normalize(
        widget.originalTitle,
        kind: widget.kind,
      );
  List<EnrichedMetadata> _results = const [];
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (metadataEnabled.value) Future.microtask(_lookup);
  }

  Future<void> _lookup() async {
    if (!mounted) {
      return;
    }
    final client = ref.read(metadataGatewayProvider);
    if (client == null || !metadataEnabled.value) {
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await client.search(normalized);
      final match = const MetadataMatcher().match(
        normalized,
        rows.map((r) => r.candidate),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = match.candidate == null
            ? const []
            : rows
                  .where(
                    (row) =>
                        row.candidate.provider == match.candidate!.provider &&
                        row.candidate.id == match.candidate!.id,
                  )
                  .toList();
        _message = switch (match.status) {
          MetadataMatchStatus.matched => null,
          MetadataMatchStatus.ambiguous =>
            'The match is uncertain. Original data retained.',
          MetadataMatchStatus.unmatched =>
            'No confident match found. Original data retained.',
        };
      });
    } on Object {
      if (mounted) {
        setState(() => _message = const MetadataLookupException().toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(normalized.title),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original title: ${widget.originalTitle}'),
            Text(
              [
                normalized.kind.name,
                if (normalized.year != null) '${normalized.year}',
                if (normalized.quality != null) normalized.quality!,
                if (normalized.language != null) normalized.language!,
                if (normalized.season != null) 'Season ${normalized.season}',
                if (normalized.episode != null) 'Episode ${normalized.episode}',
              ].join(' · '),
            ),
            if (!metadataEnabled.value)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Online metadata is off. You can enable it in Settings.',
                ),
              ),
            if (metadataEnabled.value &&
                ref.watch(metadataGatewayProvider) == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'The local metadata service is not configured for this app launch.',
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!),
              ),
            for (final row in _results) ...[
              if (row.posterUri != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 200,
                    child: ArtworkImage(
                      sourceId: 'metadata',
                      entryId: widget.originalTitle,
                      role: 'poster',
                      uri: row.posterUri,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (row.overview != null) Text(row.overview!),
              const SizedBox(height: 12),
              Text('Source: ${row.candidate.provider}'),
              Text(row.candidate.provenance?.attribution ?? ''),
              if (row.candidate.provenance?.sourceUri != null)
                SelectableText(row.candidate.provenance!.sourceUri.toString()),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tvium_core/tvium_core.dart';

import 'metadata_gateway_client.dart';

final metadataEnabled = ValueNotifier<bool>(false);
final metadataGatewayProvider = Provider<MetadataGatewayClient?>((ref) {
  const address = String.fromEnvironment('TVIUM_METADATA_GATEWAY');
  final uri = Uri.tryParse(address);
  if (uri == null || !uri.hasAuthority) return null;
  final client = MetadataGatewayClient(endpoint: uri);
  ref.onDispose(client.close);
  return client;
});

Future<void> showLibrarySettings(
  BuildContext context, {
  required bool configured,
  Future<String> Function()? onImportEpgFile,
  Future<String> Function(Uri uri)? onImportEpgUrl,
  Future<String> Function()? onRefreshSources,
  bool parentalConfigured = false,
  bool parentalUnlocked = false,
  Future<String> Function(String pin)? onSaveParentalPin,
  Future<String> Function(String pin)? onUnlockParental,
}) async {
  final epgUrlController = TextEditingController();
  final parentalPinController = TextEditingController();
  String? epgStatus;
  String? parentalStatus;
  var importingEpg = false;
  var dialogParentalConfigured = parentalConfigured;
  var dialogParentalUnlocked = parentalUnlocked;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Settings'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Titles are organized locally. Original playlist data is preserved.',
                ),
                if (onRefreshSources != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('refresh-sources'),
                    onPressed: importingEpg
                        ? null
                        : () async {
                            setDialogState(() => importingEpg = true);
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
                ValueListenableBuilder<bool>(
                  valueListenable: metadataEnabled,
                  builder: (context, enabled, _) => SwitchListTile(
                    title: const Text('Online metadata'),
                    subtitle: Text(
                      configured
                          ? 'Send cleaned titles, content type, year and language to metadata services when opening details. Applies to this session.'
                          : 'Online metadata is not configured in this build.',
                    ),
                    value: enabled,
                    onChanged: configured
                        ? (value) => metadataEnabled.value = value
                        : null,
                  ),
                ),
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
                                  ? onUnlockParental
                                  : onSaveParentalPin) ==
                              null
                          ? null
                          : () async {
                              final action =
                                  dialogParentalConfigured &&
                                      !dialogParentalUnlocked
                                  ? onUnlockParental
                                  : onSaveParentalPin;
                              final message = await action!(
                                parentalPinController.text,
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
                if (epgStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(epgStatus!),
                  ),
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
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
  epgUrlController.dispose();
  parentalPinController.dispose();
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
                  child: Image.network(
                    row.posterUri.toString(),
                    height: 200,
                    errorBuilder: (context, error, stack) =>
                        const SizedBox.shrink(),
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

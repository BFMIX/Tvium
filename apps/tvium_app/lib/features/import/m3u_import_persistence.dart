import 'dart:convert';
import 'dart:math';

import 'package:tvium_database/tvium_database.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

import '../artwork/artwork_reference_store.dart';
import '../sources/source_identity_service.dart';
import '../xtream/secure_xtream_profile_store.dart';

enum M3uSourceKind { url, file }

final class M3uSourceDescriptor {
  const M3uSourceDescriptor.url({
    required this.displayName,
    required this.location,
  }) : kind = M3uSourceKind.url,
       identityLocation = location;

  const M3uSourceDescriptor.file({
    required this.displayName,
    required this.location,
    String? identityLocation,
  }) : kind = M3uSourceKind.file,
       identityLocation = identityLocation ?? location;

  final M3uSourceKind kind;
  final String displayName;
  final String location;
  final String identityLocation;

  @override
  String toString() => 'M3uSourceDescriptor(${kind.name}, ***)';
}

abstract interface class M3uImportPersistence {
  Future<String> persist(
    M3uSourceDescriptor descriptor,
    List<M3uEntry> entries,
  );
}

abstract interface class M3uPlaybackResolver {
  Future<Uri> resolve(String sourceReference, String entryId);
}

final class SecureM3uSourceStore {
  SecureM3uSourceStore([SecureKeyValueStore? backend])
    : _backend = backend ?? FlutterSecureKeyValueStore();

  static const _prefix = 'tvium.m3u.source.';
  static final _validReference = RegExp(r'^[A-Za-z0-9_-]+$');
  final SecureKeyValueStore _backend;

  Future<void> write(String reference, M3uSourceDescriptor descriptor) =>
      _backend.write(
        _key(reference),
        jsonEncode(<String, String>{
          'kind': descriptor.kind.name,
          'displayName': descriptor.displayName,
          'location': descriptor.location,
          'identityLocation': descriptor.identityLocation,
        }),
      );

  Future<M3uSourceDescriptor?> read(String reference) async {
    final value = await _backend.read(_key(reference));
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final kind = decoded['kind'];
      final displayName = decoded['displayName'];
      final location = decoded['location'];
      final identityLocation = decoded['identityLocation'];
      if (kind is! String ||
          displayName is! String ||
          location is! String ||
          displayName.trim().isEmpty ||
          location.isEmpty) {
        throw const FormatException();
      }
      return switch (kind) {
        'url' => M3uSourceDescriptor.url(
          displayName: displayName,
          location: location,
        ),
        'file' => M3uSourceDescriptor.file(
          displayName: displayName,
          location: location,
          identityLocation: identityLocation is String
              ? identityLocation
              : location,
        ),
        _ => throw const FormatException(),
      };
    } on FormatException {
      throw const M3uSourceException('Saved playlist access is unavailable.');
    }
  }

  Future<void> delete(String reference) => _backend.delete(_key(reference));

  String _key(String reference) {
    if (!_validReference.hasMatch(reference)) {
      throw ArgumentError.value(reference, 'reference');
    }
    return '$_prefix$reference';
  }
}

final class DefaultM3uImportPersistence implements M3uImportPersistence {
  factory DefaultM3uImportPersistence({
    required Future<ProfileSourceRepository> Function() repositoryLoader,
    required SecureM3uSourceStore secureStore,
    required SourceIdentityService identityService,
    String Function()? referenceFactory,
  }) => DefaultM3uImportPersistence._(
    repositoryLoader,
    secureStore,
    identityService,
    referenceFactory ?? _randomReference,
  );

  DefaultM3uImportPersistence._(
    this._repositoryLoader,
    this._secureStore,
    this._identityService,
    this._referenceFactory,
  );

  final Future<ProfileSourceRepository> Function() _repositoryLoader;
  final SecureM3uSourceStore _secureStore;
  final SourceIdentityService _identityService;
  final String Function() _referenceFactory;

  @override
  Future<String> persist(
    M3uSourceDescriptor descriptor,
    List<M3uEntry> entries,
  ) async {
    final repository = await _repositoryLoader();
    final active = await repository.ensureDefaultProfile();
    final digest = await _identityService.m3uDigest(
      descriptor.kind.name,
      descriptor.identityLocation,
    );
    final existing = await repository.sourceByIdentity(digest);
    final reference = existing?.secretReference ?? _referenceFactory();
    await _secureStore.write(reference, descriptor);
    try {
      final sourceId = existing?.id ?? reference;
      final projected = _project(sourceId, reference, entries);
      if (existing != null && repository is PlaylistRepository) {
        await (repository as PlaylistRepository).replaceEntries(
          sourceId,
          projected,
        );
        await repository.linkSource(active.id, sourceId);
      } else {
        await repository.registerSource(
          IptvSource(
            id: sourceId,
            displayName: descriptor.displayName,
            identityDigest: digest,
            secretReference: reference,
          ),
          active.id,
          projected,
        );
      }
      try {
        await ArtworkReferenceStore().write(sourceId, {
          for (final entry in entries)
            if (entry.logoUri case final Uri uri) entry.id: uri,
        });
      } on Object {
        // Artwork storage must not discard a successfully imported catalog.
      }
      return sourceId;
    } on Object {
      if (existing == null) await _secureStore.delete(reference);
      rethrow;
    }
  }

  List<PersistedMediaEntry> _project(
    String sourceId,
    String reference,
    List<M3uEntry> entries,
  ) => <PersistedMediaEntry>[
    for (final entry in entries)
      PersistedMediaEntry(
        id: entry.id,
        playlistId: sourceId,
        sourceReference: reference,
        originalName: entry.originalName,
        displayName: entry.originalName,
        groupName: entry.groupTitle,
        kind: entry.kind,
        epgChannelId: entry.attributes['tvg-id'],
      ),
  ];

  static String _randomReference() => List<String>.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

final class DefaultM3uPlaybackResolver implements M3uPlaybackResolver {
  factory DefaultM3uPlaybackResolver({
    required SecureM3uSourceStore secureStore,
    M3uSource Function(M3uSourceDescriptor descriptor)? sourceFactory,
    M3uParser parser = const M3uParser(),
  }) => DefaultM3uPlaybackResolver._(
    secureStore,
    sourceFactory ?? _defaultSource,
    parser,
  );

  DefaultM3uPlaybackResolver._(
    this._secureStore,
    this._sourceFactory,
    this._parser,
  );

  final SecureM3uSourceStore _secureStore;
  final M3uSource Function(M3uSourceDescriptor descriptor) _sourceFactory;
  final M3uParser _parser;

  @override
  Future<Uri> resolve(String sourceReference, String entryId) async {
    final descriptor = await _secureStore.read(sourceReference);
    if (descriptor == null) {
      throw const M3uSourceException(
        'Reconnect this playlist to restore playback.',
      );
    }
    await for (final event in _parser.parse(
      _sourceFactory(descriptor).readLines(),
    )) {
      if (event case M3uBatch(:final entries)) {
        for (final entry in entries) {
          if (entry.id == entryId) return entry.originalUri;
        }
      }
    }
    throw const M3uSourceException(
      'This item is no longer available in the playlist.',
    );
  }

  static M3uSource _defaultSource(M3uSourceDescriptor descriptor) =>
      switch (descriptor.kind) {
        M3uSourceKind.url => M3uUrlSource(Uri.parse(descriptor.location)),
        M3uSourceKind.file => M3uFileSource(descriptor.location),
      };
}

final class M3uSourceRefreshService {
  factory M3uSourceRefreshService({
    required SecureM3uSourceStore secureStore,
    required M3uImportPersistence persistence,
    M3uSource Function(M3uSourceDescriptor descriptor)? sourceFactory,
    M3uParser parser = const M3uParser(),
  }) => M3uSourceRefreshService._(
    secureStore,
    persistence,
    sourceFactory ?? _defaultSource,
    parser,
  );

  M3uSourceRefreshService._(
    this._secureStore,
    this._persistence,
    this._sourceFactory,
    this._parser,
  );

  final SecureM3uSourceStore _secureStore;
  final M3uImportPersistence _persistence;
  final M3uSource Function(M3uSourceDescriptor descriptor) _sourceFactory;
  final M3uParser _parser;

  Future<int?> refresh(String sourceReference) async {
    final descriptor = await _secureStore.read(sourceReference);
    if (descriptor == null) return null;
    final entries = <M3uEntry>[];
    await for (final event in _parser.parse(
      _sourceFactory(descriptor).readLines(),
    )) {
      if (event case M3uBatch(entries: final batch)) {
        entries.addAll(batch);
      }
    }
    await _persistence.persist(descriptor, entries);
    return entries.length;
  }

  static M3uSource _defaultSource(M3uSourceDescriptor descriptor) =>
      switch (descriptor.kind) {
        M3uSourceKind.url => M3uUrlSource(Uri.parse(descriptor.location)),
        M3uSourceKind.file => M3uFileSource(descriptor.location),
      };
}

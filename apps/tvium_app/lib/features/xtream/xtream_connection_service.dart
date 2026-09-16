import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tvium_xtream/tvium_xtream.dart';

import 'secure_xtream_profile_store.dart';

final xtreamConnectionServiceProvider = Provider<XtreamConnectionService>((
  ref,
) {
  final service = DefaultXtreamConnectionService();
  ref.onDispose(service.close);
  return service;
});

final class XtreamConnectionInput {
  const XtreamConnectionInput({
    required this.profileName,
    required this.serverUri,
    required this.credentials,
  });

  final String profileName;
  final Uri serverUri;
  final XtreamCredentials credentials;

  @override
  String toString() => 'XtreamConnectionInput(***)';
}

final class XtreamAddedProfile {
  const XtreamAddedProfile({
    required this.profileId,
    required this.account,
    required this.catalog,
  });

  final String profileId;
  final XtreamAccountInfo account;
  final XtreamCatalog catalog;

  int get itemCount =>
      catalog.liveStreams.length +
      catalog.movies.length +
      catalog.series.length;

  @override
  String toString() => 'XtreamAddedProfile(profileId: $profileId)';
}

abstract interface class XtreamConnectionService {
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input);

  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input);
}

final class DefaultXtreamConnectionService implements XtreamConnectionService {
  DefaultXtreamConnectionService({
    http.Client? httpClient,
    SecureXtreamProfileStore? secretStore,
    Random? random,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _secretStore = secretStore ?? SecureXtreamProfileStore(),
       _random = random ?? Random.secure();

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final SecureXtreamProfileStore _secretStore;
  final Random _random;

  @override
  Future<XtreamAccountInfo> testConnection(XtreamConnectionInput input) {
    return XtreamClient(_httpClient)
        .authenticate(_profile(input, 'connection-test'), input.credentials);
  }

  @override
  Future<XtreamAddedProfile> addPlaylist(XtreamConnectionInput input) async {
    final reference = _secureReference();
    final profile = _profile(input, reference);
    final client = XtreamClient(_httpClient);
    final account = await client.authenticate(profile, input.credentials);
    final catalog = await client.loadCatalog(profile, input.credentials);
    await _secretStore.write(
      reference,
      XtreamConnectionSecret(
        serverUri: input.serverUri,
        credentials: input.credentials,
      ),
    );
    return XtreamAddedProfile(
      profileId: reference,
      account: account,
      catalog: catalog,
    );
  }

  XtreamProfile _profile(XtreamConnectionInput input, String reference) {
    return XtreamProfile(
      id: reference,
      displayName: input.profileName,
      serverUri: input.serverUri,
      credentialReference: reference,
    );
  }

  String _secureReference() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  void close() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  @override
  String toString() => 'DefaultXtreamConnectionService(***)';
}

import 'persisted_media_entry.dart';

final class UserProfile {
  const UserProfile(this.id, this.displayName);
  final String id;
  final String displayName;
}

final class IptvSource {
  const IptvSource({
    required this.id,
    required this.displayName,
    required this.identityDigest,
    required this.secretReference,
  });
  final String id;
  final String displayName;
  final String identityDigest;
  final String secretReference;
}

abstract interface class ProfileSourceRepository {
  Future<UserProfile> ensureDefaultProfile();
  Future<List<UserProfile>> profiles();
  Future<UserProfile> activeProfile();
  Future<UserProfile> createProfile(String name);
  Future<void> renameProfile(String id, String name);
  Future<List<IptvSource>> deleteProfile(String id);
  Future<void> setActiveProfile(String id);
  Future<IptvSource?> sourceByIdentity(String digest);
  Future<List<IptvSource>> sourcesForProfile(String profileId);
  Future<List<PersistedMediaEntry>> entriesForPlaylist(String sourceId);
  Future<void> registerSource(
    IptvSource source,
    String profileId,
    List<PersistedMediaEntry> entries,
  );
  Future<void> linkSource(String profileId, String sourceId);
  Future<void> renameSource(String sourceId, String name);
  Future<IptvSource?> unlinkSource(String profileId, String sourceId);
  Future<void> close();
}

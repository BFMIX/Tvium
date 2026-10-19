final class XtreamProfile {
  XtreamProfile({
    required this.id,
    required this.displayName,
    required this.serverUri,
    required this.credentialReference,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'A profile ID is required.');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'A profile name is required.',
      );
    }
    if (!serverUri.hasAuthority ||
        (serverUri.scheme != 'http' && serverUri.scheme != 'https')) {
      throw ArgumentError.value(
        '<redacted>',
        'serverUri',
        'The server must use HTTP or HTTPS.',
      );
    }
    if (credentialReference.trim().isEmpty) {
      throw ArgumentError.value(
        '<redacted>',
        'credentialReference',
        'A credential reference is required.',
      );
    }
  }

  final String id;
  final String displayName;
  final Uri serverUri;
  final String credentialReference;

  @override
  String toString() => 'XtreamProfile(id: $id)';
}

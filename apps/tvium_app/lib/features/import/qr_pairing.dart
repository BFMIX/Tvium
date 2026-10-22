sealed class QrPairingSubmission {
  const QrPairingSubmission();
}

final class QrM3uSubmission extends QrPairingSubmission {
  const QrM3uSubmission(this.url);

  final Uri url;
}

final class QrXtreamSubmission extends QrPairingSubmission {
  const QrXtreamSubmission(this.server, this.username, this.password);

  final Uri server;
  final String username;
  final String password;
}

QrPairingSubmission? parseQrPairingSubmission(String body) {
  if (body.length > 4096) return null;
  final Map<String, String> fields;
  try {
    fields = Uri.splitQueryString(body);
  } on FormatException {
    return null;
  }
  switch (fields['type']) {
    case 'm3u':
      final url = _safeHttpUrl(fields['url']);
      return url == null ? null : QrM3uSubmission(url);
    case 'xtream':
      final server = _safeHttpUrl(fields['server']);
      final username = fields['username']?.trim() ?? '';
      final password = fields['password'] ?? '';
      if (server == null ||
          username.isEmpty ||
          password.isEmpty ||
          username.length > 256 ||
          password.length > 256) {
        return null;
      }
      return QrXtreamSubmission(server, username, password);
    default:
      return null;
  }
}

Uri? _safeHttpUrl(String? value) {
  if (value == null || value.length > 2048) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      !<String>{'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

abstract interface class QrPairingSession {
  String get pairingUrl;
  Future<QrPairingSubmission?> get submission;
  Future<void> close();
}

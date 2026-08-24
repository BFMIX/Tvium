/// Removes credentials and source details from diagnostic text.
abstract final class SensitiveDataSanitizer {
  static final RegExp _urlPattern = RegExp(r'''https?://[^\s<>"']+''');
  static final RegExp _credentialPattern = RegExp(
    r'\b(username|user|password|pass|token|access_token|auth|key)'
    r'\s*([=:])\s*([^\s&]+)',
    caseSensitive: false,
  );

  /// Returns diagnostic text with URL paths, user info, and secret values
  /// redacted while retaining enough host and key information for support.
  static String sanitize(String input) {
    final urlsRedacted = input.replaceAllMapped(_urlPattern, (match) {
      final value = match.group(0);
      final uri = value == null ? null : Uri.tryParse(value);
      if (uri == null || uri.host.isEmpty) {
        return '[redacted-url]';
      }

      final port = uri.hasPort ? ':${uri.port}' : '';
      final query = uri.queryParametersAll.keys
          .map((key) => '${Uri.encodeQueryComponent(key)}=***')
          .join('&');
      final suffix = query.isEmpty ? '' : '?$query';
      return '${uri.scheme}://${uri.host}$port/***$suffix';
    });

    return urlsRedacted.replaceAllMapped(_credentialPattern, (match) {
      final key = match.group(1) ?? 'credential';
      final separator = match.group(2) ?? '=';
      final spacing = separator == ':' ? ' ' : '';
      return '$key$separator$spacing***';
    });
  }
}

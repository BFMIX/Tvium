import 'package:tvium_xtream/tvium_xtream.dart';

/// Extracts a possible Xtream account from a conventional M3U export URL.
/// The caller must authenticate before replacing the M3U import path.
final class XtreamM3uCandidate {
  const XtreamM3uCandidate(this.serverUri, this.credentials);

  final Uri serverUri;
  final XtreamCredentials credentials;

  @override
  String toString() => 'XtreamM3uCandidate(***)';
}

XtreamM3uCandidate? detectXtreamM3u(Uri uri) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.path.endsWith('/get.php')) {
    return null;
  }
  final parameters = uri.queryParametersAll;
  final usernames = parameters['username'];
  final passwords = parameters['password'];
  if (usernames == null ||
      passwords == null ||
      usernames.length != 1 ||
      passwords.length != 1 ||
      usernames.single.isEmpty ||
      passwords.single.isEmpty) {
    return null;
  }
  final output = parameters['output'];
  if (output != null &&
      (output.length != 1 || !{'ts', 'm3u8'}.contains(output.single))) {
    return null;
  }
  final type = parameters['type'];
  if (type != null && (type.length != 1 || type.single != 'm3u_plus')) {
    return null;
  }
  final parentPath = uri.path.substring(0, uri.path.length - 'get.php'.length);
  return XtreamM3uCandidate(
    Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: parentPath,
    ),
    XtreamCredentials(username: usernames.single, password: passwords.single),
  );
}

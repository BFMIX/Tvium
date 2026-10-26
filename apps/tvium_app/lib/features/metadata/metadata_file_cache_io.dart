import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../xtream/secure_xtream_profile_store.dart';

/// Stores only verified, public TMDB responses. Source secrets must never use
/// this backend; the narrow key prefix makes accidental use fail closed.
final class FileMetadataKeyValueStore implements SecureKeyValueStore {
  FileMetadataKeyValueStore({Directory? directory}) {
    _directory = directory;
  }

  Directory? _directory;
  static final _validKey = RegExp(r'^tvium\.metadata\.v1\.[a-f0-9]{64}$');

  Future<File> _fileFor(String key) async {
    if (!_validKey.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Not a metadata cache key.');
    }
    final directory = _directory ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/metadata',
    );
    await directory.create(recursive: true);
    return File('${directory.path}/${key.substring(18)}.json');
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _fileFor(key);
    await file.writeAsString(value, flush: true);
  }

  @override
  Future<String?> read(String key) async {
    final file = await _fileFor(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> delete(String key) async {
    final file = await _fileFor(key);
    if (await file.exists()) await file.delete();
  }
}

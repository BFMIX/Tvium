import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tvium_m3u/tvium_m3u.dart';

typedef LocalPlaylistPicker = Future<M3uSource?> Function();

final localPlaylistPickerProvider = Provider<LocalPlaylistPicker>(
  (ref) => pickLocalPlaylist,
);

Future<M3uSource?> pickLocalPlaylist() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const <String>['m3u', 'm3u8'],
  );
  if (file == null) {
    return null;
  }
  final path = file.path;
  if (!kIsWeb && path != null) {
    return retainLocalPlaylistFile(path);
  }
  return M3uBytesSource(await file.readAsBytes());
}

Future<M3uFileSource> retainLocalPlaylistFile(
  String selectedPath, {
  Directory? supportDirectory,
}) async {
  final selected = File(selectedPath);
  final digest = await sha256.bind(selected.openRead()).first;
  final root = supportDirectory ?? await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/playlists');
  await directory.create(recursive: true);
  final destination = File('${directory.path}/$digest.m3u');
  if (!await destination.exists()) {
    final temporary = File(
      '${destination.path}.part-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await selected.openRead().pipe(temporary.openWrite());
      if (await destination.exists()) {
        await temporary.delete();
      } else {
        await temporary.rename(destination.path);
      }
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
  return M3uFileSource(
    destination.path,
    displayName: _fileName(selectedPath),
    originalPath: selectedPath,
  );
}

String _fileName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  return parts.isEmpty || parts.last.isEmpty ? 'Local playlist' : parts.last;
}

Future<void> deleteRetainedLocalPlaylist(
  String path, {
  Directory? supportDirectory,
}) async {
  if (kIsWeb) return;
  final root = supportDirectory ?? await getApplicationSupportDirectory();
  final managedDirectory = Directory('${root.path}/playlists').absolute.path;
  final candidate = File(path).absolute.path;
  final prefix = '$managedDirectory${Platform.pathSeparator}';
  if (!candidate.startsWith(prefix)) return;
  final file = File(candidate);
  if (await file.exists()) await file.delete();
}

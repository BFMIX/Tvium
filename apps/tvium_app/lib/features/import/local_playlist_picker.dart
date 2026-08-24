import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return M3uFileSource(path);
  }
  return M3uBytesSource(await file.readAsBytes());
}

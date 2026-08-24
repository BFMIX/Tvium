import 'package:flutter_riverpod/legacy.dart';

import 'playlist_import_controller.dart';

final playlistImportControllerProvider =
    ChangeNotifierProvider<PlaylistImportController>(
      (ref) => PlaylistImportController(),
    );

import 'package:path_provider/path_provider.dart';
import 'package:tvium_database/tvium_database.dart';

Future<ProfileSourceRepository> openLibraryRepository() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return SqlitePlaylistRepository.open(
    '${directory.path}/tvium-library.sqlite',
  );
}

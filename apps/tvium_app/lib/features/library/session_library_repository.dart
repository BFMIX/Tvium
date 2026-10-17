import 'package:tvium_database/tvium_database.dart';

Future<ProfileSourceRepository> openLibraryRepository() async =>
    InMemoryProfileSourceRepository();

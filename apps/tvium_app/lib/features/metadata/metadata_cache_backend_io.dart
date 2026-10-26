import 'dart:io';

import '../xtream/secure_xtream_profile_store.dart';
import 'metadata_file_cache_io.dart';

SecureKeyValueStore createMetadataCacheBackend() => Platform.isMacOS
    ? FileMetadataKeyValueStore()
    : FlutterSecureKeyValueStore();

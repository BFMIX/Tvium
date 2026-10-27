import 'dart:convert';
import 'dart:typed_data';

Future<Object?> decodeXtreamJson(Uint8List bytes) async =>
    jsonDecode(utf8.decode(bytes));

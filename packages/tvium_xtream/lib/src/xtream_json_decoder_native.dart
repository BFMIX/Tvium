import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

Future<Object?> decodeXtreamJson(Uint8List bytes) async {
  if (bytes.lengthInBytes < 256 * 1024) {
    return jsonDecode(utf8.decode(bytes));
  }
  return Isolate.run(() => jsonDecode(utf8.decode(bytes)));
}

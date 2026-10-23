import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web favicon has a versioned branded URL', () {
    final document = File('web/index.html').readAsStringSync();
    final favicon = File('web/favicon.png');

    expect(document, contains('href="favicon.png?v=2"'));
    expect(favicon.existsSync(), isTrue);
    expect(favicon.lengthSync(), greaterThan(100));
  });
}

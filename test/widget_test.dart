import 'package:flutter_test/flutter_test.dart';

import 'package:clinik/main.dart';

void main() {
  test('ClinikApp se puede instanciar', () {
    const app = ClinikApp();
    expect(app, isNotNull);
  });
}

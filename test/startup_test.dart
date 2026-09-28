import 'package:flutter_test/flutter_test.dart';
import 'package:prosvet/main.dart';
import 'package:prosvet/src/core/settings.dart';

void main() {
  test('startup connection follows only the user setting', () {
    final settings = Settings.defaults();
    expect(shouldConnectAtStartup(settings), isFalse);

    settings.connectOnLaunch = true;
    expect(shouldConnectAtStartup(settings), isTrue);
  });
}

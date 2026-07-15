import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_dashboard/services/app_icon_service.dart';

void main() {
  test('detects Windows shell launch targets', () {
    expect(
      isUwpOrProtocol('Microsoft.WindowsCalculator_8wekyb3d8bbwe!App'),
      isTrue,
    );
    expect(
      isUwpOrProtocol('ChromeBeta._crx_gdfaincndodkhapmbffkckdkhn'),
      isTrue,
    );
    expect(isUwpOrProtocol('ms-settings:'), isTrue);
    expect(isUwpOrProtocol('https://nodejs.org/'), isTrue);
    expect(isUwpOrProtocol(r'C:\Windows\notepad.exe'), isFalse);
  });

  test('distinguishes AppX app ids from protocol launch targets', () {
    expect(
      isAppxAppUserModelId('Microsoft.WindowsCalculator_8wekyb3d8bbwe!App'),
      isTrue,
    );
    expect(isAppxAppUserModelId('ms-settings:'), isFalse);
    expect(isAppxAppUserModelId(r'C:\Windows\notepad.exe'), isFalse);
  });

  test('resolves username placeholder in Windows paths', () {
    final resolved = resolveWindowsPath(r'C:\Users\%USERNAME%\AppData');

    expect(resolved, isNot(contains('%USERNAME%')));
  });
}

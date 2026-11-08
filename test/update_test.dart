import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_dash/update.dart';

void main() {
  test('a release is newer only by its numbers', () {
    expect(isNewer('v1.0.1', '1.0.0-ddf24a1-1108-0028'), isTrue);
    expect(isNewer('v1.1.0', '1.0.9'), isTrue);
    expect(isNewer('v2.0.0', '1.9.9+-1108-0030'), isTrue);
    expect(isNewer('v1.0.0', '1.0.0-ddf24a1+-1108-0028'), isFalse); // the same
    expect(isNewer('v1.0.0', '1.0.1'), isFalse); // older
    expect(isNewer('build-12', '1.0.0'), isFalse); // not a version
    expect(isNewer('v1.0.1', ''), isFalse); // build unknown (iOS, tests)
  });

  test('the update carries both APKs, or is none', () {
    String release(String tag, List<String> names) => jsonEncode({
          'tag_name': tag,
          'assets': [for (final n in names) {'name': n, 'browser_download_url': 'https://x/$n'}],
        });
    const both = ['Wattline-Android.apk', 'Wattline-Android-older-phones.apk'];
    final u = pickUpdate(release('v1.0.1', both), '1.0.0-abc-1108-0000')!;
    expect(u.version, '1.0.1');
    expect(u.arm64, 'https://x/Wattline-Android.apk');
    expect(pickUpdate(release('v1.0.0', both), '1.0.0-abc-1108-0000'), isNull);
    expect(pickUpdate(release('v1.0.1', both.take(1).toList()), '1.0.0'), isNull);
  });

  // GitHub saying something odd (not an object, an asset still uploading
  // with no URL) is no update, not an error out of the check.
  test('an odd release reply is no update', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    var reply = '[1]';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('tesla_dash/net'), (call) async => call.method == 'latestRelease' ? reply : null);
    expect(await checkUpdate('1.0.0'), isNull);
    reply = jsonEncode({
      'tag_name': 'v1.0.1',
      'assets': [
        {'name': 'Wattline-Android.apk', 'browser_download_url': null},
      ],
    });
    expect(await checkUpdate('1.0.0'), isNull);
  });

  // The install call failing on the platform side is a reason to show, not an
  // error left uncaught (which would leave the update busy for good).
  test('a platform error installing is a reason', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('tesla_dash/net'), (call) async => throw PlatformException(code: 'gone', message: 'no activity'));
    expect(await installUpdate((version: '1.0.1', arm64: 'a', any: 'b')), 'no activity');
  });
}

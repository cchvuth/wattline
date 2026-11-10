import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_dash/changelog.dart';
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

  // GitHub busy or the network gone: the dash offers to try again; an APK
  // that is not there, no.
  test('which failed updates are worth retrying', () {
    for (final why in ['HTTP 504', 'HTTP 503', 'HTTP 500', 'HTTP 429', 'timeout', 'Read timed out']) {
      expect(worthRetrying(why), isTrue, reason: why);
    }
    for (final why in ['HTTP 404', 'HTTP 403', 'no apk']) {
      expect(worthRetrying(why), isFalse, reason: why);
    }
  });

  // What's new after an update: the releases since the one last run; to one
  // who never saw the changelog, all of them.
  test('the changes since the version last run', () {
    expect(versionOf('1.0.9-95b10f3-1110-0016'), '1.0.9');
    expect(versionOf(''), isNull);
    List<String> since(String? last, String now) => [for (final c in changesSince(last, now)) c.version];
    expect(since('1.0.6', '1.0.9'), ['1.0.9', '1.0.8', '1.0.7']);
    expect(since(null, '1.0.9'), ['1.0.9', '1.0.8', '1.0.7', '1.0.6', '1.0.5', '1.0.4', '1.0.3']);
    expect(since('1.0.9', '1.0.9'), isEmpty);
  });

  // Each release has its entry (the pubspec's version among them), newest
  // first, and every screenshot it names is bundled.
  test('the changelog covers the release being built', () {
    final v = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())![1];
    expect(kChangelog.map((c) => c.version), contains(v));
    for (var i = 1; i < kChangelog.length; i++) {
      expect(isNewer(kChangelog[i - 1].version, kChangelog[i].version), isTrue, reason: kChangelog[i].version);
    }
    for (final c in kChangelog) {
      for (final s in c.shots) {
        expect(File('assets/whatsnew/$s').existsSync(), isTrue, reason: s);
      }
    }
  });
}

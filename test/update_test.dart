import 'dart:convert';

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
    // A release from before the rename: its APKs' old names still do.
    final old = pickUpdate(release('v1.0.1', ['Tesla-Dash-Android.apk', 'Tesla-Dash-Android-older-phones.apk']), '1.0.0')!;
    expect(old.arm64, 'https://x/Tesla-Dash-Android.apk');
    expect(pickUpdate(release('v1.0.1', both.take(1).toList()), '1.0.0'), isNull);
  });
}

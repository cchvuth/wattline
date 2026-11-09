// The in-app update (Android): the newest full release on GitHub, offered
// when it is newer than this build, downloaded and handed to Android's
// installer (MainActivity's "latestRelease" and "installUpdate").
import 'dart:convert';

import 'package:flutter/services.dart';

const _net = MethodChannel('tesla_dash/net');

/// A release newer than the running build.
typedef Update = ({String version, String arm64, String any});

/// The version's numbers, from "v1.2.3" or "1.2.3-abc1234-1108-0030".
List<int> versionParts(String v) =>
    RegExp(r'\d+').allMatches(v.split(RegExp(r'[-+]')).first).map((m) => int.parse(m[0]!)).toList();

/// Whether [tag] is a later version than [running], number by number.
bool isNewer(String tag, String running) {
  final a = versionParts(tag), b = versionParts(running);
  if (a.isEmpty || b.isEmpty) return false;
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// The update GitHub's latest release offers over [running], or null: none
/// newer, no APKs on it, or no network.
Update? pickUpdate(String json, String running) {
  final r = jsonDecode(json) as Map<String, dynamic>;
  final tag = r['tag_name'] as String? ?? '';
  if (!isNewer(tag, running)) return null;
  String? url(String name) => [
        for (final a in (r['assets'] as List? ?? const []))
          if (a['name'] == name) a['browser_download_url'] as String,
      ].firstOrNull;
  final arm64 = url('Wattline-Android.apk'), any = url('Wattline-Android-older-phones.apk');
  if (arm64 == null || any == null) return null;
  return (version: tag.replaceFirst('v', ''), arm64: arm64, any: any);
}

Future<Update?> checkUpdate(String running) async {
  try {
    final json = await _net.invokeMethod<String>('latestRelease');
    return json == null ? null : pickUpdate(json, running);
  } catch (_) {
    return null; // no native side (tests, iOS), or GitHub said something odd (a bad cast throws an Error)
  }
}

/// Whether Android lets this app install updates (allowed once, in Settings).
Future<bool> canInstallUpdates() async {
  try {
    return await _net.invokeMethod<bool>('canInstall') ?? false;
  } on PlatformException {
    return false;
  }
}

/// Opens Android's "install unknown apps" switch for this app.
Future<void> allowInstallUpdates() async {
  try {
    await _net.invokeMethod('allowInstalls');
  } on PlatformException {
    // No such screen on this phone: the snackbar has said where to look.
  }
}

/// Whether an update that failed for [why] may work another time: GitHub
/// busy (a 5xx such as its 504s, or 429) or the network dropping out, not an
/// APK that is gone.
bool worthRetrying(String why) => why == 'HTTP 429' || !(why.startsWith('HTTP 4') || why == 'no apk');

/// Downloads and starts the install: null once Android's installer has it,
/// or why not.
Future<String?> installUpdate(Update u) async {
  try {
    final r = await _net.invokeMethod<String>('installUpdate', {'arm64': u.arm64, 'any': u.any});
    return r == 'started' ? null : r;
  } catch (e) {
    // Any error, or the dash would wait on an install that never started.
    return e is PlatformException ? e.message ?? e.code : '$e';
  }
}

// Renders a 15 s drive frame by frame, for a video of the dash. Set
// DRIVE_VIDEO=/some/dir to write the frames (frame_000.png...); otherwise it
// is skipped. Turn them into a video with tools/frames_to_mp4.swift.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_dash/commander.dart';
import 'package:tesla_dash/main.dart';
import 'package:tesla_dash/panda.dart';

const _fps = 20, _secs = 15.0, _dpr = 2.0;

/// Eases from a to b as t goes from t0 to t1 (smoothstep), a before, b after.
double _ease(double t, double t0, double t1, double a, double b) {
  final x = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
  return a + (b - a) * x * x * (3 - 2 * x);
}

/// A foot is never still: small wander and quick corrections, the same
/// every run (sums of sines, no random).
double _wobble(double t, double amp) =>
    amp * (0.6 * sin(t * 2.1) + 0.3 * sin(t * 5.3 + 1.2) + 0.15 * sin(t * 11.7 + 0.4));

/// [a] to [b] in a straight line as t goes from t0 to t1, held either side.
double _lin(double t, double t0, double t1, double a, double b) =>
    a + (b - a) * ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);

/// The drive at time [t] s: from rest, pedal and power rising in a straight
/// line to 60 km/h; a right turn on regen, slowing; the brake at the end.
/// The scene is laid out over 10 s and played over [_secs]; the indicator
/// flashes at the car's own rate whatever the stretch.
void _drive(Panda o, double real) {
  final t = real * 10 / _secs;
  final pulling = t >= 0.5 && t < 4.8, turning = t >= 4.8 && t < 8.5, braking = t >= 8.5;
  final pedal = pulling ? _lin(t, 0.5, 4.5, 0, 55) + _wobble(t, 1.2) : 0.0;
  // Power follows the pedal a beat behind, then regen: more while quicker,
  // and fading out as the car slows under the brake.
  final regen = t < 4.8 ? 0.0 : _ease(t, 4.8, 5.4, 0, 36) * _lin(t, 8.5, 10, 1, 0.25);
  final power = pulling ? _lin(t, 0.6, 4.6, 0, 125) + _wobble(t * 1.7, 2.5) : -regen + _wobble(t * 1.7, 0.8);
  final speed = t < 0.5
      ? 0.0
      : t < 4.8
          ? _ease(t, 0.5, 4.8, 0, 60)
          : t < 8.5
              ? _lin(t, 4.8, 8.5, 60, 38)
              : _ease(t, 8.5, 10, 38, 6);
  final brake = braking ? (_ease(t, 8.5, 8.9, 0, 32) + _wobble(t, 1.5)).clamp(0.0, 80.0) : 0.0;
  // The right turn: indicator from 4.8 s, the wheel turned 5.5-8 s.
  final steer = turning ? -_ease(t, 5.4, 6.3, 0, 190) * _ease(t, 7.4, 8.4, 1, 0) + _wobble(t, 4) : _wobble(t, 2);
  final signalling = t >= 4.8 && t < 7.6;
  final g = pulling
      ? _lin(t, 0.5, 1.2, 0, 0.36) * _lin(t, 4.0, 4.8, 1, 0.2)
      : braking
          ? -0.22 - brake / 110
          : t < 0.5
              ? 0.0 // waiting to go
              : -0.16;
  final lat = turning ? _ease(t, 5.4, 6.3, 0, 0.24) * _ease(t, 7.4, 8.4, 1, 0) : 0.0;
  final rear = power >= 0 ? 0.6 + pedal / 100 * 0.2 : 0.72;
  o
    ..speed = speed.roundToDouble()
    ..gear = 'D'
    ..pedalPct = pedal.clamp(0, 100)
    ..rearKw = power * rear
    ..frontKw = power * (1 - rear)
    ..braking = regen > 18 || brake > 2
    ..brakePct = brake < 2 ? 0 : brake / Panda.brakeFullBar * 100
    ..steerDeg = steer
    ..indR = signalling
    ..blinkLit = signalling && ((real - 4.8 * _secs / 10) * 1000 ~/ 361).isEven // the car's 361 ms half cycle
    ..gLong = g + _wobble(t * 2, 0.01)
    ..gLat = -lat // a right turn: the dot goes left (it goes right in a left one)
    ..gMaxAccel = max(o.gMaxAccel, g)
    ..gMaxBrake = max(o.gMaxBrake, -g)
    ..gMaxLat = max(o.gMaxLat, lat);
}

void main() {
  final out = Platform.environment['DRIVE_VIDEO'];
  testWidgets('a drive, frame by frame', (t) async {
    t.view
      ..physicalSize = const Size(823.5, 384) * _dpr
      ..devicePixelRatio = _dpr;
    addTearDown(t.view.reset);
    final o = Panda()
      ..status = 'live'
      ..kph = true
      ..drl = true
      ..lowBeam = true
      ..highBeam = false
      ..tpFL = 2.9
      ..tpFR = 2.9
      ..tpRL = 2.9
      ..tpRR = 2.9
      ..socPct = 71
      ..rangeMi = 214
      ..speedLimit = 50
      ..autopilot = 'AP READY'
      ..outsideC = 9
      ..packTempC = 26
      ..regenMaxKw = 80
      ..cellVMax = 3.902
      ..cellVMin = 3.898
      ..packKwh = 81.76
      ..packNewKwh = 84
      ..cabinC1 = 21
      ..cabinC2 = 21
      ..cabinC3 = 20
      ..fan1 = 'AUTO'
      ..fan2 = 'LOW'
      ..buckled.addAll({'D', 'P', '2L', '2R'})
      ..navRoute = true
      ..navMinutes = 18
      ..navEnergyKwh = 52;
    for (final id in [0x238, 0x2B6, 0x3A1]) {
      o.frames[id] = Frame(0);
    }
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
        theme: kTheme,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
            key: key, child: DashPage(demo: o, bt: Commander()..show(BtLink.lean, 'ready')))));
    await t.pump(const Duration(milliseconds: 500));
    await t.runAsync(() => Future.wait([
          for (final e in find.byType(Image).evaluate()) precacheImage((e.widget as Image).image, e),
        ]));
    final frames = (_secs * _fps).round();
    for (var i = 0; i < frames; i++) {
      _drive(o, i / _fps);
      o
        ..notifyListeners()
        ..fastTick();
      await t.pump(const Duration(milliseconds: 1000 ~/ _fps));
      await t.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: _dpr);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/frame_${i.toString().padLeft(3, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await t.pumpWidget(const SizedBox());
  }, skip: out == null, timeout: const Timeout(Duration(minutes: 5)));
}

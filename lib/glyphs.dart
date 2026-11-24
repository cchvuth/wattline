import 'dart:math';

import 'package:flutter/material.dart';

/// The dash's icons, on Material's 24-unit grid with one stroke and round
/// ends. Frunk, trunk, recirculation, charge port and the doors are the
/// car's own icons: traced from photos of its screen and of its manual door
/// release, then cleaned up as vectors. The headlamps are the standard
/// symbols the car's indicators use. Autopilot is the car's own steering
/// wheel, traced from its screen into docs/icons/autopilot.svg (on its disc)
/// and drawn here from the same path; cruise is a gauge. Code, not files:
/// nothing to load.
enum Glyph {
  frunk,
  trunk,
  mirrorTilt,
  recirc,
  interiorLight,
  chargePort,
  doorFL,
  doorFR,
  doorRL,
  doorRR,
  lowBeam,
  highBeam,
  drl,
  grip,
  fan,
  fanOff,
  autopilot,
  cruise,
  washer,
  massage,
}

class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size = 24, this.color});

  final Glyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(glyph, color ?? IconTheme.of(context).color ?? Colors.white),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The traced icons; the right-hand doors, the frunk and the trunk face
    // the other way.
    if (_traced[glyph] case (final strokes, final fills)) {
      if (const {Glyph.doorFR, Glyph.doorRR, Glyph.frunk, Glyph.trunk}.contains(glyph)) {
        canvas
          ..translate(24, 0)
          ..scale(-1, 1);
      }
      for (final p in strokes) {
        canvas.drawPath(p, line);
      }
      for (final p in fills) {
        canvas.drawPath(p, Paint()..color = color);
      }
      return;
    }
    switch (glyph) {
      case Glyph.mirrorTilt:
        // The door mirror on its arm, and the way it dips.
        canvas.drawRRect(
            RRect.fromLTRBR(2.8, 4, 14.6, 11.4, const Radius.circular(3.4)), line);
        canvas.drawPath(
            Path()
              ..moveTo(14.6, 7.7)
              ..lineTo(19.6, 7.7)
              ..lineTo(19.6, 11.2)
              ..moveTo(8.7, 14.2)
              ..lineTo(8.7, 21)
              ..moveTo(5.8, 18.1)
              ..lineTo(8.7, 21)
              ..lineTo(11.6, 18.1),
            line);
      case Glyph.interiorLight:
        // A dome lamp under the headliner, shining down.
        canvas.drawLine(const Offset(3.4, 5), const Offset(20.6, 5), line);
        canvas.drawArc(
            Rect.fromCircle(center: const Offset(12, 5), radius: 4.4), 0, pi, false, line);
        for (final (a, b) in const [
          (Offset(12, 12.4), Offset(12, 16)),
          (Offset(7.6, 11.2), Offset(5.6, 14)),
          (Offset(16.4, 11.2), Offset(18.4, 14)),
          (Offset(4.8, 9), Offset(2.6, 10.2)),
          (Offset(19.2, 9), Offset(21.4, 10.2)),
        ]) {
          canvas.drawLine(a, b, line);
        }
      case Glyph.massage:
        canvas
          ..drawPath(_seat, Paint()..color = color)
          ..drawPath(
              _seat,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.6
                ..strokeJoin = StrokeJoin.round);
      case Glyph.grip:
        // The stability-control symbol: a car over two skidding tracks.
        canvas.drawPath(
            Path()
              ..moveTo(4.6, 9.4)
              ..lineTo(7, 4.6)
              ..lineTo(17, 4.6)
              ..lineTo(19.4, 9.4),
            line);
        canvas.drawRRect(
            RRect.fromLTRBR(3.2, 9.4, 20.8, 14.4, const Radius.circular(2.2)), line);
        for (final x in const [8.2, 15.8]) {
          canvas.drawPath(
              Path()
                ..moveTo(x, 16.6)
                ..cubicTo(x - 2.8, 17.8, x + 2.8, 19.6, x, 21.2),
              line);
        }
      case Glyph.fan || Glyph.fanOff:
        // Four blades round a hub; off, struck through with a gap each side.
        final off = glyph == Glyph.fanOff;
        if (off) canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
        final fill = Paint()..color = color;
        for (var i = 0; i < 4; i++) {
          canvas
            ..drawPath(_blade, fill)
            ..translate(12, 12)
            ..rotate(pi / 2)
            ..translate(-12, -12);
        }
        canvas.drawCircle(const Offset(12, 12), 1.8, fill);
        if (off) {
          const a = Offset(3.6, 3.6), b = Offset(20.4, 20.4);
          canvas
            ..drawLine(a, b, Paint()
              ..blendMode = BlendMode.clear
              ..strokeWidth = 5.2)
            ..drawLine(a, b, line)
            ..restore();
        }
      case Glyph.autopilot:
        // The wheel alone, filled: docs/icons/autopilot.svg's path, whose
        // disc (radius 12) the caller paints behind it in the state's colour.
        canvas.drawPath(_autopilotWheel, Paint()..color = color);
      case Glyph.washer:
        // A drop of the fluid, outlined.
        canvas.drawPath(
            Path()
              ..moveTo(12, 3)
              ..cubicTo(12, 3, 5.6, 10.4, 5.6, 14.6)
              ..cubicTo(5.6, 18.1, 8.5, 21, 12, 21)
              ..cubicTo(15.5, 21, 18.4, 18.1, 18.4, 14.6)
              ..cubicTo(18.4, 10.4, 12, 3, 12, 3)
              ..close(),
            line);
      case Glyph.cruise:
        // The cruise gauge: an arc open at its foot, the needle up and right.
        canvas.drawArc(Rect.fromCircle(center: const Offset(12, 13.6), radius: 8.8), pi * 5 / 6, pi * 4 / 3, false, line);
        canvas.drawLine(const Offset(12, 13.6), const Offset(16.4, 8.6), line);
        canvas.drawCircle(const Offset(12, 13.6), 1.7, Paint()..color = color);
      default:
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}

/// The Autopilot wheel on the 24 grid: a round rim of radius 7.9 with its
/// three windows cut out (the top one, and the left mirrored for the right).
final _autopilotWheel = Path()
  ..fillType = PathFillType.evenOdd
  ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 7.9))
  // top
  ..moveTo(12.68, 5.46)
  ..cubicTo(14.02, 5.6, 15.14, 6.04, 16.19, 6.86)
  ..cubicTo(17.26, 7.69, 18.11, 8.9, 18.43, 10.03)
  ..cubicTo(18.64, 10.78, 18.56, 10.98, 18.04, 10.98)
  ..cubicTo(17.67, 10.98, 17.13, 10.89, 16.7, 10.76)
  ..cubicTo(16.63, 10.74, 16.48, 10.7, 16.37, 10.66)
  ..cubicTo(16.26, 10.63, 15.79, 10.48, 15.32, 10.32)
  ..cubicTo(13.44, 9.69, 12.71, 9.56, 11.55, 9.65)
  ..cubicTo(10.64, 9.72, 9.93, 9.9, 8.11, 10.5)
  ..cubicTo(6.83, 10.93, 6.56, 11, 6.05, 10.98)
  ..cubicTo(5.54, 10.96, 5.48, 10.83, 5.66, 10.1)
  ..cubicTo(6.27, 7.72, 8.92, 5.65, 11.63, 5.45)
  ..cubicTo(11.8, 5.44, 12.51, 5.44, 12.68, 5.46)
  ..close()
  // left
  ..moveTo(6.9, 12.93)
  ..cubicTo(7.68, 13.05, 8.65, 13.65, 9.64, 14.64)
  ..cubicTo(10.47, 15.47, 10.91, 16.6, 10.92, 17.88)
  ..cubicTo(10.92, 18.3, 10.82, 18.46, 10.54, 18.53)
  ..cubicTo(10.17, 18.63, 9.32, 18.31, 8.62, 17.8)
  ..cubicTo(8.55, 17.75, 8.43, 17.66, 8.35, 17.61)
  ..cubicTo(7.41, 16.93, 6.41, 15.83, 6.01, 15.03)
  ..cubicTo(5.65, 14.3, 5.51, 13.6, 5.69, 13.33)
  ..cubicTo(5.89, 13.01, 6.36, 12.86, 6.9, 12.93)
  ..close()
  // right
  ..moveTo(17.1, 12.93)
  ..cubicTo(16.32, 13.05, 15.35, 13.65, 14.36, 14.64)
  ..cubicTo(13.53, 15.47, 13.09, 16.6, 13.08, 17.88)
  ..cubicTo(13.08, 18.3, 13.18, 18.46, 13.46, 18.53)
  ..cubicTo(13.83, 18.63, 14.68, 18.31, 15.38, 17.8)
  ..cubicTo(15.45, 17.75, 15.57, 17.66, 15.65, 17.61)
  ..cubicTo(16.59, 16.93, 17.59, 15.83, 17.99, 15.03)
  ..cubicTo(18.35, 14.3, 18.49, 13.6, 18.31, 13.33)
  ..cubicTo(18.11, 13.01, 17.64, 12.86, 17.1, 12.93)
  ..close();

// The massage seat: a front seat with the massage's waves on its backrest,
// line art traced to shapes (potrace), drawn filled and outlined a little
// so its lines weigh as the stroked icons'.
final _seat = Path()
  ..moveTo(11.42, 1.32)
  ..cubicTo(11, 1.39, 10.63, 1.53, 10.4, 1.72)
  ..cubicTo(9.97, 2.06, 9.6, 2.98, 9.6, 3.72)
  ..cubicTo(9.6, 3.82, 9.59, 3.89, 9.56, 3.89)
  ..cubicTo(9.54, 3.9, 9.41, 3.94, 9.26, 3.98)
  ..cubicTo(8.71, 4.15, 8.15, 4.48, 7.89, 4.8)
  ..cubicTo(7.54, 5.21, 7.32, 5.94, 7.22, 6.95)
  ..cubicTo(7.1, 8.19, 6.9, 10.46, 6.87, 10.96)
  ..cubicTo(6.78, 12.49, 6.97, 13.57, 7.44, 14.14)
  ..lineTo(7.55, 14.27)
  ..lineTo(7.59, 14.73)
  ..cubicTo(7.61, 14.99, 7.62, 15.27, 7.62, 15.36)
  ..cubicTo(7.62, 15.62, 7.49, 16.22, 7.39, 16.41)
  ..cubicTo(7.15, 16.84, 7.06, 17.47, 7.03, 18.7)
  ..cubicTo(7.01, 19.71, 7.05, 20.2, 7.17, 20.7)
  ..cubicTo(7.33, 21.31, 7.48, 21.61, 7.81, 21.92)
  ..cubicTo(8.21, 22.31, 8.97, 22.54, 10.51, 22.72)
  ..cubicTo(11.08, 22.79, 12.93, 22.8, 13.45, 22.74)
  ..cubicTo(14.92, 22.56, 15.73, 22.34, 16.16, 22.02)
  ..cubicTo(16.3, 21.91, 16.57, 21.56, 16.67, 21.34)
  ..cubicTo(16.78, 21.11, 16.9, 20.68, 16.96, 20.26)
  ..cubicTo(17.01, 19.99, 17.02, 19.75, 17.02, 18.95)
  ..cubicTo(17.02, 17.58, 16.94, 17.01, 16.67, 16.43)
  ..cubicTo(16.48, 16.02, 16.43, 15.64, 16.45, 14.97)
  ..cubicTo(16.46, 14.68, 16.47, 14.4, 16.48, 14.35)
  ..cubicTo(16.49, 14.3, 16.56, 14.19, 16.63, 14.1)
  ..cubicTo(16.9, 13.77, 17.06, 13.3, 17.14, 12.59)
  ..cubicTo(17.22, 11.85, 17.2, 11.35, 17, 8.99)
  ..cubicTo(16.94, 8.23, 16.87, 7.41, 16.85, 7.16)
  ..cubicTo(16.75, 5.79, 16.43, 4.93, 15.87, 4.51)
  ..cubicTo(15.6, 4.31, 15.21, 4.11, 14.84, 4)
  ..cubicTo(14.67, 3.94, 14.52, 3.89, 14.51, 3.88)
  ..cubicTo(14.5, 3.87, 14.47, 3.72, 14.45, 3.56)
  ..cubicTo(14.39, 2.94, 14.24, 2.46, 13.97, 2.06)
  ..cubicTo(13.8, 1.81, 13.72, 1.73, 13.48, 1.59)
  ..cubicTo(13.04, 1.32, 12.12, 1.2, 11.42, 1.32)
  ..close()
  ..moveTo(12.62, 1.5)
  ..cubicTo(12.95, 1.55, 13.22, 1.63, 13.4, 1.74)
  ..cubicTo(13.85, 2.01, 14.2, 2.77, 14.28, 3.64)
  ..cubicTo(14.34, 4.39, 14.17, 4.89, 13.69, 5.3)
  ..cubicTo(13.59, 5.39, 13.5, 5.47, 13.49, 5.47)
  ..cubicTo(13.48, 5.47, 13.51, 5.39, 13.56, 5.29)
  ..cubicTo(13.74, 4.93, 13.75, 4.46, 13.57, 3.86)
  ..cubicTo(13.29, 2.94, 12.96, 2.68, 12.03, 2.68)
  ..cubicTo(11.63, 2.68, 11.36, 2.73, 11.16, 2.83)
  ..cubicTo(10.99, 2.92, 10.79, 3.12, 10.7, 3.3)
  ..cubicTo(10.53, 3.64, 10.35, 4.31, 10.35, 4.63)
  ..cubicTo(10.35, 4.84, 10.43, 5.22, 10.5, 5.34)
  ..cubicTo(10.53, 5.39, 10.55, 5.44, 10.54, 5.44)
  ..cubicTo(10.48, 5.44, 10.08, 5.01, 9.98, 4.84)
  ..cubicTo(9.82, 4.55, 9.77, 4.29, 9.79, 3.76)
  ..cubicTo(9.82, 2.88, 10.14, 2.11, 10.59, 1.81)
  ..cubicTo(11.05, 1.51, 11.89, 1.38, 12.62, 1.5)
  ..close()
  ..moveTo(12.52, 2.78)
  ..cubicTo(13.1, 2.9, 13.35, 3.21, 13.55, 4.12)
  ..cubicTo(13.67, 4.65, 13.66, 4.94, 13.49, 5.28)
  ..cubicTo(13.29, 5.67, 12.96, 5.76, 11.85, 5.73)
  ..cubicTo(10.85, 5.7, 10.64, 5.6, 10.49, 5.08)
  ..cubicTo(10.37, 4.66, 10.48, 3.89, 10.76, 3.36)
  ..cubicTo(10.94, 3.02, 11.19, 2.84, 11.6, 2.77)
  ..cubicTo(11.84, 2.73, 12.28, 2.74, 12.52, 2.78)
  ..close()
  ..moveTo(9.61, 4.26)
  ..cubicTo(9.62, 4.44, 9.68, 4.63, 9.76, 4.84)
  ..cubicTo(9.78, 4.87, 9.74, 4.89, 9.61, 4.93)
  ..cubicTo(9.05, 5.05, 8.56, 5.31, 8.29, 5.62)
  ..cubicTo(8.14, 5.79, 7.98, 6.15, 7.87, 6.58)
  ..cubicTo(7.78, 6.92, 7.76, 7.03, 7.76, 7.34)
  ..lineTo(7.76, 7.7)
  ..lineTo(7.87, 7.94)
  ..cubicTo(7.97, 8.14, 8.05, 8.24, 8.32, 8.51)
  ..cubicTo(8.51, 8.69, 8.8, 8.96, 8.98, 9.09)
  ..cubicTo(9.55, 9.53, 9.52, 9.5, 9.5, 9.72)
  ..lineTo(9.47, 9.91)
  ..lineTo(9.35, 9.79)
  ..cubicTo(9.28, 9.73, 9.03, 9.5, 8.78, 9.3)
  ..cubicTo(7.75, 8.45, 7.54, 8.24, 7.44, 7.93)
  ..cubicTo(7.32, 7.57, 7.37, 6.77, 7.57, 5.98)
  ..cubicTo(7.67, 5.56, 7.86, 5.11, 8.03, 4.91)
  ..cubicTo(8.15, 4.76, 8.48, 4.52, 8.75, 4.38)
  ..cubicTo(8.89, 4.3, 9.5, 4.07, 9.57, 4.06)
  ..cubicTo(9.58, 4.06, 9.6, 4.15, 9.61, 4.26)
  ..close()
  ..moveTo(15.06, 4.26)
  ..cubicTo(15.38, 4.39, 15.71, 4.6, 15.91, 4.79)
  ..cubicTo(16.33, 5.2, 16.62, 6.15, 16.66, 7.22)
  ..cubicTo(16.68, 7.55, 16.67, 7.69, 16.63, 7.85)
  ..cubicTo(16.54, 8.23, 16.46, 8.32, 15.33, 9.27)
  ..cubicTo(15.03, 9.53, 14.73, 9.78, 14.68, 9.84)
  ..lineTo(14.58, 9.94)
  ..lineTo(14.58, 9.83)
  ..cubicTo(14.58, 9.76, 14.57, 9.66, 14.56, 9.6)
  ..cubicTo(14.55, 9.5, 14.55, 9.49, 14.72, 9.37)
  ..cubicTo(15.01, 9.16, 15.63, 8.63, 15.81, 8.43)
  ..cubicTo(16.35, 7.86, 16.41, 7.53, 16.16, 6.51)
  ..cubicTo(15.98, 5.78, 15.75, 5.47, 15.17, 5.19)
  ..cubicTo(14.98, 5.1, 14.72, 4.99, 14.59, 4.96)
  ..cubicTo(14.46, 4.92, 14.33, 4.89, 14.32, 4.88)
  ..cubicTo(14.29, 4.87, 14.29, 4.84, 14.33, 4.74)
  ..cubicTo(14.39, 4.61, 14.44, 4.41, 14.47, 4.19)
  ..lineTo(14.49, 4.07)
  ..lineTo(14.67, 4.13)
  ..cubicTo(14.78, 4.16, 14.95, 4.22, 15.06, 4.26)
  ..close()
  ..moveTo(14.68, 5.06)
  ..cubicTo(15.26, 5.24, 15.71, 5.56, 15.89, 5.93)
  ..cubicTo(16.09, 6.33, 16.24, 7.03, 16.22, 7.46)
  ..cubicTo(16.2, 7.78, 16.13, 7.96, 15.88, 8.26)
  ..cubicTo(15.65, 8.54, 14.57, 9.45, 14.52, 9.41)
  ..cubicTo(14.51, 9.4, 14.55, 9.36, 14.61, 9.31)
  ..cubicTo(14.98, 9.02, 15.62, 8.46, 15.77, 8.29)
  ..cubicTo(15.87, 8.18, 16.01, 7.99, 16.07, 7.87)
  ..lineTo(16.17, 7.66)
  ..lineTo(16.16, 7.29)
  ..cubicTo(16.13, 6.85, 16.01, 6.33, 15.85, 5.99)
  ..cubicTo(15.63, 5.52, 15.18, 5.23, 14.34, 5.02)
  ..cubicTo(14.27, 5, 14.22, 4.97, 14.23, 4.96)
  ..cubicTo(14.24, 4.94, 14.28, 4.94, 14.33, 4.96)
  ..cubicTo(14.38, 4.97, 14.53, 5.02, 14.68, 5.06)
  ..close()
  ..moveTo(9.8, 4.99)
  ..cubicTo(9.76, 5, 9.56, 5.07, 9.35, 5.14)
  ..cubicTo(8.55, 5.39, 8.26, 5.69, 8.03, 6.47)
  ..cubicTo(7.83, 7.19, 7.82, 7.55, 7.99, 7.9)
  ..cubicTo(8.11, 8.14, 8.55, 8.59, 9.12, 9.05)
  ..cubicTo(9.34, 9.23, 9.53, 9.39, 9.54, 9.4)
  ..cubicTo(9.55, 9.44, 9.41, 9.34, 9.05, 9.05)
  ..cubicTo(8.37, 8.51, 8.08, 8.21, 7.9, 7.84)
  ..cubicTo(7.83, 7.69, 7.82, 7.64, 7.82, 7.37)
  ..cubicTo(7.82, 6.92, 7.98, 6.31, 8.19, 5.91)
  ..cubicTo(8.39, 5.52, 8.82, 5.22, 9.45, 5.04)
  ..cubicTo(9.7, 4.96, 9.93, 4.93, 9.8, 4.99)
  ..close()
  ..moveTo(10.23, 5.43)
  ..cubicTo(10.4, 5.59, 10.76, 5.78, 11.03, 5.85)
  ..cubicTo(11.33, 5.93, 12.69, 5.93, 13.02, 5.85)
  ..cubicTo(13.44, 5.75, 13.79, 5.53, 14.04, 5.22)
  ..cubicTo(14.16, 5.05, 14.2, 5.05, 14.56, 5.16)
  ..cubicTo(15.19, 5.34, 15.6, 5.62, 15.79, 6.02)
  ..cubicTo(15.97, 6.41, 16.12, 7.07, 16.1, 7.44)
  ..cubicTo(16.07, 7.93, 15.8, 8.27, 14.79, 9.08)
  ..lineTo(14.53, 9.28)
  ..lineTo(14.51, 9.2)
  ..cubicTo(14.5, 9.15, 14.44, 8.86, 14.38, 8.55)
  ..cubicTo(14.17, 7.49, 14.04, 7.26, 13.57, 7.11)
  ..cubicTo(13.07, 6.94, 11.98, 6.9, 11, 7.01)
  ..cubicTo(10.46, 7.07, 10.22, 7.17, 10.02, 7.43)
  ..cubicTo(9.89, 7.6, 9.75, 8.08, 9.61, 8.91)
  ..cubicTo(9.58, 9.07, 9.55, 9.23, 9.54, 9.25)
  ..cubicTo(9.53, 9.27, 9.43, 9.21, 9.27, 9.08)
  ..cubicTo(8.46, 8.42, 8.19, 8.14, 8.03, 7.81)
  ..cubicTo(7.95, 7.63, 7.94, 7.61, 7.96, 7.27)
  ..cubicTo(7.99, 6.79, 8.16, 6.18, 8.35, 5.86)
  ..cubicTo(8.56, 5.54, 9, 5.28, 9.62, 5.12)
  ..lineTo(9.89, 5.05)
  ..lineTo(9.99, 5.18)
  ..cubicTo(10.05, 5.25, 10.16, 5.36, 10.23, 5.43)
  ..close()
  ..moveTo(13.18, 7.08)
  ..cubicTo(13.65, 7.16, 13.89, 7.29, 14.03, 7.56)
  ..cubicTo(14.18, 7.85, 14.42, 8.92, 14.48, 9.63)
  ..cubicTo(14.57, 10.56, 14.62, 13.73, 14.57, 14.2)
  ..lineTo(14.54, 14.41)
  ..lineTo(14.4, 14.39)
  ..cubicTo(13.7, 14.3, 10.58, 14.29, 9.86, 14.37)
  ..cubicTo(9.68, 14.39, 9.53, 14.4, 9.53, 14.39)
  ..cubicTo(9.52, 14.39, 9.5, 14.21, 9.48, 14.01)
  ..cubicTo(9.44, 13.57, 9.46, 11.88, 9.53, 10.47)
  ..cubicTo(9.56, 9.79, 9.59, 9.45, 9.64, 9.12)
  ..cubicTo(9.74, 8.53, 9.88, 7.92, 9.96, 7.7)
  ..cubicTo(10.12, 7.29, 10.41, 7.13, 11.16, 7.06)
  ..cubicTo(11.49, 7.02, 12.92, 7.04, 13.18, 7.08)
  ..close()
  ..moveTo(16.79, 8.64)
  ..cubicTo(16.83, 9.08, 16.87, 9.57, 16.88, 9.74)
  ..cubicTo(16.94, 10.36, 17, 11.34, 17, 11.73)
  ..cubicTo(17, 12.12, 16.95, 12.71, 16.88, 13.05)
  ..cubicTo(16.84, 13.28, 16.73, 13.63, 16.72, 13.61)
  ..cubicTo(16.71, 13.6, 16.72, 13.52, 16.75, 13.44)
  ..cubicTo(16.97, 12.69, 16.93, 10.79, 16.64, 8.49)
  ..cubicTo(16.61, 8.25, 16.61, 8.2, 16.66, 8.03)
  ..cubicTo(16.69, 7.93, 16.72, 7.84, 16.72, 7.84)
  ..cubicTo(16.73, 7.85, 16.76, 8.21, 16.79, 8.64)
  ..close()
  ..moveTo(7.37, 8.84)
  ..cubicTo(7.08, 11.38, 7.07, 12.77, 7.34, 13.6)
  ..cubicTo(7.35, 13.64, 7.34, 13.64, 7.31, 13.59)
  ..cubicTo(7.25, 13.47, 7.15, 13.09, 7.09, 12.69)
  ..cubicTo(7.05, 12.44, 7.04, 12.16, 7.04, 11.66)
  ..cubicTo(7.04, 11, 7.07, 10.63, 7.2, 9.17)
  ..cubicTo(7.23, 8.82, 7.27, 8.4, 7.28, 8.23)
  ..cubicTo(7.29, 8.05, 7.31, 7.9, 7.32, 7.88)
  ..cubicTo(7.33, 7.87, 7.36, 7.93, 7.39, 8.02)
  ..cubicTo(7.44, 8.18, 7.44, 8.19, 7.37, 8.84)
  ..close()
  ..moveTo(8.04, 9.73)
  ..cubicTo(7.78, 11.6, 7.75, 12.58, 7.94, 13.34)
  ..cubicTo(8.08, 13.92, 8.41, 14.36, 8.79, 14.49)
  ..lineTo(8.99, 14.55)
  ..lineTo(8.67, 14.54)
  ..cubicTo(8.38, 14.53, 8.33, 14.52, 8.12, 14.42)
  ..cubicTo(7.71, 14.22, 7.51, 13.97, 7.37, 13.44)
  ..cubicTo(7.27, 13.07, 7.23, 12.77, 7.21, 12.23)
  ..cubicTo(7.18, 11.47, 7.29, 10.04, 7.49, 8.4)
  ..lineTo(7.51, 8.27)
  ..lineTo(7.83, 8.58)
  ..lineTo(8.16, 8.9)
  ..lineTo(8.04, 9.73)
  ..close()
  ..moveTo(16.58, 8.6)
  ..cubicTo(16.92, 11.64, 16.9, 13.09, 16.52, 13.89)
  ..cubicTo(16.38, 14.17, 16.06, 14.41, 15.7, 14.51)
  ..cubicTo(15.62, 14.53, 15.44, 14.55, 15.31, 14.55)
  ..lineTo(15.07, 14.55)
  ..lineTo(15.22, 14.49)
  ..cubicTo(15.43, 14.42, 15.57, 14.33, 15.72, 14.17)
  ..cubicTo(16.04, 13.8, 16.19, 13.26, 16.22, 12.36)
  ..cubicTo(16.24, 11.72, 16.18, 11.07, 16.01, 9.79)
  ..lineTo(15.89, 8.88)
  ..lineTo(15.99, 8.8)
  ..cubicTo(16.04, 8.76, 16.19, 8.63, 16.3, 8.51)
  ..cubicTo(16.42, 8.39, 16.52, 8.29, 16.53, 8.29)
  ..cubicTo(16.54, 8.29, 16.56, 8.43, 16.58, 8.6)
  ..close()
  ..moveTo(8.27, 9.03)
  ..cubicTo(8.24, 9.13, 8.04, 10.72, 8, 11.17)
  ..cubicTo(7.91, 12.06, 7.95, 12.92, 8.09, 13.41)
  ..cubicTo(8.26, 14, 8.61, 14.38, 9.05, 14.43)
  ..lineTo(9.26, 14.46)
  ..lineTo(9.03, 14.45)
  ..cubicTo(8.76, 14.44, 8.65, 14.39, 8.43, 14.16)
  ..cubicTo(7.81, 13.53, 7.73, 12.21, 8.15, 9.46)
  ..cubicTo(8.19, 9.19, 8.22, 8.96, 8.22, 8.94)
  ..cubicTo(8.22, 8.91, 8.23, 8.92, 8.25, 8.94)
  ..cubicTo(8.27, 8.97, 8.28, 9.01, 8.27, 9.03)
  ..close()
  ..moveTo(15.95, 9.86)
  ..cubicTo(16.13, 11.17, 16.15, 11.44, 16.15, 12.14)
  ..cubicTo(16.15, 12.79, 16.11, 13.11, 15.98, 13.53)
  ..cubicTo(15.81, 14.1, 15.4, 14.47, 14.94, 14.46)
  ..lineTo(14.77, 14.45)
  ..lineTo(14.96, 14.43)
  ..cubicTo(15.51, 14.35, 15.83, 13.97, 16.01, 13.19)
  ..cubicTo(16.07, 12.86, 16.08, 12.76, 16.08, 12.17)
  ..cubicTo(16.08, 11.45, 16.05, 11.06, 15.88, 9.78)
  ..cubicTo(15.79, 9.1, 15.77, 8.91, 15.82, 8.95)
  ..cubicTo(15.83, 8.96, 15.89, 9.36, 15.95, 9.86)
  ..close()
  ..moveTo(8.86, 9.46)
  ..cubicTo(9.15, 9.7, 9.39, 9.93, 9.42, 9.97)
  ..cubicTo(9.45, 10.04, 9.45, 10.25, 9.42, 11.42)
  ..cubicTo(9.39, 12.73, 9.39, 14.16, 9.44, 14.3)
  ..cubicTo(9.46, 14.37, 9.45, 14.37, 9.24, 14.37)
  ..cubicTo(8.96, 14.37, 8.79, 14.31, 8.6, 14.16)
  ..cubicTo(7.98, 13.63, 7.86, 12.3, 8.22, 9.87)
  ..cubicTo(8.25, 9.65, 8.29, 9.37, 8.3, 9.25)
  ..cubicTo(8.31, 9.13, 8.32, 9.03, 8.33, 9.03)
  ..cubicTo(8.34, 9.03, 8.58, 9.23, 8.86, 9.46)
  ..close()
  ..moveTo(15.85, 10.05)
  ..cubicTo(15.99, 11.23, 16.02, 11.67, 16.01, 12.35)
  ..cubicTo(15.98, 13.26, 15.84, 13.77, 15.52, 14.08)
  ..cubicTo(15.33, 14.27, 15.16, 14.35, 14.85, 14.36)
  ..lineTo(14.6, 14.38)
  ..lineTo(14.63, 14.22)
  ..cubicTo(14.66, 13.98, 14.65, 11.76, 14.61, 10.88)
  ..cubicTo(14.57, 10.04, 14.57, 10.03, 14.79, 9.83)
  ..cubicTo(14.86, 9.76, 15.09, 9.56, 15.31, 9.38)
  ..lineTo(15.7, 9.06)
  ..lineTo(15.72, 9.14)
  ..cubicTo(15.73, 9.19, 15.79, 9.6, 15.85, 10.05)
  ..close()
  ..moveTo(8.16, 14.97)
  ..lineTo(8.16, 15.29)
  ..lineTo(8.01, 15.51)
  ..cubicTo(7.93, 15.63, 7.84, 15.77, 7.8, 15.81)
  ..lineTo(7.74, 15.88)
  ..lineTo(7.76, 15.76)
  ..cubicTo(7.79, 15.62, 7.79, 14.95, 7.76, 14.65)
  ..lineTo(7.74, 14.43)
  ..lineTo(7.95, 14.54)
  ..lineTo(8.16, 14.65)
  ..lineTo(8.16, 14.97)
  ..close()
  ..moveTo(16.27, 14.94)
  ..cubicTo(16.26, 15.27, 16.26, 15.54, 16.28, 15.65)
  ..cubicTo(16.3, 15.76, 16.31, 15.85, 16.31, 15.86)
  ..cubicTo(16.29, 15.87, 15.96, 15.4, 15.92, 15.3)
  ..cubicTo(15.89, 15.26, 15.88, 15.17, 15.88, 15.1)
  ..cubicTo(15.88, 15.04, 15.89, 14.91, 15.89, 14.81)
  ..cubicTo(15.89, 14.64, 15.89, 14.64, 16.02, 14.58)
  ..cubicTo(16.09, 14.55, 16.18, 14.5, 16.21, 14.48)
  ..cubicTo(16.24, 14.45, 16.28, 14.43, 16.28, 14.43)
  ..cubicTo(16.29, 14.43, 16.28, 14.66, 16.27, 14.94)
  ..close()
  ..moveTo(14.19, 14.55)
  ..cubicTo(14.34, 14.57, 14.56, 14.6, 14.67, 14.63)
  ..lineTo(14.88, 14.68)
  ..lineTo(14.79, 14.8)
  ..cubicTo(14.74, 14.86, 14.68, 14.97, 14.65, 15.05)
  ..cubicTo(14.6, 15.17, 14.59, 15.18, 14.49, 15.18)
  ..cubicTo(14.43, 15.18, 13.87, 15.16, 13.24, 15.15)
  ..cubicTo(12.17, 15.12, 9.68, 15.15, 9.53, 15.2)
  ..cubicTo(9.49, 15.21, 9.46, 15.18, 9.41, 15.05)
  ..cubicTo(9.37, 14.97, 9.3, 14.85, 9.26, 14.79)
  ..lineTo(9.18, 14.68)
  ..lineTo(9.34, 14.65)
  ..cubicTo(9.66, 14.57, 9.9, 14.54, 10.4, 14.52)
  ..cubicTo(11.08, 14.49, 13.83, 14.51, 14.19, 14.55)
  ..close()
  ..moveTo(8.33, 14.69)
  ..cubicTo(8.36, 14.71, 8.36, 14.76, 8.31, 14.89)
  ..cubicTo(8.25, 15.08, 8.25, 15.07, 8.24, 14.79)
  ..cubicTo(8.23, 14.67, 8.26, 14.64, 8.33, 14.69)
  ..close()
  ..moveTo(15.81, 14.88)
  ..lineTo(15.8, 15.1)
  ..lineTo(15.73, 14.91)
  ..cubicTo(15.67, 14.73, 15.67, 14.71, 15.71, 14.69)
  ..cubicTo(15.81, 14.65, 15.82, 14.67, 15.81, 14.88)
  ..close()
  ..moveTo(9.19, 14.81)
  ..cubicTo(9.23, 14.87, 9.3, 14.99, 9.33, 15.07)
  ..cubicTo(9.4, 15.21, 9.4, 15.23, 9.36, 15.67)
  ..cubicTo(9.23, 17.38, 9.19, 17.63, 8.47, 21.16)
  ..cubicTo(8.43, 21.38, 8.38, 21.56, 8.36, 21.56)
  ..cubicTo(8.3, 21.56, 8.01, 21.3, 7.89, 21.14)
  ..cubicTo(7.66, 20.83, 7.51, 20.45, 7.43, 19.91)
  ..cubicTo(7.32, 19.22, 7.34, 17.78, 7.48, 17.11)
  ..cubicTo(7.57, 16.63, 7.66, 16.45, 8.13, 15.81)
  ..cubicTo(8.35, 15.51, 8.46, 15.31, 8.56, 14.98)
  ..lineTo(8.64, 14.73)
  ..lineTo(8.83, 14.72)
  ..cubicTo(8.93, 14.71, 9.04, 14.71, 9.06, 14.7)
  ..cubicTo(9.09, 14.7, 9.15, 14.75, 9.19, 14.81)
  ..close()
  ..moveTo(15.23, 14.73)
  ..cubicTo(15.33, 14.73, 15.42, 14.75, 15.42, 14.76)
  ..cubicTo(15.42, 14.78, 15.47, 14.93, 15.54, 15.11)
  ..cubicTo(15.65, 15.41, 15.85, 15.72, 16.11, 16.05)
  ..cubicTo(16.37, 16.39, 16.52, 16.74, 16.6, 17.25)
  ..cubicTo(16.71, 17.97, 16.73, 19.24, 16.63, 19.88)
  ..cubicTo(16.54, 20.49, 16.36, 20.92, 16.09, 21.22)
  ..cubicTo(15.94, 21.39, 15.7, 21.59, 15.67, 21.56)
  ..cubicTo(15.67, 21.55, 15.63, 21.36, 15.58, 21.14)
  ..cubicTo(15.54, 20.92, 15.42, 20.32, 15.31, 19.81)
  ..cubicTo(14.99, 18.26, 14.86, 17.45, 14.76, 16.42)
  ..cubicTo(14.67, 15.57, 14.65, 15.29, 14.68, 15.17)
  ..cubicTo(14.71, 15.02, 14.93, 14.69, 14.99, 14.71)
  ..cubicTo(15.02, 14.72, 15.12, 14.73, 15.23, 14.73)
  ..close()
  ..moveTo(13.51, 15.22)
  ..cubicTo(14.07, 15.23, 14.55, 15.25, 14.56, 15.27)
  ..cubicTo(14.58, 15.29, 14.61, 15.44, 14.62, 15.62)
  ..cubicTo(14.64, 15.96, 14.72, 16.75, 14.74, 16.89)
  ..lineTo(14.75, 16.97)
  ..lineTo(12.12, 16.97)
  ..cubicTo(10.68, 16.97, 9.47, 16.98, 9.44, 16.99)
  ..cubicTo(9.32, 17.04, 9.31, 17, 9.35, 16.63)
  ..cubicTo(9.37, 16.43, 9.4, 16.05, 9.42, 15.77)
  ..lineTo(9.46, 15.27)
  ..lineTo(9.75, 15.25)
  ..cubicTo(10.07, 15.23, 11.96, 15.19, 12.28, 15.2)
  ..cubicTo(12.4, 15.2, 12.95, 15.21, 13.51, 15.22)
  ..close()
  ..moveTo(8.19, 15.61)
  ..cubicTo(8.07, 15.8, 8.05, 15.79, 8.17, 15.6)
  ..cubicTo(8.22, 15.52, 8.27, 15.46, 8.28, 15.46)
  ..cubicTo(8.28, 15.47, 8.25, 15.54, 8.19, 15.61)
  ..close()
  ..moveTo(7.79, 16.16)
  ..cubicTo(7.47, 16.61, 7.36, 17.06, 7.29, 18.27)
  ..cubicTo(7.26, 18.89, 7.27, 19.24, 7.34, 19.79)
  ..cubicTo(7.41, 20.29, 7.46, 20.49, 7.62, 20.83)
  ..cubicTo(7.78, 21.16, 7.95, 21.37, 8.2, 21.55)
  ..cubicTo(8.35, 21.65, 8.37, 21.67, 8.39, 21.8)
  ..cubicTo(8.4, 21.87, 8.42, 21.97, 8.43, 22.02)
  ..cubicTo(8.47, 22.13, 8.43, 22.13, 8.23, 22.01)
  ..cubicTo(7.95, 21.85, 7.73, 21.61, 7.57, 21.26)
  ..cubicTo(7.3, 20.71, 7.2, 20.12, 7.2, 19.07)
  ..cubicTo(7.2, 17.91, 7.3, 17.09, 7.47, 16.67)
  ..cubicTo(7.56, 16.46, 7.84, 16.02, 7.88, 16.02)
  ..cubicTo(7.89, 16.02, 7.85, 16.08, 7.79, 16.16)
  ..close()
  ..moveTo(16.41, 16.34)
  ..cubicTo(16.68, 16.8, 16.78, 17.26, 16.83, 18.35)
  ..cubicTo(16.87, 19.14, 16.83, 20.02, 16.75, 20.45)
  ..cubicTo(16.6, 21.23, 16.28, 21.76, 15.81, 22.01)
  ..cubicTo(15.62, 22.11, 15.62, 22.11, 15.63, 22.04)
  ..cubicTo(15.64, 22, 15.66, 21.89, 15.67, 21.81)
  ..cubicTo(15.69, 21.66, 15.7, 21.65, 15.86, 21.54)
  ..cubicTo(16.28, 21.26, 16.58, 20.7, 16.69, 19.98)
  ..cubicTo(16.76, 19.57, 16.78, 18.49, 16.74, 17.91)
  ..cubicTo(16.67, 17.09, 16.6, 16.75, 16.39, 16.35)
  ..cubicTo(16.31, 16.22, 16.26, 16.11, 16.27, 16.11)
  ..cubicTo(16.27, 16.11, 16.34, 16.21, 16.41, 16.34)
  ..close()
  ..moveTo(14.52, 17.05)
  ..lineTo(14.75, 17.08)
  ..lineTo(14.78, 17.29)
  ..cubicTo(15.06, 18.95, 15.04, 18.86, 14.99, 18.86)
  ..cubicTo(14.97, 18.86, 14.79, 18.95, 14.58, 19.04)
  ..cubicTo(14.37, 19.14, 14.12, 19.23, 14.02, 19.25)
  ..cubicTo(13.89, 19.28, 13.28, 19.28, 11.92, 19.28)
  ..cubicTo(9.75, 19.27, 9.98, 19.29, 9.39, 19)
  ..cubicTo(9.24, 18.93, 9.09, 18.86, 9.07, 18.86)
  ..cubicTo(9.02, 18.86, 9.02, 18.86, 9.12, 18.26)
  ..cubicTo(9.17, 17.97, 9.23, 17.59, 9.26, 17.41)
  ..lineTo(9.31, 17.07)
  ..lineTo(9.57, 17.06)
  ..cubicTo(10.07, 17.04, 14.3, 17.04, 14.52, 17.05)
  ..close()
  ..moveTo(9.45, 19.11)
  ..cubicTo(9.96, 19.36, 9.85, 19.35, 12.11, 19.34)
  ..cubicTo(14.35, 19.33, 14.1, 19.35, 14.67, 19.08)
  ..cubicTo(14.84, 18.99, 15, 18.92, 15.02, 18.92)
  ..cubicTo(15.06, 18.92, 15.05, 18.89, 15.2, 19.63)
  ..cubicTo(15.62, 21.63, 15.64, 21.8, 15.55, 22.04)
  ..cubicTo(15.49, 22.18, 15.43, 22.2, 14.76, 22.34)
  ..cubicTo(13.85, 22.52, 13.31, 22.58, 12.3, 22.6)
  ..cubicTo(11.69, 22.61, 11.37, 22.61, 10.93, 22.57)
  ..cubicTo(10.11, 22.5, 9.11, 22.33, 8.71, 22.2)
  ..cubicTo(8.55, 22.15, 8.55, 22.15, 8.5, 21.98)
  ..cubicTo(8.47, 21.87, 8.46, 21.76, 8.47, 21.61)
  ..cubicTo(8.49, 21.45, 8.85, 19.63, 8.99, 18.99)
  ..cubicTo(9.01, 18.9, 9.08, 18.92, 9.45, 19.11)
  ..close()
  ..moveTo(10.69, 8.15)
  ..cubicTo(10.6, 8.21, 10.37, 8.57, 10.28, 8.77)
  ..cubicTo(10.24, 8.87, 10.18, 9.05, 10.15, 9.19)
  ..cubicTo(10.06, 9.63, 10.14, 10.07, 10.44, 10.75)
  ..cubicTo(10.89, 11.79, 10.94, 12.06, 10.75, 12.54)
  ..cubicTo(10.7, 12.65, 10.61, 12.83, 10.54, 12.95)
  ..cubicTo(10.39, 13.19, 10.38, 13.29, 10.48, 13.4)
  ..cubicTo(10.66, 13.57, 10.83, 13.52, 11.01, 13.25)
  ..cubicTo(11.3, 12.8, 11.42, 12.41, 11.39, 11.96)
  ..cubicTo(11.37, 11.62, 11.3, 11.37, 11.07, 10.83)
  ..cubicTo(10.76, 10.11, 10.7, 9.92, 10.69, 9.62)
  ..cubicTo(10.67, 9.29, 10.73, 9.08, 10.95, 8.71)
  ..cubicTo(11.13, 8.41, 11.14, 8.3, 11.01, 8.18)
  ..cubicTo(10.9, 8.1, 10.78, 8.08, 10.69, 8.15)
  ..close()
  ..moveTo(10.92, 8.33)
  ..cubicTo(10.95, 8.37, 10.94, 8.4, 10.85, 8.55)
  ..cubicTo(10.68, 8.8, 10.59, 9.02, 10.54, 9.27)
  ..cubicTo(10.46, 9.66, 10.55, 10.07, 10.9, 10.85)
  ..cubicTo(11.12, 11.34, 11.2, 11.61, 11.21, 11.97)
  ..cubicTo(11.23, 12.24, 11.22, 12.33, 11.16, 12.53)
  ..cubicTo(11.05, 12.93, 10.8, 13.33, 10.67, 13.31)
  ..cubicTo(10.57, 13.3, 10.58, 13.19, 10.7, 12.99)
  ..cubicTo(10.9, 12.69, 10.99, 12.45, 11, 12.14)
  ..cubicTo(11.02, 11.79, 10.96, 11.58, 10.65, 10.81)
  ..cubicTo(10.51, 10.49, 10.38, 10.13, 10.35, 10)
  ..cubicTo(10.24, 9.57, 10.28, 9.17, 10.48, 8.75)
  ..cubicTo(10.67, 8.35, 10.82, 8.21, 10.92, 8.33)
  ..close()
  ..moveTo(11.92, 8.14)
  ..cubicTo(11.79, 8.19, 11.53, 8.61, 11.4, 9.01)
  ..cubicTo(11.34, 9.16, 11.33, 9.26, 11.33, 9.54)
  ..cubicTo(11.33, 9.85, 11.34, 9.92, 11.43, 10.19)
  ..cubicTo(11.48, 10.35, 11.61, 10.69, 11.72, 10.93)
  ..cubicTo(11.94, 11.44, 12.01, 11.68, 12.04, 11.93)
  ..cubicTo(12.08, 12.23, 11.96, 12.61, 11.73, 12.95)
  ..cubicTo(11.62, 13.11, 11.59, 13.21, 11.64, 13.32)
  ..cubicTo(11.68, 13.42, 11.8, 13.5, 11.91, 13.5)
  ..cubicTo(12.11, 13.5, 12.48, 12.88, 12.57, 12.4)
  ..cubicTo(12.59, 12.3, 12.6, 12.1, 12.59, 11.94)
  ..cubicTo(12.58, 11.7, 12.55, 11.58, 12.44, 11.26)
  ..cubicTo(12.37, 11.05, 12.24, 10.72, 12.15, 10.53)
  ..cubicTo(11.79, 9.71, 11.79, 9.27, 12.16, 8.7)
  ..cubicTo(12.33, 8.46, 12.34, 8.4, 12.29, 8.27)
  ..cubicTo(12.22, 8.13, 12.08, 8.07, 11.92, 8.14)
  ..close()
  ..moveTo(12.13, 8.35)
  ..cubicTo(12.15, 8.39, 12.12, 8.46, 12.05, 8.57)
  ..cubicTo(11.77, 8.99, 11.67, 9.36, 11.73, 9.74)
  ..cubicTo(11.77, 10.02, 11.82, 10.19, 12.06, 10.74)
  ..cubicTo(12.47, 11.7, 12.52, 12.08, 12.34, 12.61)
  ..cubicTo(12.27, 12.83, 12.07, 13.18, 11.97, 13.27)
  ..cubicTo(11.94, 13.3, 11.89, 13.32, 11.86, 13.31)
  ..cubicTo(11.77, 13.3, 11.78, 13.18, 11.88, 13.04)
  ..cubicTo(12, 12.86, 12.13, 12.57, 12.18, 12.36)
  ..cubicTo(12.26, 12, 12.16, 11.48, 11.87, 10.86)
  ..cubicTo(11.38, 9.78, 11.37, 9.21, 11.83, 8.49)
  ..cubicTo(11.94, 8.33, 11.98, 8.29, 12.04, 8.29)
  ..cubicTo(12.09, 8.29, 12.12, 8.31, 12.13, 8.35)
  ..close()
  ..moveTo(13.12, 8.14)
  ..cubicTo(12.98, 8.21, 12.67, 8.75, 12.58, 9.08)
  ..cubicTo(12.52, 9.33, 12.53, 9.75, 12.6, 10.04)
  ..cubicTo(12.66, 10.31, 12.71, 10.44, 12.95, 10.98)
  ..cubicTo(13.13, 11.39, 13.26, 11.84, 13.26, 12.06)
  ..cubicTo(13.26, 12.32, 13.12, 12.7, 12.92, 12.98)
  ..cubicTo(12.8, 13.15, 12.8, 13.29, 12.89, 13.39)
  ..cubicTo(12.98, 13.49, 13.09, 13.51, 13.2, 13.47)
  ..cubicTo(13.31, 13.42, 13.56, 13.05, 13.68, 12.74)
  ..cubicTo(13.78, 12.51, 13.78, 12.48, 13.78, 12.08)
  ..cubicTo(13.78, 11.58, 13.76, 11.48, 13.42, 10.68)
  ..cubicTo(13.14, 10.02, 13.1, 9.86, 13.1, 9.56)
  ..cubicTo(13.09, 9.26, 13.16, 9.05, 13.35, 8.72)
  ..cubicTo(13.53, 8.43, 13.54, 8.38, 13.49, 8.26)
  ..cubicTo(13.41, 8.11, 13.27, 8.07, 13.12, 8.14)
  ..close()
  ..moveTo(13.34, 8.35)
  ..cubicTo(13.35, 8.38, 13.3, 8.49, 13.23, 8.59)
  ..cubicTo(13.01, 8.93, 12.93, 9.21, 12.93, 9.57)
  ..cubicTo(12.93, 9.86, 13.01, 10.15, 13.27, 10.75)
  ..cubicTo(13.56, 11.42, 13.63, 11.68, 13.63, 12.08)
  ..cubicTo(13.63, 12.33, 13.62, 12.41, 13.54, 12.63)
  ..cubicTo(13.49, 12.77, 13.39, 12.98, 13.31, 13.1)
  ..cubicTo(13.18, 13.3, 13.16, 13.32, 13.08, 13.31)
  ..cubicTo(12.96, 13.3, 12.97, 13.22, 13.1, 13.01)
  ..cubicTo(13.27, 12.76, 13.35, 12.57, 13.39, 12.31)
  ..cubicTo(13.46, 11.91, 13.38, 11.56, 13.06, 10.82)
  ..cubicTo(12.73, 10.06, 12.64, 9.63, 12.73, 9.21)
  ..cubicTo(12.78, 8.97, 13, 8.5, 13.13, 8.37)
  ..cubicTo(13.21, 8.27, 13.33, 8.27, 13.34, 8.35)
  ..close();

final _traced = <Glyph, (List<Path>, List<Path>)>{
  Glyph.frunk: (_frunkStrokes, _frunkFills),
  Glyph.trunk: (_trunkStrokes, _trunkFills),
  Glyph.recirc: (_recircStrokes, _recircFills),
  Glyph.chargePort: (_boltStrokes, _boltFills),
  Glyph.doorFL: ([_door(front: true)], _doorFills),
  Glyph.doorFR: ([_door(front: true)], _doorFills),
  Glyph.doorRL: ([_door(front: false)], _doorFills),
  Glyph.doorRR: ([_door(front: false)], _doorFills),
  Glyph.lowBeam: (_lowBeamStrokes, <Path>[]),
  Glyph.highBeam: (_highBeamStrokes, <Path>[]),
  Glyph.drl: (<Path>[], _drlFills),
};

// Generated from the vectorised photos (stroke 1.9 throughout).
final _frunkStrokes = [
  Path()..moveTo(14.1, 16.64)..cubicTo(14.1, 18.59, 12.51, 20.18, 10.56, 20.18)..cubicTo(8.62, 20.18, 7.03, 18.59, 7.03, 16.64)..cubicTo(7.03, 14.69, 8.62, 13.1, 10.56, 13.1)..cubicTo(12.51, 13.1, 14.1, 14.69, 14.1, 16.64)..close(),
  Path()..moveTo(7.39, 18.2)..lineTo(3.95, 17.67)..cubicTo(3.37, 17.58, 2.95, 17.08, 2.95, 16.5)..lineTo(2.95, 12.57)..cubicTo(2.95, 11.4, 9.29, 9.4, 12.87, 9.4)..lineTo(16.1, 9.4)..lineTo(21.05, 7.03),
  Path()..moveTo(13.77, 18.11)..lineTo(21.05, 18.11),
  Path()..moveTo(6, 3.82)..cubicTo(9.28, 3.82, 13.77, 6.44, 16.45, 9.23),
];
final _frunkFills = <Path>[];
final _trunkStrokes = [
  Path()..moveTo(2.95, 5.38)..cubicTo(11.56, 5.38, 11.74, 8.46, 20.24, 9.96)..cubicTo(20.59, 10.02, 20.81, 10.36, 20.73, 10.71)..cubicTo(19.97, 13.84, 20.74, 12.99, 21.03, 15.5)..cubicTo(21.19, 16.82, 20.17, 18.06, 18.83, 18.06)..lineTo(15.58, 18.06),
  Path()..moveTo(13.85, 8.08)..lineTo(18.54, 3.93)..lineTo(20.15, 4.94),
  Path()..moveTo(2.95, 18.06)..lineTo(9.29, 18.06),
  Path()..moveTo(15.91, 16.59)..cubicTo(15.91, 18.52, 14.36, 20.07, 12.43, 20.07)..cubicTo(10.51, 20.07, 8.95, 18.52, 8.95, 16.59)..cubicTo(8.95, 14.67, 10.51, 13.11, 12.43, 13.11)..cubicTo(14.36, 13.11, 15.91, 14.67, 15.91, 16.59)..close(),
];
final _trunkFills = <Path>[];
/// The car's door-release icon turned a quarter left, as it sits on the
/// door, so it reads as the car from above, nose up, with a door swung open
/// on its left side: the outline is the body, the gap the door opening, the
/// slanted stroke the door on its front hinge. A front door opens near the
/// nose, a rear one near the tail. Shapes and corners from the traced photo.
Path _door({required bool front}) {
  const k = 0.5523, l = 8.6, r = 19.0, t = 3.4, b = 20.6;
  final hinge = front ? 7.0 : 12.2, end = hinge + 7.0; // the opening
  return Path()
    ..moveTo(l, end)
    ..lineTo(l, b - 1.4)
    ..cubicTo(l, b - 1.4 + 1.4 * k, l + 1.4 - 1.4 * k, b, l + 1.4, b)
    ..lineTo(r - 2.2, b)
    ..cubicTo(r - 2.2 + 2.2 * k, b, r, b - 2.2 + 2.2 * k, r, b - 2.2)
    ..lineTo(r, t + 2.2)
    ..cubicTo(r, t + 2.2 - 2.2 * k, r - 2.2 + 2.2 * k, t, r - 2.2, t)
    ..lineTo(l + 3.6, t)
    ..cubicTo(l + 3.6 - 3.6 * k, t, l, t + 3.6 - 3.6 * k, l, t + 3.6)
    ..lineTo(l, hinge)
    ..lineTo(l - 3.6, hinge + 4.56);
}

final _doorFills = <Path>[];
// One fan blade, from the hub up and swept clockwise; the fan turns it four
// times.
final _blade = Path()
  ..moveTo(12, 10.2)
  ..cubicTo(10.4, 8.8, 10.1, 4.6, 12.3, 2.9)
  ..cubicTo(14.4, 1.4, 17.8, 3.4, 16.5, 6.5)
  ..cubicTo(15.7, 8.4, 13.6, 9.3, 12, 10.2)
  ..close();
final _recircStrokes = [
  Path()..moveTo(6.53, 16.9)..lineTo(5.93, 16.9)..cubicTo(4.28, 16.9, 2.95, 15.57, 2.95, 13.92)..lineTo(2.95, 7.8)..cubicTo(2.95, 6.15, 4.28, 4.82, 5.93, 4.82)..lineTo(18.07, 4.82)..cubicTo(19.72, 4.82, 21.05, 6.15, 21.05, 7.8)..lineTo(21.05, 13.92)..cubicTo(21.05, 15.57, 19.72, 16.9, 18.07, 16.9)..lineTo(14.09, 16.9),
];
final _recircFills = [
  Path()..moveTo(9.79, 17.45)..cubicTo(9.44, 17.17, 9.44, 16.63, 9.79, 16.36)..lineTo(12.95, 13.83)..cubicTo(13.41, 13.46, 14.09, 13.79, 14.09, 14.38)..lineTo(14.09, 19.43)..cubicTo(14.09, 20.02, 13.41, 20.34, 12.95, 19.98)..close(),
];
final _boltStrokes = <Path>[];
final _boltFills = [
  Path()..moveTo(5.29, 13.23)..lineTo(11.75, 2.2)..cubicTo(11.95, 1.85, 12.49, 1.99, 12.49, 2.4)..lineTo(12.49, 9.77)..cubicTo(12.49, 9.99, 12.67, 10.17, 12.89, 10.17)..lineTo(18.37, 10.17)..cubicTo(18.67, 10.17, 18.87, 10.51, 18.71, 10.77)..lineTo(12.25, 21.8)..cubicTo(12.05, 22.15, 11.51, 22.01, 11.51, 21.6)..lineTo(11.51, 14.23)..cubicTo(11.51, 14.01, 11.33, 13.83, 11.11, 13.83)..lineTo(5.63, 13.83)..cubicTo(5.33, 13.83, 5.13, 13.49, 5.29, 13.23)..close(),
];
// The lamp symbols of ISO 7000 (0082 high beam, 0083 low beam, 2611
// daytime running lights), the ones the car's own indicators follow, from
// the standard's SVGs: the lamp at the centre of its outline, four beams
// rather than five so they stay apart at the dash's 20 dp.
final _lamp = Path()..moveTo(11.57, 6.07)..lineTo(14.55, 6.07)..cubicTo(16.72, 6.07, 18.68, 6.73, 20.09, 7.8)..cubicTo(21.51, 8.88, 22.39, 10.36, 22.39, 12)..cubicTo(22.39, 13.64, 21.51, 15.12, 20.09, 16.2)..cubicTo(18.68, 17.27, 16.72, 17.93, 14.55, 17.93)..lineTo(11.57, 17.93)..cubicTo(10.11, 14.27, 10.11, 9.73, 11.57, 6.07)..close();
final _lowBeamStrokes = [
  _lamp,
  Path()..moveTo(3.31, 8.86)..lineTo(8.35, 6.96),
  Path()..moveTo(3.29, 12.53)..lineTo(7.69, 10.68),
  Path()..moveTo(3.29, 16.23)..lineTo(7.7, 14.38),
  Path()..moveTo(3.31, 19.97)..lineTo(8.44, 18.04),
];
final _highBeamStrokes = [
  _lamp,
  Path()..moveTo(2.56, 6.55)..lineTo(8.32, 6.55),
  Path()..moveTo(2.56, 10.18)..lineTo(7.62, 10.18),
  Path()..moveTo(2.56, 13.82)..lineTo(7.62, 13.82),
  Path()..moveTo(2.56, 17.45)..lineTo(8.32, 17.45),
];
final _drlFills = [
  Path()..moveTo(14.21, 6.53)..cubicTo(18.46, 6.53, 21.91, 8.98, 21.91, 12)..cubicTo(21.91, 15.02, 18.46, 17.47, 14.21, 17.47)..lineTo(12.65, 17.35)..cubicTo(11.03, 15.39, 11.03, 8.61, 12.65, 6.65)..close(),
  Path()..moveTo(10.56, 8.04)..cubicTo(10.56, 8.59, 10.11, 9.04, 9.56, 9.04)..cubicTo(9.01, 9.04, 8.56, 8.59, 8.56, 8.04)..cubicTo(8.56, 7.49, 9.01, 7.04, 9.56, 7.04)..cubicTo(10.11, 7.04, 10.56, 7.49, 10.56, 8.04)..close(),
  Path()..moveTo(7.36, 8.04)..cubicTo(7.36, 8.46, 7.01, 8.81, 6.59, 8.81)..cubicTo(6.16, 8.81, 5.82, 8.46, 5.82, 8.04)..cubicTo(5.82, 7.62, 6.16, 7.27, 6.59, 7.27)..cubicTo(7.01, 7.27, 7.36, 7.62, 7.36, 8.04)..close(),
  Path()..moveTo(4.61, 8.04)..cubicTo(4.61, 8.38, 4.34, 8.65, 4, 8.65)..cubicTo(3.66, 8.65, 3.39, 8.38, 3.39, 8.04)..cubicTo(3.39, 7.7, 3.66, 7.43, 4, 7.43)..cubicTo(4.34, 7.43, 4.61, 7.7, 4.61, 8.04)..close(),
  Path()..moveTo(9.26, 11.99)..cubicTo(9.26, 12.54, 8.82, 12.99, 8.27, 12.99)..cubicTo(7.71, 12.99, 7.27, 12.54, 7.27, 11.99)..cubicTo(7.27, 11.44, 7.71, 11, 8.27, 11)..cubicTo(8.82, 11, 9.26, 11.44, 9.26, 11.99)..close(),
  Path()..moveTo(6.06, 11.99)..cubicTo(6.06, 12.42, 5.72, 12.76, 5.29, 12.76)..cubicTo(4.87, 12.76, 4.52, 12.42, 4.52, 11.99)..cubicTo(4.52, 11.57, 4.87, 11.22, 5.29, 11.22)..cubicTo(5.72, 11.22, 6.06, 11.57, 6.06, 11.99)..close(),
  Path()..moveTo(3.31, 11.99)..cubicTo(3.31, 12.33, 3.04, 12.6, 2.7, 12.6)..cubicTo(2.37, 12.6, 2.09, 12.33, 2.09, 11.99)..cubicTo(2.09, 11.66, 2.37, 11.38, 2.7, 11.38)..cubicTo(3.04, 11.38, 3.31, 11.66, 3.31, 11.99)..close(),
  Path()..moveTo(10.56, 15.95)..cubicTo(10.56, 16.5, 10.11, 16.95, 9.56, 16.95)..cubicTo(9.01, 16.95, 8.56, 16.5, 8.56, 15.95)..cubicTo(8.56, 15.4, 9.01, 14.95, 9.56, 14.95)..cubicTo(10.11, 14.95, 10.56, 15.4, 10.56, 15.95)..close(),
  Path()..moveTo(7.36, 15.95)..cubicTo(7.36, 16.37, 7.01, 16.72, 6.59, 16.72)..cubicTo(6.16, 16.72, 5.82, 16.37, 5.82, 15.95)..cubicTo(5.82, 15.52, 6.16, 15.18, 6.59, 15.18)..cubicTo(7.01, 15.18, 7.36, 15.52, 7.36, 15.95)..close(),
  Path()..moveTo(4.61, 15.95)..cubicTo(4.61, 16.28, 4.34, 16.56, 4, 16.56)..cubicTo(3.66, 16.56, 3.39, 16.28, 3.39, 15.95)..cubicTo(3.39, 15.61, 3.66, 15.34, 4, 15.34)..cubicTo(4.34, 15.34, 4.61, 15.61, 4.61, 15.95)..close(),
];

/// A disc brake, drawn for the dash: the disc (drilled, its hub and bore
/// open) and the caliper over its top, a gap between them; filled (even-odd),
/// on a 102-unit square centred on 0,0. dash-native draws the same shape.
final kDiscBrake = () {
  const c = Offset(0, 6), a0 = -135 * pi / 180, sweep = 90 * pi / 180; // the caliper: 90° over the top
  Rect at(double r, [Offset o = c]) => Rect.fromCircle(center: o, radius: r);
  Offset on(double r, double a) => c + Offset(cos(a), sin(a)) * r;
  final p = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(at(34)) // the disc
    ..addOval(at(14)) // its centre open
    ..addOval(at(9)) // the hub
    ..addOval(at(3.5)); // its bore
  for (var i = 0; i < 5; i++) {
    p.addOval(at(3, on(24, -pi / 2 + i * 2 * pi / 5))); // the drilled holes
  }
  return p
    ..arcTo(at(50), a0, sweep, true) // the caliper's back, its ends round
    ..arcToPoint(on(38, a0 + sweep), radius: const Radius.circular(6))
    ..arcTo(at(38), a0 + sweep, -sweep, false)
    ..arcToPoint(on(50, a0), radius: const Radius.circular(6))
    ..close();
}();

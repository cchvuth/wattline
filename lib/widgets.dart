// The pieces both layouts in main.dart are built from: the ring's centre,
// the side columns' cards, the buttons and the bottom bar. A part of
// main.dart, so they stay private to it.
part of 'main.dart';

/// Digital speed in the ring's hole, the limit sign above it, the cruise or
/// charge cue below; under them the gear, a tap on it calling [onGear] (the
/// full and basic layouts swap). Without [onGear] no gear: the compact dash
/// has it in its corner.
class _Centre extends StatelessWidget {
  const _Centre({required this.obd, this.onGear, this.gearOnly = false});

  final Panda obd;
  final VoidCallback? onGear;
  final bool gearOnly; // the gear, a little higher, and the cue line: under the [_Speedo]

  @override
  Widget build(BuildContext context) {
    final o = obd;
    // Charging in P: the power going in, where the speed would be.
    final charge = o.wifiLive && o.charging && o.gear == 'P' && o.chargeKw != null;
    final cue = _cue(charge);
    return LayoutBuilder(
        builder: (context, c) => Stack(alignment: Alignment.center, children: [
          if (!gearOnly) ...[
          Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Scaled to the ring's hole, never past it, whatever the digits.
            SizedBox(
              width: c.maxWidth * 0.50,
              height: c.maxHeight * 0.40,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  charge ? o.chargeKw!.round().toString() : o.live ? o.speed.round().toString() : '—',
                  style: TextStyle(
                    fontSize: 200,
                    height: 1,
                    fontWeight: FontWeight.w200,
                    // Dim when there is no data, so the dash reads as a gap.
                    color: charge ? kRegen : o.live ? Colors.white : Colors.white24,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            Text(charge ? 'kW' : o.speedUnit,
                style: const TextStyle(
                    color: Colors.white60, letterSpacing: 3, fontSize: 15)),
          ],
          ),
          ],
          // One short line below, mirroring the limit sign above: the speed
          // stays centred. As wide as the digits, which is also where the
          // ring's arc closes in at that height; longer lines shrink. On the
          // speedometer too: under its raised gear.
          if (cue != null)
            Positioned(
              bottom: gearOnly ? c.maxHeight * 0.03 - 4 : c.maxHeight * 0.17,
              child: SizedBox(
                width: c.maxWidth * 0.5,
                height: c.maxHeight * 0.075,
                child: FittedBox(fit: BoxFit.scaleDown, child: cue),
              ),
            ),
          // The limit above the speed, scaled to the ring; the speed stays
          // centred between the kW readouts.
          if (!gearOnly)
            Positioned(
              top: c.maxHeight * 0.1,
              child: SizedBox.square(
                dimension: c.maxHeight * 0.16,
                child: FittedBox(child: _SpeedLimit(limit: obd.live ? obd.speedLimit : null)),
              ),
            ),
          // Only the gear engaged, in the gap the ring leaves at its foot,
          // clear of the brake's arc there.
          // A finger's room round it to tap; the -8 keeps the letter in place.
          if (onGear != null)
            Positioned(
              bottom: c.maxHeight * (gearOnly ? 0.11 : 0.05) - 8, // a little higher on the speedometer
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  child: Text(o.gear,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: o.live && const {'P', 'R', 'N', 'D'}.contains(o.gear) ? Colors.white : Colors.white38)),
                ),
              ),
            ),
        ]),
      );
  }

  /// The line under the speed: charging, the most the pack takes now and
  /// why; else the cruise set speed and gap while cruise holds one; and the
  /// washer fluid low, amber: on its own in words, beside the cruise cue its
  /// drop alone. (A regen cap shows on the ring itself.)
  Widget? _cue(bool charge) {
    final o = obd, washer = o.wifiLive && o.washerLow;
    const s = TextStyle(fontSize: 15, letterSpacing: 1, fontWeight: FontWeight.w600);
    const drop = GlyphIcon(Glyph.washer, size: 15, color: kWarn);
    if (charge) {
      final max = o.chargeMaxKw, why = o.chargeWhy;
      if (max != null || why != null) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text.rich(TextSpan(children: [
            if (max != null) TextSpan(text: 'MAX ${max.round()}', style: s.copyWith(color: Colors.white70)),
            if (why != null) TextSpan(text: '${max != null ? ' · ' : ''}$why', style: s.copyWith(color: kWarn)),
          ])),
          if (washer) ...[const SizedBox(width: 12), drop],
        ]);
      }
    }
    final set = o.wifiLive ? o.cruiseSet : null;
    if (set != null) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text('SET ${set.round()}', style: s.copyWith(color: kAccent)),
        if (o.followGap case final gap?) ...[
          const SizedBox(width: 10),
          const Icon(Icons.directions_car_filled, size: 16, color: kAccent),
          Text(' $gap', style: s.copyWith(color: kAccent)),
        ],
        if (washer) ...[const SizedBox(width: 12), drop],
      ]);
    }
    if (washer) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        drop,
        const SizedBox(width: 4),
        Text('WASHER LOW', style: s.copyWith(color: kWarn, fontSize: 13)),
      ]);
    }
    return null;
  }
}


/// A vertical pager that opens on [initial] each time it is shown (its
/// controller made per mount, as [_Cards]') and reports the page it settles
/// on: basic's ring.
class _Pages extends StatefulWidget {
  const _Pages({super.key, required this.initial, required this.onPage, required this.children});

  final int initial;
  final ValueChanged<int> onPage;
  final List<Widget> children;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  late final _ctrl = PageController(initialPage: widget.initial.clamp(0, widget.children.length - 1));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  late int _page = _ctrl.initialPage;

  @override
  void didUpdateWidget(_Pages old) {
    super.didUpdateWidget(old);
    // A page set from outside (the saved one, loaded after the first show).
    final p = widget.initial.clamp(0, widget.children.length - 1);
    if (p != _page && _ctrl.hasClients) _ctrl.jumpToPage(_page = p);
  }

  // Clipped, unlike the cards: a face sliding in would cross the bar below
  // and the corners above. A few dp out, as the arcs and the needle's tip
  // reach just past the box. The page reported once settled: a half swipe
  // that springs back changes nothing.
  @override
  Widget build(BuildContext context) => ClipRect(
      clipper: const _Inflated(6),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          final p = _ctrl.page?.round() ?? _page;
          if (p != _page) widget.onPage(_page = p);
          return false;
        },
        child: PageView(
            scrollDirection: Axis.vertical, controller: _ctrl, clipBehavior: Clip.none, children: widget.children),
      ));
}

/// The box, [by] larger all round.
class _Inflated extends CustomClipper<Rect> {
  const _Inflated(this.by);

  final double by;

  @override
  Rect getClip(Size size) => (Offset.zero & size).inflate(by);

  @override
  bool shouldReclip(_Inflated old) => old.by != by;
}

/// The basic layout's other ring face, a gas car's speedometer: one arc over
/// the top, dashed and numbered, a needle trailing a blue glow as it moves, the figure small on the inner
/// left (the needle passes over it), the limit on the inner top right, and the
/// gear where the power ring has it.
class _Speedo extends StatelessWidget {
  const _Speedo({required this.obd, this.onGear});

  final Panda obd;
  final VoidCallback? onGear;

  @override
  Widget build(BuildContext context) {
    final o = obd, top = o.kph ? 250 : 160; // the arc's end: past the car's top speed, km/h or mph
    // Charging in P: the power going in, where the speed would be.
    final charge = o.wifiLive && o.charging && o.gear == 'P' && o.chargeKw != null;
    return LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight), r = RingGauge.radiusIn(side);
      // The last speed even with the link down: the needle hides, not falls.
      final end = (o.speed / top).clamp(0.0, 1.0);
      return Stack(alignment: Alignment.center, children: [
        // The dial a little lower, its arc over the top centred in the box;
        // the gear stays.
        Positioned.fill(
            child: Transform.translate(
                offset: Offset(0, r * 0.15),
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(
                      child: RepaintBoundary(child: CustomPaint(painter: _SpeedoScale(top, major: top > 200 ? 50 : 20)))),
                  // The limit inside the arc's top right, under its numbers.
                  Positioned(
                    left: side / 2 + r * 0.3,
                    top: side / 2 - r * 0.46,
                    child: SizedBox.square(dimension: r * 0.22, child: FittedBox(child: _SpeedLimit(limit: o.live ? o.speedLimit : null))),
                  ),
                  // The speed (or the charge) and its unit inside the arc on the left.
                  Positioned(
                    left: side / 2 - r * 0.62,
                    width: r * 0.42,
                    top: side / 2 - r * 0.04,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        height: r * 0.24,
                        child: FittedBox(
                          child: Text(
                              charge ? o.chargeKw!.round().toString() : o.live ? o.speed.round().toString() : '—',
                              style: TextStyle(
                                  fontSize: 100,
                                  height: 1,
                                  fontWeight: FontWeight.w300,
                                  color: charge ? kRegen : o.live ? Colors.white : Colors.white24,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                        ),
                      ),
                      Text(charge ? 'kW' : o.speedUnit,
                          style: const TextStyle(color: Colors.white60, letterSpacing: 2, fontSize: 11)),
                    ]),
                  ),
                  // Only the needle animates: a little behind the speed, the
                  // trail's glow further back.
                  if (o.live)
                    Positioned.fill(
                      child: RepaintBoundary(child: TweenAnimationBuilder<double>(
                        tween: Tween(end: end),
                        duration: const Duration(milliseconds: 150),
                        builder: (context, f, _) => TweenAnimationBuilder<double>(
                          tween: Tween(end: end),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          builder: (context, lag, _) => CustomPaint(painter: _SpeedoNeedle(f, lag)),
                        ),
                      )),
                    ),
                ]))),
        Positioned.fill(child: _Centre(obd: o, onGear: onGear, gearOnly: true)),
      ]);
    });
  }

  /// The arc, canvas angles (clockwise from the right): 260° about the top,
  /// its ends 40° under the level.
  static const start = 140 * pi / 180, sweep = 260 * pi / 180;
}

/// A basic card, after the S3XY Dash's: the pack's power as a dash round a
/// thin track over the top, filled inside from the top to it (draw clockwise,
/// regen green the other way), the figure in the middle, and the battery as
/// an arc round the range at its foot.
class _PowerDial extends StatelessWidget {
  const _PowerDial({required this.obd});

  final Panda obd;
  static const ends = 300.0; // kW either way: the arc's ends

  @override
  Widget build(BuildContext context) {
    // The pack's own over WiFi (0x132); over Bluetooth alone, the motors'.
    final o = obd,
        raw = (o.wifiLive ? o.packKw : null) ?? (o.live && o.rearKw != null ? (o.frontKw ?? 0) + o.rearKw! : null);
    final kw = raw == null ? null : (raw.abs() < 0.05 ? 0.0 : raw); // never -0.0
    return LayoutBuilder(builder: (context, c) {
      final r = RingGauge.radiusIn(min(c.maxWidth, c.maxHeight));
      return Stack(alignment: Alignment.center, children: [
          // Only the marks animate, on their own layer.
          Positioned.fill(
            child: RepaintBoundary(child: TweenAnimationBuilder<double>(
              tween: Tween(end: ((kw ?? 0) / ends).clamp(-1.0, 1.0)),
              duration: const Duration(milliseconds: 150),
              builder: (context, p, _) =>
                  CustomPaint(painter: _PowerFace(p, o.live ? o.socPct : null, known: kw != null)),
            )),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(kw == null ? '—' : kw.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: r * 0.32,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: kw == null ? Colors.white38 : kw < 0 ? kRegen : Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text('kW', style: TextStyle(fontSize: r * 0.11, color: Colors.white54)),
          ]),
          Positioned(
            bottom: c.maxHeight / 2 - r * 0.86,
            child: Text(!o.live || o.range == null ? '—' : '${o.range!.round()} ${o.rangeUnit}',
                style: TextStyle(
                    fontSize: r * 0.12, color: Colors.white70, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ]);
    });
  }
}

/// [_PowerDial]'s marks: the power's track over the top and its dash from
/// the top ([p] of the way to an end, negative regen), the battery's round the
/// foot, from the left.
class _PowerFace extends CustomPainter {
  _PowerFace(this.p, this.soc, {required this.known});

  final double p;
  final bool known; // a power reading at all: without, no fill and no dash at 0
  final double? soc;
  // The battery's round the foot; the power's either way from the top, to
  // a gap short of it.
  static const _foot = 100 * pi / 180, _gap = 10 * pi / 180, _reach = pi - _foot / 2 - _gap;
  static const _track = 0.035; // both tracks' width, of the radius

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = RingGauge.radiusIn(size.shortestSide);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint line(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    // The power: a white dash round its track from the top, and a fill from
    // the top to it inside the track (green in regen), three quarters its
    // depth.
    final a = -pi / 2 + _reach * p, d = Offset(cos(a), sin(a)), color = p < 0 ? kRegen : kAccent;
    const dash = 0.26, band = dash * 0.75; // of the radius
    canvas.drawArc(rect, -pi / 2 - _reach, 2 * _reach, false, line(Colors.white24, r * _track)); // its track
    if (known && p.abs() > 0.002) {
      // Out over the track, so it hides under the fill.
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * (1 + _track / 2 - band / 2)), -pi / 2, _reach * p, false,
          line(color, r * band)..strokeCap = StrokeCap.butt);
    }
    // The dash square at its inner end, round at the track.
    final tip = c + d * r, foot = c + d * (r * (1 - dash)), drop = const Offset(1.5, 2);
    if (known) {
      canvas
      ..drawLine(tip + drop, foot + drop,
          line(Colors.black87, 5)
            ..strokeCap = StrokeCap.butt
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)) // its shadow
      ..drawLine(tip, foot, line(Colors.white, 3)..strokeCap = StrokeCap.butt)
      ..drawCircle(tip, 1.5, Paint()..color = Colors.white);
    }
    // The battery: from the foot's left, round under the range, to its right.
    const from = pi / 2 + _foot / 2;
    canvas.drawArc(rect, from, -_foot, false, line(Colors.white24, r * _track));
    final f = (soc ?? 0).clamp(0.0, 100.0) / 100;
    if (f > 0) canvas.drawArc(rect, from, -_foot * f, false, line(kAccent, r * _track));
  }

  @override
  bool shouldRepaint(_PowerFace old) => old.p != p || old.soc != soc || old.known != known;
}

/// [_Speedo]'s scale: the arc, a dash every 10 up to [hi], longer and
/// numbered every [major]. Drawn once.
class _SpeedoScale extends CustomPainter {
  _SpeedoScale(this.hi, {required this.major});

  final int hi, major;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = RingGauge.radiusIn(size.shortestSide), w = r * RingGauge.arcWidth;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), _Speedo.start, _Speedo.sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.5
          ..color = Colors.white24);
    final inner = r - w / 2 - 3;
    for (var v = 0; v <= hi; v += 10) {
      final major = v % this.major == 0, a = _Speedo.start + _Speedo.sweep * v / hi, d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * inner, c + d * (inner - r * (major ? 0.09 : 0.045)),
          Paint()
            ..strokeWidth = major ? 2 : 1.2
            ..color = major ? Colors.white70 : Colors.white38);
      if (!major) continue;
      final t = TextPainter(
          text: TextSpan(
              text: '$v', style: TextStyle(fontFamily: kFont, fontSize: r * 0.085, color: Colors.white70)),
          textDirection: TextDirection.ltr)
        ..layout();
      t.paint(canvas, c + d * (inner - r * 0.17) - Offset(t.width / 2, t.height / 2));
      t.dispose();
    }
  }

  @override
  bool shouldRepaint(_SpeedoScale old) => old.hi != hi || old.major != major;
}

/// [_Speedo]'s needle on its hub, shadowed, and while it moves a short blue
/// wedge trailing it (nothing at rest).
class _SpeedoNeedle extends CustomPainter {
  _SpeedoNeedle(this.f, this.lag);

  final double f, lag; // of the arc: now, and where the trail has got to

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = RingGauge.radiusIn(size.shortestSide), w = r * RingGauge.arcWidth;
    final a = _Speedo.start + _Speedo.sweep * f, d = Offset(cos(a), sin(a));
    final rect = Rect.fromCircle(center: c, radius: r);
    // The trail: a short wedge behind the needle, hub to arc, fading to its
    // tail, dimmer as the speed settles and gone once it holds.
    final gap = f - lag;
    if (gap.abs() > 0.002) {
      // Four times the lag: real speeds change a few km/h a second, which
      // the lag alone would leave a sliver.
      // Kept on the scale: none of it under 0 pulling away, or past the top.
      final tail = (gap * 4).clamp(-0.12, 0.12).clamp(f - 1, f), at = _Speedo.start + _Speedo.sweep * (f - tail);
      final span = _Speedo.sweep * tail; // towards the needle: negative slowing down
      final from = min(at, at + span), glow = kAccent.withValues(alpha: 0.45 * min(1.0, tail.abs() / 0.05));
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..arcTo(Rect.fromCircle(center: c, radius: r + w / 2), from, span.abs(), false)
            ..close(),
          Paint()
            ..shader = SweepGradient(
              endAngle: span.abs(),
              colors: span > 0 ? [glow.withValues(alpha: 0), glow] : [glow, glow.withValues(alpha: 0)],
              transform: GradientRotation(from),
              tileMode: TileMode.decal,
            ).createShader(rect));
    }
    final from = c, to = c + d * (r + w / 2); // from the hub, under it
    canvas
      ..drawLine(from + const Offset(1.5, 2), to + const Offset(1.5, 2),
          Paint()
            ..color = Colors.black87
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3))
      ..drawLine(from, to,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round)
      // The hub it turns on: a dark cap, faintly rimmed.
      ..drawCircle(c + const Offset(1.5, 2), r * 0.08,
          Paint()
            ..color = Colors.black87
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3))
      ..drawCircle(c, r * 0.08, Paint()..color = const Color(0xFF2A2A2A))
      ..drawCircle(c, r * 0.08,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.white24);
  }

  @override
  bool shouldRepaint(_SpeedoNeedle old) => old.f != f || old.lag != lag;
}

/// Column beside the ring.
class _SideColumn extends StatelessWidget {
  const _SideColumn({required this.children});

  final List<Widget> children;

  // Shrinks rather than overflows: a large font, or two cards at once.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth, // bounded, for the rows that expand
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in children)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), child: c),
              ],
            ),
          ),
        ),
      );
}

/// The air outside by the ring (ice blue near freezing), centred in a
/// [rowHeight] row so it sits level with what is across the ring; right-
/// aligned, as it sits to the left of the arc. No name: by the ring, a
/// temperature is the air outside.
class _Outside extends StatelessWidget {
  const _Outside({required this.obd, required this.rowHeight});

  final Panda obd;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final c = obd.outsideC;
    return SizedBox(
      height: rowHeight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(c == null ? '—' : _deg(c),
            style: TextStyle(
                fontSize: 16,
                color: _airColor(c),
                fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    );
  }
}

/// The Autopilot icon ([_autopilot]): its glyph on a [disc] of that colour,
/// white on it (dark on amber, which white does not read on), blinking while
/// [flash], [struck] through when locked out. Its words on a long press.
class _ApIcon extends StatefulWidget {
  const _ApIcon({
    required this.disc,
    required this.words,
    this.glyph = Glyph.autopilot,
    this.flash = false,
    this.struck = false,
  });

  static const size = 30.0;

  final Color disc;
  final Glyph glyph;
  final bool flash, struck;
  final String words;

  @override
  State<_ApIcon> createState() => _ApIconState();
}

class _ApIconState extends State<_ApIcon> {
  // A hard blink, 4 frames a second: a fade would redraw at the screen's rate
  // for as long as the nag lasts.
  Timer? _blink;
  bool _dim = false;

  @override
  void initState() {
    super.initState();
    _fit();
  }

  @override
  void didUpdateWidget(_ApIcon old) {
    super.didUpdateWidget(old);
    _fit();
  }

  void _fit() {
    if (widget.flash) {
      _blink ??= Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() => _dim = !_dim));
    } else {
      _blink?.cancel();
      _blink = null;
      _dim = false;
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    const size = _ApIcon.size;
    final mark = w.disc == kWarn ? Colors.black : Colors.white;
    return Tooltip(
      message: w.words,
      child: Opacity(
        opacity: _dim ? 0.2 : 1,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: w.disc),
          // The wheel is drawn to the disc's own size; the gauge smaller.
          child: Stack(alignment: Alignment.center, children: [
            GlyphIcon(w.glyph, size: w.glyph == Glyph.autopilot ? size : size * 0.66, color: mark),
            if (w.struck) CustomPaint(size: const Size.square(size), painter: _Strike(w.disc, mark)),
          ]),
        ),
      ),
    );
  }
}

/// A stroke across the disc, with a gap of the disc's colour each side.
class _Strike extends CustomPainter {
  _Strike(this.disc, this.mark);

  final Color disc, mark;

  @override
  void paint(Canvas canvas, Size s) {
    final a = Offset(s.width * 0.24, s.height * 0.24), b = Offset(s.width * 0.76, s.height * 0.76);
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = s.width * w
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(a, b, line(disc, 0.17))
      ..drawLine(a, b, line(mark, 0.07));
  }

  @override
  bool shouldRepaint(_Strike old) => old.disc != disc || old.mark != mark;
}

/// A card of [_Cards]: [child] laid out at the card's size over [scale] and
/// scaled up by it, so cards of one scale share a text size (a graphic takes
/// the room its text leaves; [_fit] centres fixed-size content); or, with
/// [_Card.fill], a picture built for the card's height at its own size.
class _Card {
  const _Card(Widget this.child, {this.scale = kBasicFigures}) : fill = null;
  const _Card.fill(Widget Function(double height) this.fill) : child = null, scale = 1;

  final Widget? child;
  final Widget Function(double height)? fill;
  final double scale;
}

/// Basic layout's stack of cards beside the ring: one shows, filling the
/// side; a swipe up or down brings the next, and dots at the side say which.
class _Cards extends StatefulWidget {
  const _Cards({super.key, required this.cards, this.initial = 0, this.onPage, this.dotsLeft = false});

  final List<_Card> cards;
  final bool dotsLeft; // the dots on the screen's edge: the left stack's at its left
  final int initial; // the card shown first
  final ValueChanged<int>? onPage;

  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  late int _page = widget.initial.clamp(0, widget.cards.length - 1);
  late final _ctrl = PageController(initialPage: _page);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Room for the dots on their side.
    final pad = widget.dotsLeft ? const EdgeInsets.fromLTRB(14, 6, 8, 6) : const EdgeInsets.fromLTRB(8, 6, 14, 6);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // No card behind, nothing clipped: the car's beams and paths run on
        // past its side.
        child: Stack(clipBehavior: Clip.none, children: [
          PageView(
            controller: _ctrl,
            clipBehavior: Clip.none,
            scrollDirection: Axis.vertical,
            onPageChanged: (p) {
              setState(() => _page = p);
              widget.onPage?.call(p);
            },
            children: [
              for (final c in widget.cards)
                if (c.fill case final fill?)
                  LayoutBuilder(
                      builder: (context, box) =>
                          Padding(padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 0), child: fill(box.maxHeight)))
                else
                  Padding(
                    padding: pad,
                    child: LayoutBuilder(
                      builder: (context, box) => FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(width: box.maxWidth / c.scale, height: box.maxHeight / c.scale, child: c.child),
                      ),
                    ),
                  ),
            ],
          ),
          Positioned(
            left: widget.dotsLeft ? 0 : null,
            right: widget.dotsLeft ? null : 0,
            top: 0,
            bottom: 0,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 6, children: [
              for (var i = 0; i < widget.cards.length; i++)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: i == _page ? Colors.white70 : Colors.white24),
                ),
            ]),
          ),
        ]),
      );
  }
}

/// Fixed-size content centred on a card, shrunk only if it does not fit.
Widget _fit(Widget child) => Center(child: FittedBox(fit: BoxFit.scaleDown, child: child));

/// Basic's car card: the whole car, as tall as the card allows with its
/// beams in view: low going forward, its beams and paths ahead showing (the
/// high beam to the screen's edge, plainly past the low), high in reverse,
/// its paths behind showing; it slides between the two. Never cut off.
class _BasicCar extends StatelessWidget {
  const _BasicCar({required this.obd, required this.height});

  final Panda obd;
  final double height; // the card's

  /// The screen's edge this far over the card's top: beams may reach into it.
  static const above = 6.0;

  @override
  Widget build(BuildContext context) {
    final h = height;
    // Forward: room over it for the beams (the low one ends 0.23 of the car
    // past the nose, the high one fades out by 0.38), the car, and its brake
    // glow under it. Reverse: its paths end on the card.
    const beams = 0.26, glow = 0.02;
    final behind = 1 - _Picture.of(obd.car).pathFrom.$1 + _Picture.pathBehind;
    final car = (h + above) / (beams + 1 + glow);
    final top = obd.gear == 'R' ? h - 2 - behind * car : beams * car - above;
    return Stack(clipBehavior: Clip.none, children: [
      AnimatedPositioned(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        top: top - _Cabin.fillInset(context),
        left: 0,
        right: 0,
        child: Center(child: _Cabin(obd: obd, carHeight: car)),
      ),
    ]);
  }
}

/// The route the car is driving, along the foot of the dash: time to go,
/// arrival time, the route's length and the energy it takes, range at
/// arrival (with what the route takes of the range now) and battery at
/// arrival, each after its icon, and the destination under them; the
/// compact dash has the essentials in one line. Shown while the bus says a
/// route is set, so a finished route never lingers whatever the Commander
/// last pushed; without the bus (no WiFi) it trusts the Commander alone, as
/// the Dash does. Minutes and the battery at arrival come off the bus, else
/// from the Commander; the length and the destination only over Bluetooth,
/// from the car's API through the Commander's own link to the car. Values
/// without data stay hidden.
class _Nav extends StatelessWidget {
  const _Nav({required this.obd, required this.bt, this.oneLine = false, this.tall = false});

  final Panda obd;
  final Commander bt;
  final bool oneLine; // the compact dash: one row under the ring
  final bool tall; // basic's card: the place, then a value a line

  @override
  Widget build(BuildContext context) {
    final o = obd, bus = o.wifiLive; // without WiFi its route values are stale
    // The bus first; its 0 (none, or the last minute) lets the Commander's in.
    final mins = bus && (o.navMinutes ?? 0) > 0 ? o.navMinutes! : bt.navMinutes ?? 0;
    final route = bus && o.frames.containsKey(0x238)
        ? o.navRoute
        : bt.navDest != null || mins > 0;
    if (!route) {
      return tall
          ? const Text('NO ROUTE', style: TextStyle(fontSize: 14, letterSpacing: 2, color: Colors.white38))
          : const SizedBox.shrink();
    }
    final trip = mins > 0; // none yet, or a finished route's zeros
    final m = mins.round();
    // At arrival: the battery % worked out from the bus, else the
    // Commander's (the car's own, once it is linked to the infotainment);
    // the range left from that % and the battery now.
    final pct = trip ? (bus ? o.arrivePct : null) ?? bt.navArrivePct : null;
    final kwh = bus ? o.navEnergyKwh : null;
    final left = trip ? o.rangeAt(pct) : null;
    final dist = left == null ? null : '${left.round()} ${o.rangeUnit}';
    // Beside it, what the route takes of the range now.
    final drop = left == null || o.range == null ? 0 : (o.range! - left).round();
    // The route's own length, which the Commander gives in miles, to a
    // tenth while short as the car's screen does; and the energy it takes.
    final mi = trip ? bt.navMiles : null, len = mi == null ? null : o.kph ? mi * 1.609344 : mi;
    final length = len == null ? null : '${len < 9.95 ? len.toStringAsFixed(1) : len.round()} ${o.rangeUnit}';
    final use = trip ? o.tripKwh(pct) : null;
    final energy = pct != null ? '${pct.round()}%' : kwh != null ? '${kwh.toStringAsFixed(1)} kWh' : null;
    // Lines set tight: with the destination the two still fit the bar's
    // height at the text cap, so the ring keeps its size as a route comes
    // and goes.
    final big = TextStyle(
        fontSize: tall ? 16 : 18, height: 1.1, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]);
    final togo = m < 1 ? '<1 min' : m < 60 ? '$m min' : '${m ~/ 60}h ${m % 60}m';
    // The arrival clock, in the phone's 12 or 24 hour format.
    final clock = TimeOfDay.fromDateTime(
            DateTime.now().add(Duration(seconds: (mins * 60).round())))
        .format(context);
    // Every value after its icon; [note]: a smaller grey figure after it.
    Widget stat(IconData icon, String text, {TextStyle? style, String? note}) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 4),
          Text.rich(
              TextSpan(text: text, children: [
                if (note != null)
                  TextSpan(text: note, style: const TextStyle(fontSize: 14, color: Colors.white54)),
              ]),
              style: style ?? big),
        ]);
    // Beside it, as beside the range, what the route takes of the battery now.
    final used = pct == null || o.socPct == null ? 0 : (o.socPct! - pct).round();
    final battery = energy == null
        ? null
        : stat(Icons.battery_std, energy,
            style: (pct ?? 100) < 10 ? big.copyWith(color: kAlert) : big,
            note: oneLine || used <= 0 ? null : ' −$used');
    // One line, scaled to the width it has, never wrapped.
    final line = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, spacing: oneLine ? 14 : 20, children: [
        if (trip) ...[stat(Icons.hourglass_bottom, togo), stat(Icons.flag, clock)],
        if (!oneLine && length != null) stat(Icons.route, length),
        if (!oneLine && use != null) stat(Icons.bolt, '${use.toStringAsFixed(1)} kWh'),
        if (dist != null) stat(Icons.electric_car, dist, note: oneLine || drop <= 0 ? null : ' −$drop'),
        ?battery,
      ]),
    );
    // On a light grey card, set apart from the link icons and buttons.
    // As much room above and below as the bar allows: the place's line
    // under the name takes most of it.
    Widget card(Widget child) => Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: bt.navDest == null ? 3 : 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
    // Nothing to put on the line yet (the route's fields come round slowly).
    final blank = !trip && dist == null && energy == null && (oneLine || length == null);
    if (oneLine) return blank ? const SizedBox.shrink() : card(line);
    if (tall) {
      // As wide as its card lets it (the name wraps there, never shrinking
      // the rest), and no wider than this.
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
          if (bt.navDest case final dest?)
            Text(dest, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, color: Colors.white))
          else
            const Text('DESTINATION', style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: Colors.white70)),
          if (trip) ...[stat(Icons.hourglass_bottom, togo), stat(Icons.flag, clock)],
          if (length != null) stat(Icons.route, length),
          if (dist != null) stat(Icons.electric_car, dist, note: drop <= 0 ? null : ' −$drop'),
          ?battery,
        ]),
      );
    }
    return card(Column(mainAxisSize: MainAxisSize.min, children: [
      // Its name, top centre, with the place beside it once Bluetooth has
      // one: two lines at most, so the bar grows no taller.
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('DESTINATION', style: TextStyle(fontSize: 10, height: 1.2, letterSpacing: 1.5, color: Colors.white70)),
        if (bt.navDest case final dest?) ...[
          const SizedBox(width: 10),
          const Icon(Icons.place, size: 15, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(dest,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, height: 1.1, color: Colors.white)),
          ),
        ],
      ]),
      if (!blank) line,
    ]));
  }
}

enum _Side { left, right, bottom }

/// A soft coloured glow along one screen edge.
class _Edge extends StatelessWidget {
  const _Edge({required this.side, required this.color});

  final _Side side;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final horizontal = side != _Side.bottom;
    return IgnorePointer(
      child: Align(
        alignment: switch (side) {
          _Side.left => Alignment.centerLeft,
          _Side.right => Alignment.centerRight,
          _Side.bottom => Alignment.bottomCenter,
        },
        child: Container(
          width: horizontal ? 70 : double.infinity,
          height: horizontal ? double.infinity : 45,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: switch (side) {
                _Side.left => Alignment.centerLeft,
                _Side.right => Alignment.centerRight,
                _Side.bottom => Alignment.bottomCenter,
              },
              end: switch (side) {
                _Side.left => Alignment.centerRight,
                _Side.right => Alignment.centerLeft,
                _Side.bottom => Alignment.topCenter,
              },
              colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bar along the bottom: the link icons on the left, the route, Google
/// Maps and the car panel on the right.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.obd,
    required this.bt,
    required this.onWifi,
    required this.onBt,
    required this.onMaps,
    this.nav = true,
  });

  final Panda obd;
  final Commander bt;
  final VoidCallback onWifi, onBt, onMaps;
  final bool nav; // the route in the bar (basic has it on a card)

  @override
  Widget build(BuildContext context) {
    // Each link's state at a glance: a word under its icon, and the seconds
    // left while a timer runs. The words tooltips and snackbars spell out.
    final (wIcon, wColor, wWord) = switch (obd.link) {
      WifiLink.idle => (Icons.wifi_off, Colors.white54, 'IDLE'),
      WifiLink.wifiOff => (Icons.wifi_off, kAlert, 'OFF'),
      WifiLink.scanning => (Icons.wifi_find, kAccent, 'SCAN'),
      WifiLink.joining => (Icons.wifi_find, kAccent, 'JOIN'),
      WifiLink.hello => (Icons.wifi, kAccent, 'HELLO'),
      WifiLink.live => (Icons.wifi, kRegen, 'LIVE'),
      WifiLink.quiet => (Icons.wifi, kWarn, 'QUIET'),
      WifiLink.away => (Icons.wifi_off, Colors.white54, 'AWAY'),
      WifiLink.retrying => (Icons.wifi_find, kWarn, 'RETRY'),
    };
    final (bIcon, bColor, bWord) = switch (bt.link) {
      BtLink.idle => (Icons.bluetooth_disabled, Colors.white54, 'IDLE'),
      BtLink.off => (Icons.bluetooth_disabled, kAlert, 'OFF'),
      BtLink.noLocation => (Icons.location_off, kAlert, 'NO LOC'),
      BtLink.scanning => (Icons.bluetooth_searching, kAccent, 'SCAN'),
      BtLink.linking => (Icons.bluetooth_searching, kAccent, 'LINK'),
      BtLink.approving => (Icons.touch_app, kWarn, 'PRESS'),
      BtLink.refused => (Icons.bluetooth_disabled, kAlert, 'DENIED'),
      // Left to the S3XY Dash on purpose: plain and grey, not a fault.
      BtLink.dash => (Icons.bluetooth, Colors.white54, 'DASH'),
      BtLink.paused => (Icons.pause_circle_outline, kWarn, 'WAIT'),
      BtLink.away => (Icons.bluetooth_searching, Colors.white54, 'AWAY'),
      BtLink.held => (Icons.app_blocking, kAlert, 'HELD'),
      BtLink.retrying => (Icons.bluetooth_searching, kWarn, 'RETRY'),
      BtLink.borrowed => (Icons.bluetooth_connected, kAccent, 'BORROW'),
      BtLink.buttons => (Icons.bluetooth_connected, kAccent, 'ACTION'),
      BtLink.lean => (Icons.bluetooth_connected, kRegen, 'READY'),
      BtLink.full => (Icons.bluetooth_connected, kRegen, 'LIVE'),
    };
    // Settled (WiFi live; Bluetooth ready with its car data), a link shrinks
    // to its icon and leaves the route the room; anything else stands out.
    return Row(children: [
        _LinkButton(
            icon: wIcon, color: wColor, word: wWord, until: obd.until,
            settled: obd.link == WifiLink.live,
            // Live, the speed frames a second: the screen redraws up to 45 a
            // second, so under ~36 the dash waits on the Commander (the car
            // sends about 50).
            stat: obd.link == WifiLink.live && obd.speedKnown ? '${obd.speedHz}' : null,
            statColor: obd.speedHz >= 36 ? Colors.white : obd.speedHz >= 18 ? kWarn : kAlert,
            tip: obd.link == WifiLink.live
                ? 'WiFi: live, ${obd.speedHz} speed frames/s (the car sends about 50), ${obd.frameHz} frames/s in all'
                : 'WiFi: ${obd.status}',
            onTap: onWifi),
        _LinkButton(
            icon: bIcon, color: bColor, word: bWord, until: bt.until,
            settled: bt.link == BtLink.lean || bt.link == BtLink.full,
            tip: 'Commander: ${bt.status}', onTap: onBt),
        // Charging takes the route's place, as in the compact dash.
        Expanded(child: !nav || obd.wifiLive && obd.charging ? const SizedBox() : _Nav(obd: obd, bt: bt)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.map_outlined, color: Colors.white),
          tooltip: 'Google Maps beside the dash',
          onPressed: onMaps,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          // The car panel: locks, honk, flash, climate.
          icon: const Icon(Icons.directions_car_outlined, color: Colors.white),
          tooltip: 'Car controls',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CarPanel(bt: bt)),
          ),
        ),
      ]);
  }
}

/// A link's button in the bottom bar: its icon over a word for its state.
/// While a timer runs, a ring round the icon drains to the deadline and the
/// seconds left stand beside it. A big target, for a finger in a moving car;
/// [settled], just a small icon (still the bar's height to tap).
class _LinkButton extends StatefulWidget {
  const _LinkButton({
    required this.icon,
    required this.color,
    required this.word,
    required this.until,
    required this.settled,
    required this.tip,
    required this.onTap,
    this.stat,
    this.statColor = Colors.white,
  });

  /// A small figure under a settled icon.
  final String? stat;
  final Color statColor;
  final IconData icon;
  final Color color;
  final String word, tip;
  final DateTime? until;
  final bool settled;
  final VoidCallback onTap;

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  late final Timer _tick;
  // When this deadline first showed: the ring's full turn.
  DateTime _from = DateTime.now();

  @override
  void initState() {
    super.initState();
    // The countdown moves on its own: the links notify only when they
    // change. Four times a second, so the ring drains smoothly.
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (widget.until != null) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_LinkButton old) {
    super.didUpdateWidget(old);
    if (widget.until != old.until) _from = DateTime.now();
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = widget.until, now = DateTime.now();
    final left = until?.difference(now) ?? Duration.zero;
    final secs = (left.inMilliseconds / 1000).ceil();
    final span = until?.difference(_from).inMilliseconds ?? 0;
    final c = widget.color;
    return Tooltip(
      message: widget.tip,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          width: widget.settled ? 36 : 60,
          height: 44,
          child: widget.settled
              // On the big buttons' icon line (its word below), not the
              // bar's middle, so a small and a big one line up.
              ? Align(
                  alignment: const Alignment(0, -0.5),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(widget.icon, size: 18, color: c),
                    if (widget.stat case final s?)
                      Text(s,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: widget.statColor,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                  ]))
              // Scaled while the button grows back, so it never spills.
              : FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // The icon keeps one place whatever the state: a 28 dp spot at
            // the button's middle, the ring round it while a timer runs and
            // the seconds hung beside it, two digits' room, moving nothing.
            SizedBox(
              width: 60,
              height: 28,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.square(
                  dimension: 28,
                  child: CustomPaint(
                    painter: secs > 0
                        ? _RingPainter(span <= 0 ? 0 : (left.inMilliseconds / span).clamp(0.0, 1.0), c)
                        : null,
                    child: Center(child: Icon(widget.icon, size: secs > 0 ? 16 : 22, color: c)),
                  ),
                ),
                if (secs > 0)
                  Positioned(
                    left: 45,
                    width: 15,
                    top: 0,
                    bottom: 0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('$secs',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: c,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(widget.word,
                  style: TextStyle(fontSize: 10, height: 1.1, letterSpacing: 0.5, color: c)),
            ),
          ])),
        ),
      ),
    );
  }
}

/// A countdown round a link's icon: a faint track, and over it what is
/// left, from the top clockwise.
class _RingPainter extends CustomPainter {
  _RingPainter(this.left, this.color);

  final double left; // 1 at the start, 0 at the deadline
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawOval(rect, stroke(color.withValues(alpha: 0.18), 2));
    canvas.drawArc(rect, -pi / 2, 2 * pi * left, false, stroke(color, 2.5));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.left != left || old.color != color;
}

/// S3XY functions, pressed over Bluetooth. Lit from the state the bus already
/// reports over WiFi; dim while they cannot be pressed. Half down each side
/// of the screen ([right] the right-hand one), each door on its own side.
class _Actions extends StatelessWidget {
  const _Actions({required this.obd, required this.bt, required this.onTap, this.right = false});

  final Panda obd;
  final Commander bt;
  final void Function(S3xyAction) onTap;
  final bool right;


  @override
  Widget build(BuildContext context) {
    final o = obd;
    // White when off, solid light blue when on: both read in sunlight. A
    // button that cannot act right now looks the same; a tap says why.
    // Icons only, each the car's own; the name shows on a long press. A
    // stalled link lights nothing; a state only WiFi has, nothing without it.
    // [note]: a figure under the icon, inside the chip's own size. [level]
    // 1 amber, 2 red: the figure, or on a lit chip the chip itself (dark
    // digits on its light fill would read as muted).
    Widget chip(S3xyAction a, Glyph icon, String label, bool lit,
        {bool wifiOnly = false, String? note, int level = 0}) {
      lit = lit && (wifiOnly ? o.wifiLive : o.live);
      final fill = switch (level) { 2 => kAlert, 1 => kWarn, _ => kLit };
      final color = lit && level < 2 ? Colors.black : Colors.white;
      final noteColor = lit ? color : switch (level) { 2 => kAlert, 1 => kWarn, _ => color };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onTap(a),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 42,
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: lit ? fill : null,
                border: Border.all(color: lit ? fill : Colors.white70),
              ),
              child: note == null
                  ? GlyphIcon(icon, size: 24, color: color)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      GlyphIcon(icon, size: 22, color: color),
                      // Four digits in the chip's width, whatever the font.
                      SizedBox(
                        width: 26,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(note,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.1,
                                  color: noteColor,
                                  fontFeatures: const [FontFeature.tabularFigures()])),
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      );
    }

    // The cabin's CO2 on the recirculation chip, the button that changes
    // it: amber when a full car makes it stuffy, red when it makes it
    // drowsy. ponytail: fixed bands; tune from a log with a full car.
    final co2 = o.wifiLive ? o.co2ppm : null;
    final co2Level = co2 == null ? 0 : co2 >= 2500 ? 2 : co2 >= 1500 ? 1 : 0;
    // Once a figure has come, its slot stays, blank through a WiFi stall.
    final co2Note = o.co2ppm == null ? null : '${co2 ?? ''}';
    return Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      if (!right) ...[
        chip(S3xyAction.trunk, Glyph.trunk, 'Trunk', o.trunk),
        // Outside R: the screen's Mirror Auto Tilt (0x273), which a tilt
        // press overrides in R. In R: whether the mirrors are dipped (0x102),
        // so the override shows.
        chip(S3xyAction.mirrorTilt, Glyph.mirrorTilt, 'Mirror tilt',
            o.gear == 'R' ? o.mirrorDipped : o.tiltAuto,
            wifiOnly: true),
        // Lit while that door is open (latches from 0x102/0x103). Locks,
        // honk and flash live in the car controls.
        chip(S3xyAction.doorFrontLeft, Glyph.doorFL, 'Front left door', o.doorFL),
        chip(S3xyAction.doorRearLeft, Glyph.doorRL, 'Rear left door', o.doorRL),
        // Lit while the charge port door is open (CP_status).
        chip(S3xyAction.chargePort, Glyph.chargePort, 'Charge port', o.chargePort,
            wifiOnly: true),
      ] else ...[
        chip(S3xyAction.frunk, Glyph.frunk, 'Frunk', o.frunk),
        // Lit while most of the air is recirculated (the HVAC controller,
        // 0x243); without that frame the Commander's Bluetooth reading
        // stands in. A press always toggles.
        if (o.wifiLive && o.frames.containsKey(0x243))
          chip(S3xyAction.recircToggle, Glyph.recirc, 'Recirculation', o.hvacOn && o.recircOn,
              note: co2Note, level: co2Level)
        else
          // Bluetooth's own value, cleared when that link drops. Its low
          // bits are the mode; the top bit is set while a Commander press
          // holds it.
          chip(S3xyAction.recircToggle, Glyph.recirc, 'Recirculation',
              ((bt.recircMode ?? 0) & 0x7F) == 1,
              note: co2Note, level: co2Level),
        chip(S3xyAction.doorFrontRight, Glyph.doorFR, 'Front right door', o.doorFR),
        chip(S3xyAction.doorRearRight, Glyph.doorRR, 'Rear right door', o.doorRR),
        // Lit while the screen's dome light is on or any map light is: the
        // lamps the S3XY Interior Lights press switches on.
        chip(S3xyAction.interiorLights, Glyph.interiorLight, 'Interior lights',
            o.domeLight == 'ON' || o.mapLight,
            wifiOnly: true),
      ],
    ]);
  }
}

/// The battery as a small dial, the speed ring in miniature: an arc round
/// 270°, empty at the left of its foot and full at the right, filled to the
/// charge (red below 20 %), the % in its hole and the range in the open
/// foot, where the ring has the gear. Over the %, a bolt while charging (the
/// arc dim green on to the limit) and the pack's coldest cells: ice blue
/// with the car's snowflake while too cold for full regen and power, a red
/// up arrow while it heats, and the target a preconditioning heats it to.
class _Battery extends StatelessWidget {
  const _Battery({required this.obd, this.width = 128});

  final Panda obd;
  final double width; // shown this wide, drawn at 104 x 98

  @override
  Widget build(BuildContext context) {
    final o = obd, pct = o.socPct, range = o.range;
    final color = (pct ?? 100) < 20 ? kAlert : kRegen;
    final charging = o.wifiLive && o.charging, t = o.packTempC, cold = (t ?? 99) <= 10;
    final heating = o.packHeating || o.precondC != null;
    return SizedBox(
      width: width,
      height: width * 98 / 104,
      child: FittedBox(child: SizedBox(
      width: 104,
      height: 98,
      child: CustomPaint(
        painter: _DialPainter(((pct ?? 0).clamp(0, 100) / 100).toDouble(), color,
            limit: charging ? o.chargeLimitPct : null),
        child: Stack(alignment: Alignment.topCenter, children: [
          if (charging || t != null)
            Positioned(
              top: 15,
              width: 66,
              height: 19,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, spacing: 1, children: [
                  if (charging) const Icon(Icons.bolt, size: 17, color: kRegen),
                  if (cold) const Icon(Icons.ac_unit, size: 14, color: kCold),
                  if (t != null)
                    Text.rich(
                        TextSpan(text: '${t.abs() < 10 ? (t.abs() < 0.05 ? 0.0 : t).toStringAsFixed(1) : t.round()}°', children: [
                          if (o.precondC case final to?)
                            TextSpan(text: ' → ${_deg(to)}', style: const TextStyle(color: kWarn)),
                        ]),
                        style: TextStyle(
                            fontSize: 14,
                            color: cold ? kCold : Colors.white70,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  if (heating) const Icon(Icons.arrow_upward, size: 14, color: kAlert),
                ]),
              ),
            ),
          // The figures shrink rather than reach the arc, whatever the font.
          Positioned(
            top: 34,
            width: 76,
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                  TextSpan(text: pct == null ? '—' : '${pct.round()}', children: [
                    if (pct != null) const TextSpan(text: '%', style: TextStyle(fontSize: 16)),
                  ]),
                  style: TextStyle(
                      fontSize: 28,
                      // Dim without a reading, so the dial reads as a gap.
                      color: pct == null ? Colors.white38 : color == kAlert ? kAlert : Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ),
          if (range != null)
            Positioned(
              bottom: 0,
              width: 60,
              height: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('${range.round()} ${o.rangeUnit}',
                    style: const TextStyle(fontSize: 15, color: Colors.white70)),
              ),
            ),
        ]),
      ),
    )));
  }
}

/// The dial's arc in the box's top square: a hairline track, open at the
/// foot, and over it the fill, clockwise from the left end to [fraction];
/// [limit], a charge limit %, dim on to it.
class _DialPainter extends CustomPainter {
  _DialPainter(this.fraction, this.color, {this.limit});

  final double fraction;
  final Color color;
  final int? limit;

  // Canvas angles: 0 = right, clockwise; from the bottom left over the top.
  static const _start = 0.75 * pi, _sweep = 1.5 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.width / 2), r = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    canvas.drawArc(rect, _start, _sweep, false, stroke(Colors.white24, 1.5));
    if (fraction > 0) canvas.drawArc(rect, _start, _sweep * fraction, false, stroke(color, 6));
    // What is still to go in, a dim green on to the limit, after a red fill
    // too; solid, so the track does not show through. (The signal reaches
    // 102 %: never past the arc's end.)
    if (limit case final l? when l / 100 > fraction) {
      canvas.drawArc(rect, _start + _sweep * fraction, _sweep * (min(l, 100) / 100 - fraction), false,
          stroke(Color.alphaBlend(kRegen.withValues(alpha: 0.3), Colors.black), 6));
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.color != color || old.limit != limit;
}

/// The g-meter, as Track Mode draws it: the dot where the force pushes the
/// driver (up braking, down speeding up, right in a left turn), its figure
/// beside it and this drive's peak under that. WiFi only.
class _GBall extends StatefulWidget {
  const _GBall({required this.obd, this.dial, this.listen = true});

  final Panda obd;
  final bool listen; // hidden, it holds its place without redrawing
  /// Basic's card: in a [dial] square, its circle the power dial's
  /// ([RingGauge.radiusIn]), the figures under the square.
  final double? dial;

  @override
  State<_GBall> createState() => _GBallState();
}

class _GBallState extends State<_GBall> {
  // The last few dots, oldest first: about a fifth of a second at the
  // fast tick's 45 a second. Still, they gather under the dot.
  final _trail = <Offset>[];

  // Redrawn on the fast tick, on its own layer: the rest of the page stays.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
      child: widget.listen ? ListenableBuilder(listenable: widget.obd.fast, builder: (context, _) => _ball()) : _ball());

  Widget _ball() {
    final o = widget.obd, g = Offset(o.gLat ?? 0, o.gLong ?? 0);
    _trail.add(g);
    if (_trail.length > 10) _trail.removeAt(0);
    final peak = max(o.gMaxBrake, max(o.gMaxAccel, o.gMaxLat));
    final ball = CustomPaint(painter: _GPainter(List.of(_trail), (o.gMaxBrake, o.gMaxAccel, o.gMaxLat)));
    final figures = [
        Text.rich(
            TextSpan(text: g.distance.toStringAsFixed(2), children: const [
              TextSpan(text: ' g', style: TextStyle(fontSize: 14, color: Colors.white70)),
            ]),
            style: const TextStyle(
                fontSize: 20, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()])),
        Text('PEAK ${peak.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, letterSpacing: 0.8, color: Colors.white70)),
    ];
    if (widget.dial case final side?) {
      return SizedBox.square(
        dimension: side,
        child: Stack(clipBehavior: Clip.none, children: [
          // The painter's circle is 1 in from its box: 6 in all, as the dial's.
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(5), child: ball)),
          Positioned(
            top: side + 6,
            left: -40,
            right: -40,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic, spacing: 12, children: figures),
          ),
        ]),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox.square(dimension: 72, child: ball),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: figures),
    ]);
  }
}

/// Rings at 0.5 and 1 g on a crosshair; inside them, in blue, how far this
/// drive has reached each way; the trail fading in to the dot, held at the
/// 1 g ring past it.
class _GPainter extends CustomPainter {
  _GPainter(this.trail, this.peaks);

  final List<Offset> trail; // g across, g along; the last one is now
  final (double, double, double) peaks; // brake, accel, across

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2 - 1;
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), stroke(Colors.white12, 1));
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), stroke(Colors.white12, 1));
    canvas.drawCircle(c, r / 2, stroke(Colors.white12, 1));
    canvas.drawCircle(c, r, stroke(Colors.white24, max(1.5, r * _PowerFace._track))); // as the power card's track, basic
    // The reach: a quarter ellipse between each pair of peaks.
    final (b, a, l) = (peaks.$1.clamp(0, 1) * r, peaks.$2.clamp(0, 1) * r, peaks.$3.clamp(0, 1) * r);
    if (a + b + l > 0) {
      const w = 0.7071; // a conic's weight for a quarter ellipse
      final p = Path()
        ..moveTo(c.dx, c.dy - b)
        ..conicTo(c.dx + l, c.dy - b, c.dx + l, c.dy, w)
        ..conicTo(c.dx + l, c.dy + a, c.dx, c.dy + a, w)
        ..conicTo(c.dx - l, c.dy + a, c.dx - l, c.dy, w)
        ..conicTo(c.dx - l, c.dy - b, c.dx, c.dy - b, w)
        ..close();
      canvas.drawPath(p, Paint()..color = kAccent.withValues(alpha: 0.4));
    }
    Offset at(Offset g) => c + (g.distance > 1 ? g / g.distance : g) * r;
    // The dot and trail grow with the meter (basic's is the room's size),
    // never under the full layout's 72 dp one's.
    final k = max(1.0, r / 35);
    for (var i = 1; i < trail.length; i++) {
      canvas.drawLine(at(trail[i - 1]), at(trail[i]),
          stroke(Colors.white.withValues(alpha: 0.7 * i / trail.length), 2 * k)..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(at(trail.last), 5 * k, Paint()..color = Colors.black);
    canvas.drawCircle(at(trail.last), 4 * k, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GPainter old) => !listEquals(old.trail, trail) || old.peaks != peaks;
}

/// A label and its value, the labels one width so the values line up.
Widget _statRow(BuildContext context, String label, String value, {Color color = Colors.white}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: MediaQuery.textScalerOf(context).scale(104), // aligns the values
        child: Text(label,
            maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12, letterSpacing: 0.8, color: Colors.white70)),
      ),
      Text(value, style: TextStyle(fontSize: 16, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

/// The battery's health: the spread between the strongest and weakest cell
/// group ([minor]: the full layout hides it unless switched on), and how far
/// full-pack energy has fallen from the BMS's figure for it new.
class _Pack extends StatelessWidget {
  const _Pack({required this.obd, this.minor = true});

  final Panda obd;
  final bool minor;

  @override
  Widget build(BuildContext context) {
    final o = obd, mv = o.imbalanceMv, kwh = o.packKwh, isNew = o.packNewKwh;
    // Shrinks rather than overflows when a large font meets a wide ring.
    return FittedBox(fit: BoxFit.scaleDown, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (minor) _statRow(context, 'IMBALANCE', mv == null ? '—' : '${mv.round()} mV'),
      _statRow(context, 'DEGRADATION',
          kwh == null || isNew == null ? '—' : '${((1 - kwh / isNew) * 100).clamp(0, 100).toStringAsFixed(1)} %'),
    ]));
  }
}

/// A temperature in whole degrees, the degree sign against the number.
String _deg(double c) => '${c.round()}°';

/// The air outside's colour: ice blue from +3 °C down, where bridges freeze first.
Color _airColor(double? c, [Color other = Colors.white]) => c != null && c.round() <= 3 ? kCold : other;

/// European-style sign; blank while the car reports no limit.
class _SpeedLimit extends StatelessWidget {
  const _SpeedLimit({required this.limit});

  final double? limit;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: limit == null ? Colors.white10 : Colors.white,
          border: Border.all(
            color: limit == null ? Colors.white24 : const Color(0xFFE23D3D),
            width: 5,
          ),
        ),
        child: Text(
          limit == null ? '—' : limit!.round().toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: limit == null ? Colors.white24 : Colors.black,
          ),
        ),
      );
}

/// The lights on, each only while it is: DRL for the front light bar (DRL by
/// day, the position lamp at night), LOW and HIGH, from VCFRONT_lighting;
/// HIGH also from the lamps themselves. Green as the car's own indicators,
/// HIGH blue. Then GRIP while it has something to say, coloured by the road:
/// amber while traction or stability control steps in, ice blue while the
/// car judges the road slippery, both only while moving ([Panda.gripLit]);
/// Slip Start or Off-Road Assist left on names itself (amber on a dry road).
/// GRIP is WiFi only.
class _Lights extends StatelessWidget {
  const _Lights({required this.obd});

  final Panda obd;

  @override
  Widget build(BuildContext context) {
    final o = obd;
    Widget lamp(String label, Glyph icon, [Color lit = kRegen]) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(children: [
            GlyphIcon(icon, size: 20, color: lit),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, letterSpacing: 1, color: lit)),
          ]),
        );
    final grip = o.wifiLive && o.frames.containsKey(0x2B6) && (o.gripLit || o.tcMode != null);
    // Four lamps where three fitted: shrinks rather than overflows.
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
      // Not after the link: a stall would leave them lit.
      if (o.live && o.drl == true) lamp('DRL', Glyph.drl),
      if (o.live && o.lowBeam == true) lamp('LOW', Glyph.lowBeam),
      if (o.live && o.highBeam == true) lamp('HIGH', Glyph.highBeam, kAccent),
      if (grip) lamp(o.tcMode ?? 'GRIP', Glyph.grip, o.gripLit && !o.gripHeld ? kCold : kWarn),
    ]));
  }
}

/// An indicator lamp on a picture: its points as (along, out from the
/// picture's centre line), the same both sides, and how thick (1 the bars',
/// a repeater thinner).
final class _Turn {
  const _Turn(this.points, {this.k = 1});

  final List<(double, double)> points;
  final double k;
}

/// A body's picture and where things are on it: shares of the picture's
/// width and length. The Model Y's two (5 and 7 seats) are the same car at
/// the same size and place, so they share one set. What a car is lives in
/// [Car]; this is only how it is drawn. Its folder holds `car.png` (lamps
/// off, seats dark) and a `seat_<name>.png` mask for each of the car's
/// seats ([Car.seatNames]), the seat as a white one, to take the belt's colour.
final class _Picture {
  const _Picture({
    required this.dir,
    required this.aspect,
    required this.rows,
    required this.axles,
    required this.tyreL,
    required this.tyreR,
    required this.tyreW,
    required this.pillL,
    required this.pillW,
    required this.centre,
    required this.nose,
    required this.tail,
    required this.pathFrom,
    required this.turns,
    this.corners,
  }) : tailParabola = false;

  final String dir;
  final double aspect;

  /// Each seat row's centre along the length, front first (the last the
  /// third row, or the boot).
  final List<double> rows;

  /// The axles, front and rear.
  final List<double> axles;

  /// The tyre figures: in from each side (the mirrors make the picture
  /// wider than the body, and not evenly), and as wide.
  final double tyreL, tyreR, tyreW;

  /// The rows' pills, centred on the seats.
  final double pillL, pillW;

  /// The body's centre line, across the width (the mirrors make the picture
  /// uneven, the body is not).
  final double centre;

  /// The outline of the nose and of the tail, from the tip back, as (along,
  /// half the body's width there), the same both sides: the Y's light bars
  /// sit on them; the beams start at the nose's tip.
  final List<(double, double)> nose, tail;

  /// The tail's outline is a parabola, near enough (the Y's): its bar is
  /// drawn as one through [tail]'s tip and ends, the smoothest there is.
  /// Otherwise through every point of [tail].
  final bool tailParabola;

  /// Light bars (no [corners]): the front one a strip of the picture, lit
  /// from a `drl.png` mask beside its seats' and `drl_glow.png` round it
  /// (the L's cut from its picture; the Y's, the same front, fitted onto its
  /// own); no bar is drawn on [nose], which the beams start from.
  bool get drlStrip => corners == null;

  /// Where the path lines start: just outside the mirror tips, the car's
  /// widest points, whose paths bound the space it sweeps.
  final (double, double) pathFrom;

  /// How far the path lines run, of the car's length: ahead, and behind in R.
  static const pathAhead = 0.7, pathBehind = 0.53;

  /// The turn signals ([_Turn]); with light bars, the tail bar's own ends too.
  final List<_Turn> turns;

  /// Lamps apart at each corner, one side's, from the inner end out: the
  /// 3's DRL strips and tail lamps, each glowing from the lamp. Null: bars
  /// across the nose and tail on their outlines (the Y's).
  final ({List<(double, double)> head, List<(double, double)> tail})? corners;

  /// Each car's: every body has one, or this does not compile.
  static _Picture of(Car car) => switch (car.model) {
        Model.y => car.thirdRow ? y7 : y5,
        Model.yL => yL,
        Model.three => three,
      };

  const _Picture._y(this.dir)
      : aspect = 257 / 570,
        rows = const [0.494, 0.66, 0.804],
        axles = const [0.205, 0.80],
        tyreL = 0.10,
        tyreR = 0.068,
        tyreW = 0.21,
        pillL = 0.213,
        pillW = 0.62,
        centre = 0.5155,
        // The silhouette's edge, traced and smoothed, a little inside it,
        // round the nose: where the beams start. Its light bar is the L's
        // (the same front), fitted onto this picture's nose.
        nose = const [
          (0.0299, 0.000), (0.0301, 0.035), (0.0304, 0.068), (0.0315, 0.100), (0.0333, 0.132), (0.0351, 0.165),
          (0.0377, 0.197), (0.0418, 0.228), (0.0481, 0.257), (0.0558, 0.285), (0.0641, 0.311), (0.0736, 0.336),
          (0.0840, 0.359), (0.0956, 0.379), (0.1084, 0.395), (0.1223, 0.405),
        ],
        // Just outside its outline (the wider side of both pictures, so it
        // hugs either evenly), flat across the bumper's middle; corner to
        // corner across the hatch, not up the sides.
        tail = const [
          (0.9635, 0.0), (0.9635, 0.05), (0.9595, 0.105), (0.956, 0.138), (0.9525, 0.163), (0.949, 0.186),
          (0.9455, 0.208), (0.9405, 0.222), (0.9368, 0.238), (0.9333, 0.249), (0.9298, 0.269), (0.9263, 0.280),
        ],
        pathFrom = const (0.355, 0.495),
        // On the light bar's lower end down each side, and by the wing's
        // camera (thin, short).
        turns = const [
          _Turn([(0.0880, 0.353), (0.0954, 0.365), (0.1028, 0.371), (0.1101, 0.377), (0.1175, 0.380)]),
          _Turn([(0.259, 0.404), (0.273, 0.401)], k: 0.83),
        ],
        tailParabola = true,
        corners = null;

  static const y5 = _Picture._y('assets/car5');
  static const y7 = _Picture._y('assets/car');

  /// The Model Y L's: its front light bar the strip its picture shows; the
  /// tail's drawn as the Y's, following every point of its outline (no
  /// parabola), just outside the body. The third row is where the Y's boot is.
  static const yL = _Picture(
    dir: 'assets/carL',
    aspect: 282 / 680,
    rows: [0.4675, 0.6363, 0.7775],
    axles: [0.198, 0.771],
    tyreL: 0.071, tyreR: 0.069, tyreW: 0.216,
    pillL: 0.181, pillW: 0.639,
    centre: 0.5009,
    // The silhouette's edge, traced and smoothed, a little inside it, round
    // the nose: where the beams start (its light bar is the picture's own).
    nose: [
      (0.0278, 0.000), (0.0278, 0.038), (0.0285, 0.073), (0.0295, 0.109), (0.0309, 0.144), (0.0329, 0.179),
      (0.0353, 0.214), (0.0397, 0.248), (0.0465, 0.279), (0.0551, 0.307), (0.0646, 0.335), (0.0741, 0.361),
      (0.0842, 0.387), (0.0961, 0.408), (0.1097, 0.421), (0.1241, 0.427),
    ],
    tail: [
      (0.9657, 0.0), (0.9651, 0.050), (0.9637, 0.082), (0.9615, 0.112), (0.9587, 0.143), (0.9545, 0.181),
      (0.9478, 0.219), (0.9398, 0.246), (0.9296, 0.273), (0.9236, 0.293),
    ],
    pathFrom: (0.3425, 0.495),
    // Its front indicator: on the strip's lower end, down each side.
    turns: [
      _Turn([(0.0840, 0.369), (0.0911, 0.381), (0.0982, 0.388), (0.1052, 0.394), (0.1123, 0.397)]),
      _Turn([(0.2475, 0.425), (0.2575, 0.424)], k: 0.83),
    ],
  );

  static const _head3 = [(0.0692, 0.2647), (0.0806, 0.3103), (0.0889, 0.3441), (0.0970, 0.3651), (0.1060, 0.3819), (0.1163, 0.3923), (0.1267, 0.3982)];
  static const _tail3 = [(0.9343, 0.2424), (0.9297, 0.2688), (0.9246, 0.2972), (0.9197, 0.3218), (0.9148, 0.3435), (0.9090, 0.3640), (0.9025, 0.3740)];

  /// The Model 3's. Its lamps measured off the picture's own: the DRL strip
  /// round each headlamp, the tail lamp round each rear corner. Its
  /// indicator: a strip of its own just under the DRL's inner half, the
  /// repeater by the wing's camera, and the whole tail lamp.
  static const three = _Picture(
    dir: 'assets/car3',
    // Narrower than the picture: its render is about 11 % too wide for the
    // car (1850 by 4720 mm); every position here is a share, so all follow.
    aspect: 314 / 680 * 0.903,
    rows: [0.4756, 0.667, 0.829],
    axles: [0.205, 0.765],
    tyreL: 0.057, tyreR: 0.060, tyreW: 0.22,
    pillL: 0.176, pillW: 0.656,
    centre: 0.4962,
    nose: [(0.0279, 0.0)],
    tail: [(0.9645, 0.0)],
    pathFrom: (0.369, 0.50),
    corners: (head: _head3, tail: _tail3),
    turns: [
      _Turn([(0.0652, 0.2650), (0.0762, 0.3100), (0.0847, 0.3435), (0.0928, 0.3640)]),
      _Turn([(0.2542, 0.428), (0.2772, 0.428)], k: 0.83),
      _Turn(_tail3),
    ],
  );
}

/// The car's lights on its picture, but for a light bar the picture shows
/// (lit by [_Cabin] from its mask): the tail bar (red) on its outline, or the
/// 3's corner lamps; low beams a cone ahead, high beams a longer, brighter
/// one; braking, the tail brighter; an indicator, amber on the front lamp,
/// the wing and the tail bar's end or lamp. Painted twice: [beams] under the
/// car (the cones and every glow, so the body hides what would light it),
/// then the lamps themselves over it.
class _CarLights extends CustomPainter {
  _CarLights({
    required this.car,
    required this.drl,
    required this.low,
    required this.high,
    required this.brake,
    this.left = false,
    this.right = false,
    this.steerDeg,
    this.steerLines = false,
    this.reverse = false,
    this.beams = false,
  });

  /// In R: the path lines run out behind the car.
  final bool reverse;

  /// The steering wheel's angle, deg, left positive: the car's path either
  /// side, dotted, while the wheel is turned past 3° and 2 s after.
  final double? steerDeg;

  /// Whether to draw them ([Panda.steerLines]): past the mark, or just back.
  final bool steerLines;

  final Car car;
  final bool drl, low, high, brake;

  /// The cool white of an LED strip's bloom.
  static const _led = Color(0xFFDCEBFF);

  /// An indicator lit, in step with the car's flasher.
  final bool left, right;

  /// The beams alone, painted under the car (they light the road, not the
  /// bonnet); otherwise everything else, over it.
  final bool beams;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, pic = _Picture.of(car), body = car.model;
    // The bar: down one side of the outline, across the tip, back up the
    // other, moved [inward] along the length.
    List<Offset> bar(List<(double, double)> edge, double inward) => [
          for (final (y, half) in edge.reversed) Offset(w * (pic.centre - half), h * (y + inward)),
          for (final (y, half) in edge.skip(1)) Offset(w * (pic.centre + half), h * (y + inward)),
        ];
    // One side's points ([s] -1 left, 1 right).
    List<Offset> oneSide(List<(double, double)> pts, int s) =>
        [for (final (y, half) in pts) Offset(w * (pic.centre + s * half), h * y)];
    // A smooth curve through measured points (Catmull-Rom): a polyline
    // through pixel-rounded samples wriggles.
    Path smooth(List<Offset> p) {
      final path = Path()..moveTo(p.first.dx, p.first.dy);
      for (var i = 0; i < p.length - 1; i++) {
        final a = p[i > 0 ? i - 1 : i], b = p[i], c = p[i + 1], d = p[i + 2 < p.length ? i + 2 : i + 1];
        final c1 = b + (c - a) / 6, c2 = c - (d - b) / 6;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, c.dx, c.dy);
      }
      return path;
    }

    Paint line(Color c, double width, [double blur = 0]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = c
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
    // The beams: a cone from the front's corners, straight sides fanning
    // out, its far edge an arc (no flat top), the light fading with distance
    // on arcs alike ([reach]: a share of the length past the nose). Not
    // clipped to the outline: a clip's straight edge showed.
    void cone(Offset l, Offset r, double reach, double alpha) {
      final cx = w * pic.centre, nose = h * pic.nose.first.$1;
      final len = h * reach, spread = len * 0.7; // about 35° each side
      // The fade's centre well behind the nose: its rings, and the far edge
      // on one of them, are gentle arcs.
      final back = Offset(cx, nose + len * 0.9), radius = len * 1.9;
      final side = nose - len * 0.8; // where the sides end
      // The sides start under the body, a little back and in from the lamps,
      // so they come out from behind the car, not from a hard corner.
      final in_ = w * 0.06, down = h * 0.03;
      canvas.drawPath(
          Path()
            ..moveTo(l.dx + in_, l.dy + down)
            ..lineTo(l.dx - spread, side)
            ..arcToPoint(Offset(r.dx + spread, side), radius: Radius.circular(radius))
            ..lineTo(r.dx - in_, r.dy + down)
            ..close(),
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: alpha),
                Colors.white.withValues(alpha: alpha),
                Colors.white.withValues(alpha: alpha * 0.4),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0, 0.45, 0.75, 1],
            ).createShader(Rect.fromCircle(center: back, radius: radius))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // The lamps: the Y's bars across the nose and tail, or a lamp at each
    // corner; the beams from the outer ends of the front ones.
    final List<Path> fronts, rears;
    final Offset beamL, beamR;
    final cornerLamps = pic.corners != null; // the 3's, which also glow
    if (pic.corners case (:final head, :final tail)?) {
      fronts = [for (final s in [-1, 1]) smooth(oneSide(head, s))];
      rears = [for (final s in [-1, 1]) smooth(oneSide(tail, s))];
      beamL = oneSide(head, -1).last;
      beamR = oneSide(head, 1).last;
    } else {
      final front = bar(pic.nose, 0.002), rear = bar(pic.tail, 0);
      final tip = h * pic.tail.first.$1;
      fronts = const []; // the picture's own strip is the front bar; [front] places the beams
      rears = [
        pic.tailParabola
            ? (Path()
              ..moveTo(rear.first.dx, rear.first.dy)
              ..quadraticBezierTo(w * pic.centre, 2 * tip - rear.first.dy, rear.last.dx, rear.last.dy))
            : smooth(rear),
      ];
      beamL = front.first;
      beamR = front.last;
    }
    final front_ = drl || low || high, rear_ = front_ || brake;
    // A corner tail lamp's red steps back while its indicator is lit (the
    // rears left, then right), so the amber in the same lamp shows.
    double dim(int i) => cornerLamps && (i == 0 ? left : right) ? 0.35 : 1;
    if (beams) {
      // The space the car sweeps, as it really goes: with the wheel held,
      // the car turns about a point level with the rear axle, wheelbase /
      // tan(road wheel angle) to the side, and every point on it sweeps an
      // arc about that point, true to scale. Where an arc passes under the
      // car the body hides it (these are painted beneath it). Dots, fading
      // with distance; none while fairly straight ([steerLines]).
      final road = ((steerDeg ?? 0) / body.steerRatio).clamp(-body.maxRoadDeg, body.maxRoadDeg) * pi / 180;
      if (steerLines) {
        final wheelbase = h * (pic.axles[1] - pic.axles[0]);
        // Wheels dead straight (held after a turn): a turn too wide to see.
        final r = wheelbase / tan(max(road.abs(), 1e-4)), side = road > 0 ? -1 : 1; // left: centre to the left
        final cx = w * pic.centre, c = Offset(cx + side * r, h * pic.axles[1]);
        final step = h * 0.022;
        // Each line the true path of a point just outside the body, one arc
        // about that point, from the mirror tips on (at full lock the outer
        // one dips under the front corner and comes out ahead of it). In
        // reverse the very same shape flipped front to back, ending above the
        // bottom bar.
        final len = h * (reverse ? _Picture.pathBehind : _Picture.pathAhead);
        for (final s in [-1, 1]) {
          final p = Offset(cx + s * w * pic.pathFrom.$2, h * pic.pathFrom.$1);
          final rad = (p - c).distance, a0 = atan2(p.dy - c.dy, p.dx - c.dx);
          // The same two ends as the true arc, the line between them pushed further
          // out than the true arc (a quadratic through its middle, bulge x3).
          Offset at(double d) {
            final a = a0 + side * d / rad;
            return c + Offset(cos(a), sin(a)) * rad;
          }
          final q0 = at(0), q1 = at(len), mid = at(len / 2), chord = (q0 + q1) / 2;
          final ctrl = chord + (mid - chord) * 2 * 3;
          for (var d = 0.0; d <= len; d += step) {
            final t = d / len;
            final q = q0 * ((1 - t) * (1 - t)) + ctrl * (2 * t * (1 - t)) + q1 * (t * t);
            canvas.drawCircle(Offset(q.dx, reverse ? h - q.dy : q.dy), 1.6,
                Paint()..color = Colors.white.withValues(alpha: 0.8 * (1 - d / len)));
          }
        }
      }
      // Under the car: the beams and the bars' glow. The body hides the half
      // that would light it, and the glow fades round the bars' ends.
      if (high) {
        cone(beamL, beamR, 0.38, 0.56); // further, brighter
      } else if (low) {
        cone(beamL, beamR, 0.234, 0.35);
      }
      for (final p in front_ && cornerLamps ? fronts : const <Path>[]) {
        canvas.drawPath(p, line(Colors.white.withValues(alpha: 0.6), 3, 1.5));
      }
      for (final (i, p) in (rear_ ? rears : const <Path>[]).indexed) {
        canvas.drawPath(p, line(kAlert.withValues(alpha: (brake ? 0.95 : 0.5) * dim(i)), brake ? 6 : 3, brake ? 2.5 : 1.5));
      }
      return;
    }
    // Each lit indicator: its path, and how thick (the wing's is thin). A
    // tail light bar's own end is one: on its curve, along the rear edge.
    Path barEnd(Path bar, int s) {
      final m = bar.computeMetrics().firstOrNull, span = h * 0.035;
      if (m == null) return Path(); // no length to it (a zero-size layout)
      return s < 0 ? m.extractPath(0, span) : m.extractPath(m.length - span, m.length);
    }

    final turns = [
      for (final (on, s) in [(left, -1), (right, 1)])
        if (on) ...[
          for (final t in pic.turns) (smooth(oneSide(t.points, s)), 0.6 * t.k),
          if (!cornerLamps) (barEnd(rears.single, s), 0.6),
        ],
    ];
    // Over it, the lamps themselves.
    // A corner lamp (the 3's) glows from the lamp itself, over the body
    // round it as well as past it: a wide soft halo, and a bloom on the strip.
    if (cornerLamps) {
      for (final p in front_ ? fronts : const <Path>[]) {
        final (alpha, wide) = high ? (0.42, 0.2) : low ? (0.32, 0.16) : (0.2, 0.12);
        canvas.drawPath(p, line(_led.withValues(alpha: alpha), w * wide, w * wide * 0.42));
        if (low || high) canvas.drawPath(p, line(_led.withValues(alpha: high ? 0.55 : 0.42), w * 0.07, w * 0.03));
        canvas.drawPath(p, line(_led.withValues(alpha: 0.55), 2.6, 1.3));
      }
      for (final (i, p) in (rear_ ? rears : const <Path>[]).indexed) {
        final k = dim(i);
        canvas.drawPath(p, line(kAlert.withValues(alpha: (brake ? 0.36 : 0.2) * k), w * 0.12, w * 0.05));
        canvas.drawPath(p, line(kAlert.withValues(alpha: (brake ? 0.7 : 0.45) * k), 2.6, 1.3));
      }
    }
    for (final p in front_ && cornerLamps ? fronts : const <Path>[]) {
      canvas.drawPath(p, line(Colors.white, 0.75));
    }
    for (final p in rear_ ? rears : const <Path>[]) {
      canvas.drawPath(p, line(brake ? const Color(0xFFFF6B6B) : kAlert, brake ? 1 : 0.75));
    }
    // An indicator glows from the lamp itself, over the body round it as
    // well as past it (over a corner lamp's halo too: amber wins while lit).
    for (final (t, k) in turns) {
      canvas.drawPath(t, line(kWarn.withValues(alpha: 0.5), w * 0.09 * k / 0.6, w * 0.038 * k / 0.6));
      canvas.drawPath(t, line(kWarn, 5 * k, 2 * k));
      canvas.drawPath(t, line(const Color(0xFFFFD27A), 1.5 * k));
    }
  }

  @override
  bool shouldRepaint(_CarLights old) =>
      old.car != car ||
      old.drl != drl ||
      old.low != low ||
      old.high != high ||
      old.brake != brake ||
      old.left != left ||
      old.right != right ||
      old.steerDeg != steerDeg ||
      old.steerLines != steerLines ||
      old.reverse != reverse ||
      old.beams != beams;
}

/// The car as it is, its seats as the picture has them: what the car picker shows for each
/// layout.
class CarSeats extends StatelessWidget {
  const CarSeats({super.key, required this.car, required this.height});

  final Car car;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pic = _Picture.of(car);
    return SizedBox(
      height: height,
      width: height * pic.aspect,
      child: Image.asset('${pic.dir}/car.png', fit: BoxFit.fill),
    );
  }
}

/// The car from above, front up, its seats as the car picked has them (the
/// driver front left: this car is LHD), its lights ([_CarLights]) and each
/// tyre's pressure (psi) on its wheel. Once the stream is live: on each row
/// its air temperature and fan as the screen sets it (the third row has no
/// fan; a 5-seater's in the boot), and the seats: as the picture has them while empty or
/// not yet heard, green once the belt is buckled, red while someone sits in
/// it unbuckled (that row's figures then step aside). Not over Bluetooth,
/// which has none of it; before the stream the saved pressures on the car.
class _Cabin extends StatelessWidget {
  const _Cabin({required this.obd, this.carHeight});

  final Panda obd;

  /// The car's own height, for a basic card: drawn to it, its figures their
  /// own size (a little over the full layout's), its paddings trimmed (its
  /// top [fillInset] under the widget's). Otherwise its own size, which the
  /// full layout's column scales, figures and all.
  final double? carHeight;

  static const _fillFrame = 2.0, _fillTop = 2.0, _fillFigures = 1.38;

  /// Where a [carHeight] car's picture starts, under the widget's top.
  static double fillInset(BuildContext context) => _fillFrame + MediaQuery.textScalerOf(context).scale(_fillTop);

  @override
  Widget build(BuildContext context) {
    final o = obd;
    if (o.viaBt) return const SizedBox.shrink();
    // Before the chime's frame, someone seated unbuckled would show plain.
    final live = o.wifiLive && o.frames.containsKey(0x3A1);
    final belt = live && o.anyBeltUnbuckled;
    final scale = MediaQuery.textScalerOf(context).scale;
    bool rowUnbuckled(int row) => o.car.seatsIn(row).any(o.unbuckledAt);
    final pic = _Picture.of(o.car), dir = pic.dir;
    final fill = carHeight != null;
    // Room above it for the beams over the lamps' row, behind it for the
    // brake glow, and round it for the unbuckled seat's frame.
    final padTop = scale(fill ? _fillTop : 4), padBottom = scale(fill ? 4 : 6), frame = fill ? _fillFrame : 4.0;
    final carH = carHeight ?? scale(236);
    final carW = carH * pic.aspect; // the image's own shape
    // A tyre's psi on the body over its wheel: between the outline and the
    // seats, as far in from each side (the mirrors make the image wider than
    // the body, the left more than the right).
    // Bigger figures widen the box about its centre and shrink to it.
    final f = fill ? _fillFigures : 1.0, tyreOut = carW * pic.tyreW * (f - 1) / 2;
    Widget tyre(double? bar, double at, bool left) => Positioned(
          left: left ? carW * pic.tyreL - tyreOut : null,
          right: left ? null : carW * pic.tyreR - tyreOut,
          width: carW * pic.tyreW * f,
          top: carH * at - scale(15) * f,
          height: scale(30) * f,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(bar == null ? '—' : (bar * 14.5038).round().toString(),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 * f,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: const [Shadow(blurRadius: 3)])),
              Text('psi',
                  style: TextStyle(color: Colors.white60, fontSize: 9 * f, height: 1, shadows: const [Shadow(blurRadius: 3)])),
            ]),
          ),
        );
    // A row's air and fan on a dark pill over its seats, centred on them. On
    // basic's card the air as big as a tyre's figure and the fan's word as
    // its "psi", so the two read alike.
    final temp = (fill ? 14 : 16) * f, word = (fill ? 9 : 11) * f;
    Widget row(double at, double c, [String? fan]) => Positioned(
          left: carW * pic.pillL,
          width: carW * pic.pillW,
          top: carH * at - scale(fan == null ? 11 : 19) * f,
          height: scale(fan == null ? 22 : 38) * f,
          // Shrinks, never overflows, should a long fan word meet big figures.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_deg(c),
                      style: TextStyle(fontSize: temp, height: 1.1, fontWeight: FontWeight.w600, color: Colors.white)),
                  if (fan != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GlyphIcon(fan == 'OFF' ? Glyph.fanOff : Glyph.fan, size: word + 1 * f, color: Colors.white70),
                      if (fan != 'OFF')
                        Text(' $fan', style: TextStyle(fontSize: word, height: 1.1, color: Colors.white70)),
                    ]),
                ]),
              ),
            ),
          ),
        );
    // The beams and paths under the car, the rest over it.
    Widget lights({bool beams = false}) => CustomPaint(
        painter: _CarLights(
            car: o.car,
            drl: o.drl == true,
            low: o.lowBeam == true,
            high: o.highBeam == true,
            brake: o.braking,
            left: o.indL && o.blinkLit,
            right: o.indR && o.blinkLit,
            // The paths only under it: the layer over it does not repaint as the wheel turns.
            steerDeg: beams ? o.steerDeg : null,
            steerLines: beams && o.steerLines,
            reverse: beams && o.gear == 'R',
            beams: beams));
    final picture = SizedBox(
      width: carW,
      height: carH,
      child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
        // An empty seat, or one not yet heard, shows as the picture has it.
        // The masks are the white-seat picture's seats, multiplied by the
        // colour, shading and all. The beams under it.
        if (o.live) lights(beams: true),
        Image.asset('$dir/car.png', fit: BoxFit.fill),
        if (live)
          for (final s in o.car.seatNames)
            if (o.unbuckledAt(s) || o.buckled.contains(s))
              Image.asset('$dir/seat_$s.png',
                  fit: BoxFit.fill, colorBlendMode: BlendMode.modulate, color: o.unbuckledAt(s) ? kAlert : kRegen),
        // The front light bar, lit: the picture's strip and its glow.
        if (o.live && pic.drlStrip && o.frontLit) ...[
          Image.asset('$dir/drl_glow.png', fit: BoxFit.fill), // blurred ahead: no blur each frame
          Image.asset('$dir/drl.png', fit: BoxFit.fill),
        ],
        // Its lights, past its ends into the room the padding leaves.
        if (o.live) lights(),
        tyre(o.tpFL, pic.axles[0], true),
        tyre(o.tpFR, pic.axles[0], false),
        tyre(o.tpRL, pic.axles[1], true),
        tyre(o.tpRR, pic.axles[1], false),
        // A row with a seat unbuckled leaves the red in full view.
        if (live) ...[
          // A row the car gives no air reading for shows none.
          // Only the row's own seats count (the L has no second-row middle).
          if (o.cabinC1 != null && !rowUnbuckled(1)) row(pic.rows[0], o.cabinC1!, o.fan1),
          if (o.cabinC2 != null && !rowUnbuckled(2)) row(pic.rows[1], o.cabinC2!, o.fan2),
          // A 5-seater's in the boot, should the car send one; no belts there.
          if (o.cabinC3 != null && !rowUnbuckled(3)) row(pic.rows[2], o.cabinC3!),
        ],
      ]),
    );
    // Shrinks rather than overflows in the column beside the ring.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        // The beams reach up over the lamps' row above, and a little room
        // behind for the brake glow: outside the unbuckled seat's frame, which
        // keeps to the picture (its own margins clear the car).
        padding: EdgeInsets.only(top: frame + padTop, bottom: frame + padBottom),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: belt
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: kAlert.withValues(alpha: 0.18),
                  border: Border.all(color: kAlert),
                )
              : null,
          child: picture,
        ),
      ),
    );
  }
}

/// What the pack feeds besides the motors: the climate, and ([minor]) the
/// 12 V side and the rest.
class _Draws extends StatelessWidget {
  const _Draws({required this.obd, this.minor = true});

  final Panda obd;
  final bool minor; // 12 V and the rest (the full layout hides them unless switched on)

  @override
  Widget build(BuildContext context) {
    final o = obd, live = o.wifiLive;
    String kw(double? v) => !live || v == null ? '—' : '${v.toStringAsFixed(1)} kW';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _statRow(context, 'CLIMATE', kw(o.climateKw)),
      if (minor) ...[
        _statRow(context, '12 V', kw(o.lvKw)),
        _statRow(context, 'OTHER', kw(o.otherKw)),
      ],
    ]);
  }
}

/// While charging: to what % and by when, as the nav puts a route.
/// WiFi only.
class _Charge extends StatelessWidget {
  const _Charge({required this.obd, this.oneLine = false});

  final Panda obd;
  final bool oneLine; // the compact dash: one row under the ring

  @override
  Widget build(BuildContext context) {
    final o = obd;
    if (!o.wifiLive || !o.charging) return const SizedBox.shrink();
    const big = TextStyle(fontSize: 18, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]);
    final pct = o.chargeLimitPct, m = o.chargeMinutes;
    final to = pct == null ? null : 'to $pct %';
    final when = m == null
        ? null
        : '${m < 60 ? '$m min' : '${m ~/ 60}h ${m % 60}m'}   '
            '${TimeOfDay.fromDateTime(DateTime.now().add(Duration(minutes: m))).format(context)}';
    if (to == null && when == null) return const SizedBox.shrink();
    if (oneLine) {
      return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text([?to, ?when].join('   '), style: big));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CHARGE', style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.white70)),
      const SizedBox(height: 2),
      if (to != null) Text(to, style: big),
      if (when != null) FittedBox(fit: BoxFit.scaleDown, child: Text(when, style: big)),
    ]);
  }
}

// The pieces both layouts in main.dart are built from: the ring's centre,
// the side columns' cards, the buttons and the bottom bar. A part of
// main.dart, so they stay private to it.
part of 'main.dart';

/// Digital speed in the ring's hole, the limit sign above it, the cruise or
/// charge cue below; under them the gear, where [gear] asks for it (the
/// compact dash has it in its corner).
class _Centre extends StatelessWidget {
  const _Centre({required this.obd, this.gear = false});

  final Panda obd;
  final bool gear;

  @override
  Widget build(BuildContext context) {
    final o = obd;
    // Charging in P: the power going in, where the speed would be.
    final charge = o.wifiLive && o.charging && o.gear == 'P' && o.chargeKw != null;
    final cue = _cue(charge);
    return LayoutBuilder(
        builder: (context, c) => Stack(alignment: Alignment.center, children: [
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
          // One short line below, mirroring the limit sign above: the speed
          // stays centred. As wide as the digits, which is also where the
          // ring's arc closes in at that height; longer lines shrink.
          if (cue != null)
            Positioned(
              bottom: c.maxHeight * 0.17,
              child: SizedBox(
                width: c.maxWidth * 0.5,
                height: c.maxHeight * 0.075,
                child: FittedBox(fit: BoxFit.scaleDown, child: cue),
              ),
            ),
          // The limit above the speed, scaled to the ring; the speed stays
          // centred between the kW readouts.
          Positioned(
            top: c.maxHeight * 0.1,
            child: SizedBox.square(
              dimension: c.maxHeight * 0.16,
              child: FittedBox(child: _SpeedLimit(limit: obd.speedLimit)),
            ),
          ),
          // Only the gear engaged, in the gap the ring leaves at its foot,
          // clear of the brake's arc there.
          if (gear)
            Positioned(
              bottom: c.maxHeight * 0.05,
              child: Text(o.gear,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const {'P', 'R', 'N', 'D'}.contains(o.gear) ? Colors.white : Colors.white38)),
            ),
        ]),
      );
  }

  /// The line under the speed: charging, the most the pack takes now and
  /// why; else the cruise set speed and gap while cruise holds one. (A
  /// regen cap shows on the ring itself.)
  Widget? _cue(bool charge) {
    final o = obd;
    const s = TextStyle(fontSize: 15, letterSpacing: 1, fontWeight: FontWeight.w600);
    if (charge) {
      final max = o.chargeMaxKw, why = o.chargeWhy;
      if (max == null && why == null) return null;
      return Text.rich(TextSpan(children: [
        if (max != null) TextSpan(text: 'MAX ${max.round()}', style: s.copyWith(color: Colors.white70)),
        if (why != null) TextSpan(text: '${max != null ? ' · ' : ''}$why', style: s.copyWith(color: kWarn)),
      ]));
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
      ]);
    }
    return null;
  }
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

/// The air outside by the ring (ice blue near freezing), over it its name,
/// or in its place, amber, that the washer fluid is low. Right-aligned, as
/// it sits to the left of the arc.
class _Outside extends StatelessWidget {
  const _Outside({required this.obd});

  final Panda obd;

  @override
  Widget build(BuildContext context) {
    final o = obd, c = o.outsideC, washer = o.wifiLive && o.washerLow;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(washer ? 'WASHER LOW' : 'OUTSIDE',
          style: TextStyle(fontSize: 10, height: 1.2, letterSpacing: 1, color: washer ? kWarn : Colors.white54)),
      Text(c == null ? '—' : _deg(c),
          style: TextStyle(
              fontSize: 18,
              height: 1.15,
              color: c != null && c <= 3 ? kCold : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()])),
    ]);
  }
}

/// The Autopilot icon ([_autopilot]): its glyph on a [disc] of that colour,
/// white on it (dark on amber, which white does not read on), [flash]ing
/// twice a second, [struck] through when locked out.
class _ApIcon extends StatefulWidget {
  const _ApIcon({
    required this.disc,
    required this.glyph,
    required this.flash,
    required this.struck,
    required this.words,
    required this.size,
  });

  final Color disc;
  final Glyph glyph;
  final bool flash, struck;
  final String words;
  final double size;

  @override
  State<_ApIcon> createState() => _ApIconState();
}

class _ApIconState extends State<_ApIcon> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

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
    if (widget.flash && !_blink.isAnimating) {
      _blink.repeat(reverse: true);
    } else if (!widget.flash && _blink.isAnimating) {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget, size = w.size;
    final mark = w.disc == kWarn ? Colors.black : Colors.white;
    return Tooltip(
      message: w.words,
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.2).animate(_blink),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: w.disc),
          // The wheel is drawn to the disc's own size; the gauge smaller.
          child: Stack(alignment: Alignment.center, children: [
            GlyphIcon(w.glyph, size: w.glyph == Glyph.autopilot ? size : size * 0.66, color: mark),
            if (w.struck) CustomPaint(size: Size.square(size), painter: _Strike(w.disc, mark)),
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

/// Basic layout's stack of cards beside the ring: one shows, filling the
/// side; a swipe up or down brings the next, and dots at the side say
/// which. Every card is laid out in its card's size over [_scale] and then
/// scaled up by it, so text is one size across cards; a card fills that box
/// itself (a graphic takes the room its text leaves; [_fit] centres
/// fixed-size content, shrunk only if too big). A [_Fill] card, a picture,
/// is as large as its card allows.
/// ponytail: one fixed scale, set for the S23 Ultra's 823 x 384 dp.
class _Cards extends StatefulWidget {
  const _Cards({super.key, required this.cards, this.initial = 0, this.onPage, this.dotsLeft = false});

  final List<Widget> cards;
  final bool dotsLeft; // the dots on the screen's edge: the left stack's at its left
  final int initial; // the card shown first
  final ValueChanged<int>? onPage;

  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  static const _scale = 1.22; // every card's text, over the full layout's: the widest row (a label and its value) just fits
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                c is _Fill
                    ? LayoutBuilder(
                        builder: (context, box) => Padding(
                            padding: EdgeInsets.fromLTRB(pad.left, box.maxHeight * c.top, pad.right, 0),
                            child: FittedBox(child: c.child)))
                    : Padding(
                        padding: pad,
                        child: LayoutBuilder(
                          builder: (context, box) => FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(width: box.maxWidth / _scale, height: box.maxHeight / _scale, child: c),
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

/// A card of [_Cards] that fills it, as large as it fits.
class _Fill extends StatelessWidget {
  const _Fill(this.child, {this.top = 0});

  final Widget child;
  final double top; // room left above it, a share of the card's height (the car's beams shine into it)

  @override
  Widget build(BuildContext context) => child;
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
        fontSize: tall ? 16 : 18, height: 1.1, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]);
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
          icon: const Icon(Icons.more_horiz, color: Colors.white),
          tooltip: 'More actions',
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
        // honk and flash live in More actions.
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
  const _Battery({required this.obd, this.width = 88});

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
                        TextSpan(text: '${t.abs() < 10 ? t.toStringAsFixed(1) : t.round()}°', children: [
                          if (o.precondC case final to?)
                            TextSpan(text: ' → ${to.round()}°', style: const TextStyle(color: kWarn)),
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
  const _GBall({required this.obd, this.tall = false});

  final Panda obd;
  final bool tall; // basic's card: the ball as big as the room, the figures under it

  @override
  State<_GBall> createState() => _GBallState();
}

class _GBallState extends State<_GBall> {
  // The last few dots, oldest first: about a fifth of a second at the
  // fast tick's 45 a second. Still, they gather under the dot.
  final _trail = <Offset>[];

  @override
  Widget build(BuildContext context) {
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
    if (widget.tall) {
      return Column(children: [
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: ball))),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, spacing: 12, children: figures),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox.square(dimension: 72, child: ball),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: figures),
    ]);
  }
}

/// Rings at 0.5 and 1 g on a crosshair; inside them, faint, how far this
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
    canvas.drawCircle(c, r, stroke(Colors.white24, 1.5));
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
      canvas.drawPath(p, Paint()..color = kAccent.withValues(alpha: 0.22));
    }
    Offset at(Offset g) => c + (g.distance > 1 ? g / g.distance : g) * r;
    for (var i = 1; i < trail.length; i++) {
      canvas.drawLine(at(trail[i - 1]), at(trail[i]),
          stroke(Colors.white.withValues(alpha: 0.7 * i / trail.length), 2)..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(at(trail.last), 5, Paint()..color = Colors.black);
    canvas.drawCircle(at(trail.last), 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GPainter old) => !listEquals(old.trail, trail) || old.peaks != peaks;
}

/// Temperatures and battery health: the air outside (ice blue from +3 °C
/// down, where bridges freeze first), washer fluid once it runs low (the
/// pack's own temperature is in the battery dial); then the spread between the strongest and weakest cell
/// group, and how far full-pack energy has fallen from the BMS's figure for
/// it new.
/// A label and its value, the labels one width so the values line up.
/// [size]: over the full layout's (a basic card passes the inverse of its
/// scale, so its rows come out the full layout's size on screen).
Widget _statRow(BuildContext context, String label, String value, {Color color = Colors.white, double size = 1}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: MediaQuery.textScalerOf(context).scale(104) * size, // aligns the values
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontSize: 12 * size, letterSpacing: 0.8 * size, color: Colors.white70)),
      ),
      Text(value, style: TextStyle(fontSize: 16 * size, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
    ]);

class _Pack extends StatelessWidget {
  const _Pack({required this.obd, this.outside = true, this.pack = true, this.minor = true, this.size = 1});

  final Panda obd;
  final bool outside, pack; // the air outside (and washer), the pack's health
  final bool minor; // the cell imbalance (a switch in the settings hides it)
  final double size; // [_statRow]'s

  @override
  Widget build(BuildContext context) {
    final o = obd, mv = o.imbalanceMv;
    final kwh = o.packKwh, isNew = o.packNewKwh;
    final out = o.outsideC;
    Widget row(String label, String value, {Color color = Colors.white}) =>
        _statRow(context, label, value, color: color, size: size);
    // Shrinks rather than overflows when a large font meets a wide ring.
    return FittedBox(fit: BoxFit.scaleDown, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (outside) ...[
        row('OUTSIDE', out == null ? '—' : _deg(out), color: out != null && out <= 3 ? kCold : Colors.white),
        if (o.wifiLive && o.washerLow) row('WASHER', 'LOW', color: kWarn),
      ],
      if (pack) ...[
        if (minor) row('IMBALANCE', mv == null ? '—' : '${mv.round()} mV'),
        row('DEGRADATION', kwh == null || isNew == null ? '—' : '${((1 - kwh / isNew) * 100).clamp(0, 100).toStringAsFixed(1)} %'),
      ],
    ]));
  }
}

/// A temperature as the car reads it: to the half degree near freezing,
/// whole degrees beyond.
String _deg(double c) => '${c.abs() < 10 ? c.toStringAsFixed(1) : c.round()} °C';

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
      if (o.drl == true) lamp('DRL', Glyph.drl),
      if (o.lowBeam == true) lamp('LOW', Glyph.lowBeam),
      if (o.highBeam == true) lamp('HIGH', Glyph.highBeam, kAccent),
      if (grip) lamp(o.tcMode ?? 'GRIP', Glyph.grip, o.gripLit && !o.gripHeld ? kCold : kWarn),
    ]));
  }
}

/// The car pictures: one per layout, the same car at the same size and
/// place, so one set of positions serves both: shares of the picture's width
/// and length.
abstract final class _Car {
  static const aspect = 257 / 570;
  static String dir(bool thirdRow) => thirdRow ? 'assets/car' : 'assets/car5';
  static List<String> seats(bool thirdRow) => ['D', 'P', '2L', '2C', '2R', if (thirdRow) ...['3L', '3R']];

  /// Each seat row's centre along the length, front first.
  static const rows = [0.494, 0.66, 0.804];

  /// The axles, front and rear.
  static const axles = [0.205, 0.80];

  /// The tyre figures: in from each side (the mirrors make the picture
  /// wider than the body, and not evenly), and as wide.
  static const tyreL = 0.10, tyreR = 0.068, tyreW = 0.21;

  /// The rows' pills, centred on the seats.
  static const pillL = 0.213, pillW = 0.62;

  /// The body's centre line, across the width (the mirrors make the picture
  /// uneven, the body is not).
  static const centre = 0.5155;

  /// The outline of the nose and of the tail, from the tip back, as (along,
  /// half the body's width there), the same both sides: the light bars sit on
  /// it. The nose's runs back to where the body is nearly its full width; the
  /// tail's spans the hatch, corner to corner, not up the sides.
  static const nose = [
    (0.030, 0.0), (0.035, 0.154), (0.040, 0.214), (0.046, 0.244), (0.051, 0.263),
    (0.061, 0.300), (0.072, 0.329), (0.082, 0.355), (0.093, 0.372), (0.104, 0.386),
  ];
  // The tail's: just outside its outline (the wider side of both pictures,
  // so it hugs either evenly), flat across the bumper's middle.
  static const tail = [
    (0.9635, 0.0), (0.9635, 0.05), (0.9595, 0.105), (0.956, 0.138), (0.9525, 0.163), (0.949, 0.186),
    (0.9455, 0.208), (0.9405, 0.222), (0.9368, 0.238), (0.9333, 0.249), (0.9298, 0.269), (0.9263, 0.280),
  ];

  /// Where the path lines start: just outside the mirror tips (0.473 either
  /// side of [centre], at 0.355 of the length): the car's widest points,
  /// whose paths bound the space it sweeps.
  static const pathFrom = (0.355, 0.495);

  /// The steering: the Model Y's 12.1 m turning circle (kerb to kerb, so
  /// 6.05 m to the outer front wheel), 2.89 m wheelbase and 1.66 m track put
  /// the rear axle's centre 4.48 m from the turning point at full lock:
  /// 32.8° for the one road wheel of the bicycle model. The wheel turns about
  /// 450° each way, so a ratio near 13.7:1.
  /// ponytail: published figures; set them from a full-lock reading once the
  /// steering frame is confirmed.
  static const steerRatio = 13.7, maxRoadDeg = 32.8;

  /// The turn signals, each side alike, on the body's edge (the narrower
  /// side of both pictures): at the nose bar's end,
  /// the side repeater on the front wing, at the tail bar's end.
  static const turns = [
    [(0.072, 0.329), (0.082, 0.355), (0.093, 0.372), (0.104, 0.386)],
    [(0.259, 0.404), (0.273, 0.401)], // by the wing's camera: a thin, short one
    [(0.9263, 0.272), (0.9193, 0.299), (0.9088, 0.331)],
  ];
}

/// The indicators' amber.
const kTurn = Color(0xFFFFB000);

/// The car's lights on its picture: with the DRL thin bars on the nose
/// (white) and the tail (red) outlines; low beams a cone ahead, high beams a
/// longer, brighter one; braking, the tail bar brighter; an indicator, amber
/// at both bars' ends and on the front wing. Painted twice: [beams] under
/// the car (the cones and every glow, so the body hides what would light
/// it), then the lamps themselves over it.
class _CarLights extends CustomPainter {
  _CarLights({
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
    this.reach = 1,
  });

  /// The beams' length over their usual: basic's bigger car has less room
  /// ahead of it to the screen's edge.
  final double reach;

  /// In R: the path lines run out behind the car.
  final bool reverse;

  /// The steering wheel's angle, deg, left positive: the car's path either
  /// side, dotted, while the wheel is turned past 3° and 2 s after.
  final double? steerDeg;

  /// Whether to draw them ([Panda.steerLines]): past the mark, or just back.
  final bool steerLines;

  final bool drl, low, high, brake;

  /// An indicator lit, in step with the car's flasher.
  final bool left, right;

  /// The beams alone, painted under the car (they light the road, not the
  /// bonnet); otherwise everything else, over it.
  final bool beams;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // The bar: down one side of the outline, across the tip, back up the
    // other, moved [inward] along the length.
    List<Offset> bar(List<(double, double)> edge, double inward) => [
          for (final (y, half) in edge.reversed) Offset(w * (_Car.centre - half), h * (y + inward)),
          for (final (y, half) in edge.skip(1)) Offset(w * (_Car.centre + half), h * (y + inward)),
        ];
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
    void cone(List<Offset> front, double reach, double alpha) {
      final l = front.first, r = front.last, cx = w * _Car.centre, nose = h * _Car.nose.first.$1;
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

    final front = bar(_Car.nose, 0.002), rear = bar(_Car.tail, 0);
    // The tail's a parabola from end to end (its outline is one, near
    // enough): the smoothest there is.
    final tip = h * _Car.tail.first.$1;
    final frontPath = smooth(front),
        rearPath = Path()
          ..moveTo(rear.first.dx, rear.first.dy)
          ..quadraticBezierTo(w * _Car.centre, 2 * tip - rear.first.dy, rear.last.dx, rear.last.dy);
    final front_ = drl || low || high, rear_ = front_ || brake;
    // Each lit indicator: its path, and how thick (the wing's is thin).
    final turns = [
      for (final (on, side) in [(left, -1), (right, 1)])
        if (on)
          for (final (i, seg) in _Car.turns.indexed)
            (
              smooth([for (final (y, half) in seg) Offset(w * (_Car.centre + side * half), h * y)]),
              i == 1 ? 0.5 : 0.6,
            ),
    ];
    if (beams) {
      // The space the car sweeps, as it really goes: with the wheel held,
      // the car turns about a point level with the rear axle, wheelbase /
      // tan(road wheel angle) to the side, and every point on it sweeps an
      // arc about that point, true to scale. Where an arc passes under the
      // car the body hides it (these are painted beneath it). Dots, fading
      // with distance; none while fairly straight ([steerLines]).
      final road = ((steerDeg ?? 0) / _Car.steerRatio).clamp(-_Car.maxRoadDeg, _Car.maxRoadDeg) * pi / 180;
      if (steerLines) {
        final wheelbase = h * (_Car.axles[1] - _Car.axles[0]); // 2.89 m
        // Wheels dead straight (held after a turn): a turn too wide to see.
        final r = wheelbase / tan(max(road.abs(), 1e-4)), side = road > 0 ? -1 : 1; // left: centre to the left
        final cx = w * _Car.centre, c = Offset(cx + side * r, h * _Car.axles[1]);
        final step = h * 0.022;
        // Each line the true path of a point just outside the body, one arc
        // about that point, from the mirror tips on (at full lock the outer
        // one dips under the front corner and comes out ahead of it). In
        // reverse the very same shape flipped front to back, ending above the
        // bottom bar.
        final len = reverse ? h * 0.53 : h * 0.7;
        for (final s in [-1, 1]) {
          final p = Offset(cx + s * w * _Car.pathFrom.$2, h * _Car.pathFrom.$1);
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
        cone(front, 0.38 * reach, 0.56); // further, brighter
      } else if (low) {
        cone(front, 0.234 * reach, 0.35);
      }
      if (front_) canvas.drawPath(frontPath, line(Colors.white.withValues(alpha: 0.6), 3, 1.5));
      if (rear_) canvas.drawPath(rearPath, line(kAlert.withValues(alpha: brake ? 0.95 : 0.5), brake ? 6 : 3, brake ? 2.5 : 1.5));
      for (final (t, k) in turns) {
        // A wide soft halo and a brighter core round the thin lamp.
        canvas.drawPath(t, line(kTurn.withValues(alpha: 0.5), 20 * k, 10 * k));
        canvas.drawPath(t, line(kTurn, 9 * k, 4 * k));
      }
      return;
    }
    // Over it, the bars themselves.
    if (front_) canvas.drawPath(frontPath, line(Colors.white, 0.75));
    if (rear_) canvas.drawPath(rearPath, line(brake ? const Color(0xFFFF6B6B) : kAlert, brake ? 1 : 0.75));
    for (final (t, k) in turns) {
      canvas.drawPath(t, line(const Color(0xFFFFD27A), 1.5 * k));
    }
  }

  @override
  bool shouldRepaint(_CarLights old) =>
      old.drl != drl ||
      old.low != low ||
      old.high != high ||
      old.brake != brake ||
      old.left != left ||
      old.right != right ||
      old.steerDeg != steerDeg ||
      old.steerLines != steerLines ||
      old.reverse != reverse ||
      old.beams != beams ||
      old.reach != reach;
}

/// The car as it is, dark seats and all: what the car picker shows for each
/// layout.
class CarSeats extends StatelessWidget {
  const CarSeats({super.key, required this.thirdRow, required this.height});

  final bool thirdRow;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: height * _Car.aspect,
        child: Image.asset('${_Car.dir(thirdRow)}/car.png', fit: BoxFit.fill),
      );
}

/// The car from above, front up, its seats 2 + 3 + 2 or 2 + 3 as picked (the
/// driver front left: this car is LHD), its lights ([_CarLights]) and each
/// tyre's pressure (psi) on its wheel. Once the stream is live: on each row
/// its air temperature and fan as the screen sets it (the third row has no
/// fan; a 5-seater's in the boot), beside the car what the pack feeds besides
/// the motors, and the seats: dark, as the picture has them, while empty or
/// not yet heard, green once the belt is buckled, red while someone sits in
/// it unbuckled (that row's figures then step aside). Not over Bluetooth,
/// which has none of it; before the stream the saved pressures on the car.
class _Cabin extends StatelessWidget {
  const _Cabin({required this.obd, this.figures = 1, this.reach = 1});

  final Panda obd;

  /// The tyre and seat figures' size, over the full layout's (basic: bigger).
  final double figures;

  /// The beams' length ([_CarLights.reach]).
  final double reach;

  @override
  Widget build(BuildContext context) {
    final o = obd;
    if (o.viaBt) return const SizedBox.shrink();
    // Before the chime's frame, someone seated unbuckled would show plain.
    final live = o.wifiLive && o.frames.containsKey(0x3A1);
    final belt = live && o.anyBeltUnbuckled;
    final scale = MediaQuery.textScalerOf(context).scale;
    final unbuckled = {
      'D': o.beltDriver, 'P': o.beltPass, '2L': o.belt2L, '2C': o.belt2C,
      '2R': o.belt2R, '3L': o.belt3L, '3R': o.belt3R,
    };
    // As tall as the column allows: the rows' figures sit on the seats.
    final dir = _Car.dir(o.thirdRow);
    final carH = scale(236), carW = carH * _Car.aspect; // the image's own shape
    // A tyre's psi on the body over its wheel: between the outline and the
    // seats, as far in from each side (the mirrors make the image wider than
    // the body, the left more than the right).
    // Bigger figures widen the box about its centre and shrink to it.
    final f = figures, tyreOut = carW * _Car.tyreW * (f - 1) / 2;
    Widget tyre(double? bar, double at, bool left) => Positioned(
          left: left ? carW * _Car.tyreL - tyreOut : null,
          right: left ? null : carW * _Car.tyreR - tyreOut,
          width: carW * _Car.tyreW * f,
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
    // A row's air and fan on a dark pill over its seats, centred on them.
    Widget row(double at, double c, [String? fan]) => Positioned(
          left: carW * _Car.pillL,
          width: carW * _Car.pillW,
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
                  Text('${c.round()}°',
                      style: TextStyle(fontSize: 16 * f, height: 1.1, fontWeight: FontWeight.w600, color: Colors.white)),
                  if (fan != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GlyphIcon(fan == 'OFF' ? Glyph.fanOff : Glyph.fan, size: 12 * f, color: Colors.white70),
                      if (fan != 'OFF')
                        Text(' $fan', style: TextStyle(fontSize: 11 * f, height: 1.1, color: Colors.white70)),
                    ]),
                ]),
              ),
            ),
          ),
        );
    final car = SizedBox(
      width: carW,
      height: carH,
      child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
        // The picture's seats are dark: an empty one, or one not yet heard,
        // shows as it is. The masks are the white-seat picture's seats,
        // multiplied by the colour, shading and all. The beams under it.
        if (o.live)
          CustomPaint(
              painter: _CarLights(
                  drl: o.drl == true,
                  low: o.lowBeam == true,
                  high: o.highBeam == true,
                  brake: o.braking,
                  left: o.indL && o.blinkLit,
                  right: o.indR && o.blinkLit,
                  steerDeg: o.steerDeg,
                  steerLines: o.steerLines,
                  reverse: o.gear == 'R',
                  beams: true,
                  reach: reach)),
        Image.asset('$dir/car.png', fit: BoxFit.fill),
        if (live)
          for (final s in _Car.seats(o.thirdRow))
            if (unbuckled[s]! || o.buckled.contains(s))
              Image.asset('$dir/seat_$s.png',
                  fit: BoxFit.fill, colorBlendMode: BlendMode.modulate, color: unbuckled[s]! ? kAlert : kRegen),
        // Its lights, past its ends into the room the padding leaves.
        if (o.live)
          CustomPaint(
              painter: _CarLights(
                  drl: o.drl == true,
                  low: o.lowBeam == true,
                  high: o.highBeam == true,
                  brake: o.braking,
                  left: o.indL && o.blinkLit,
                  right: o.indR && o.blinkLit)),
        tyre(o.tpFL, _Car.axles[0], true),
        tyre(o.tpFR, _Car.axles[0], false),
        tyre(o.tpRL, _Car.axles[1], true),
        tyre(o.tpRR, _Car.axles[1], false),
        // A row with a seat unbuckled leaves the red in full view.
        if (live) ...[
          // A row the car gives no air reading for shows none.
          if (o.cabinC1 != null && !o.beltDriver && !o.beltPass) row(_Car.rows[0], o.cabinC1!, o.fan1),
          if (o.cabinC2 != null && !o.belt2L && !o.belt2C && !o.belt2R) row(_Car.rows[1], o.cabinC2!, o.fan2),
          // A 5-seater's in the boot, should the car send one; no belts there.
          if (o.cabinC3 != null && (!o.thirdRow || (!o.belt3L && !o.belt3R))) row(_Car.rows[2], o.cabinC3!),
        ],
      ]),
    );
    // Shrinks rather than overflows in the column beside the ring.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        decoration: belt
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kAlert.withValues(alpha: 0.18),
                border: Border.all(color: kAlert),
              )
            : null,
        // The beams reach up over the lamps' row above. A little room
        // behind for the brake glow.
        child: Padding(padding: EdgeInsets.only(top: scale(4), bottom: scale(6)), child: car),
      ),
    );
  }
}

/// Basic layout's card of what the pack feeds besides the motors.
class _Draws extends StatelessWidget {
  const _Draws({required this.obd, this.minor = true, this.size = 1});

  final Panda obd;
  final bool minor; // 12 V and the rest (a switch in the settings hides them)
  final double size; // [_statRow]'s

  @override
  Widget build(BuildContext context) {
    final o = obd, live = o.wifiLive;
    String kw(double? v) => !live || v == null ? '—' : '${v.toStringAsFixed(1)} kW';
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _statRow(context, 'CLIMATE', kw(o.climateKw), size: size),
      if (minor) ...[
        _statRow(context, '12 V', kw(o.lvKw), size: size),
        _statRow(context, 'OTHER', kw(o.otherKw), size: size),
      ],
    ]);
  }
}

/// While charging: to what % and by when, as the nav puts a route.
/// WiFi only.
class _Charge extends StatelessWidget {
  const _Charge({required this.obd, this.oneLine = false, this.size = 1});

  final Panda obd;
  final bool oneLine; // the compact dash: one row under the ring
  final double size; // over the full layout's, as [_statRow]'s

  @override
  Widget build(BuildContext context) {
    final o = obd;
    if (!o.wifiLive || !o.charging) return const SizedBox.shrink();
    final big = TextStyle(
        fontSize: 18 * size, color: Colors.white, fontFeatures: const [FontFeature.tabularFigures()]);
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
      Text('CHARGE',
          style: TextStyle(fontSize: 12 * size, letterSpacing: 1.5 * size, color: Colors.white70)),
      SizedBox(height: 2 * size),
      if (to != null) Text(to, style: big),
      if (when != null) FittedBox(fit: BoxFit.scaleDown, child: Text(when, style: big)),
    ]);
  }
}

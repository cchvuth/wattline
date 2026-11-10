import 'dart:async';
import 'dart:io' show File;
import 'dart:math' show atan2, cos, max, min, pi, sin, tan;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'car_panel.dart';
import 'changelog.dart';
import 'commander.dart';
import 'gauge.dart';
import 'glyphs.dart';
import 'panda.dart';
import 'signals.dart' show kSubscribeIds;
import 'diag.dart';
import 'update.dart';

part 'widgets.dart';

// The Commander's panda endpoint. Turn it on first: S3XY Buttons app ->
// Commander Settings -> ScanMyTesla support, then join the `S3XY_OBD` wifi
// (password 12345678). Editable in the app and remembered.
const kDefaultHost = '192.168.4.1';
const kDefaultPort = 1338;
const kDefaultSsid = 'S3XY_OBD';
const kDefaultPassword = '12345678';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DashApp());
}

/// The app's look; the layout tests render with it too.
final kTheme = ThemeData.dark(useMaterial3: true).copyWith(
  scaffoldBackgroundColor: Colors.black,
  textTheme: ThemeData.dark().textTheme.apply(fontFamily: kFont),
  // The landscape screen is short: 8 dp clear above and below a dialog,
  // not 24, leave the field being typed in room above a tall keyboard.
  dialogTheme: const DialogThemeData(
      insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 8)),
);

class DashApp extends StatelessWidget {
  const DashApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wattline',
        debugShowCheckedModeBanner: false,
        theme: kTheme,
        home: const DashPage(),
      );
}

/// What the basic layout reads off the bus: the ring, its centre and the
/// edge glows always ([kBasicBase]), and each card its own ([kBasicCards],
/// in the cards' order); the rest is not asked for while no side shows it.
const kBasicBase = {
  0x257, 0x118, 0x2E5, 0x266, 0x132, 0x252, 0x185, // speed, gear/pedal/brake lamp, power, regen cap, brake
  0x2A7, 0x2B4, 0x2B3, // climate and 12 V draws: the ring's motor split takes them off the pack
  0x399, 0x3F5, 0x286, 0x3F8, // limit, blind spots and assist, indicators, cruise set and gap
  0x321, // washer fluid low under the speed (and the air outside)
  0x212, 0x472, // charging: the centre's charge power and why it is capped
};
const kBasicCards = <Set<int>>[
  {0x33A, 0x332, 0x352, 0x392, 0x3A1, 0x347, 0x333, 0x33B}, // energy: battery, pack heat, health, charge
  {0x3F6, 0x2B6, 0x101}, // drive: lamps, grip, g-meter (yaw)
  {0x3A1, 0x3C2, 0x31A, 0x2F3, 0x25A, 0x219, 0x129, 0x101, 0x3F6}, // car: belts, fans, tyres, path lines (moving: yaw), lamps
  {0x102, 0x103, 0x2E1, 0x25D, 0x273, 0x3E2, 0x243}, // buttons: doors, trunk, frunk, port, tilt, lights, recirc
  {0x238, 0x347, 0x3FD, 0x33A, 0x352}, // route: on a route, energy and minutes, battery now
  {0x33A}, // power: the pack's draw (the ring's frames), the battery and range
];

/// The basic layout's cards over the full layout's size on screen: the
/// figures and the route a little bigger, the buttons more.
const kBasicFigures = 1.1, kBasicButtons = 1.22;

/// The power ring's alone and streamed: the brake torque (44 a second), not
/// asked for while basic's ring shows the speedometer. (The regen cap is
/// polled and slow: kept, so it is fresh on the swipe back.)
const kPowerRingOnly = {0x185};

/// The ids the basic layout has no use for with these two cards showing
/// ([speedo]: and the speedometer on the ring).
Set<int> basicSkip(int left, int right, {bool speedo = false}) {
  // Off the ring's own ids only: a card that needs one keeps it.
  final need = {...speedo ? kBasicBase.difference(kPowerRingOnly) : kBasicBase, ...kBasicCards[left], ...kBasicCards[right]};
  return {for (final id in kSubscribeIds) if (!need.contains(id)) id};
}

class DashPage extends StatefulWidget {
  const DashPage({super.key, this.demo, this.bt, this.basic = false});

  /// Pre-populated state instead of a live link. Lets the layout be rendered
  /// offline (see test/dash_shot_test.dart) without a car or a dongle.
  final Panda? demo;
  final Commander? bt;

  /// The basic layout from the start (the saved choice overrides it live).
  final bool basic;

  @override
  State<DashPage> createState() => _DashPageState();
}

class _DashPageState extends State<DashPage> {
  late final Panda _obd = widget.demo ?? Panda();
  late final Commander _bt = widget.bt ?? Commander();
  String _host = kDefaultHost;
  int _port = kDefaultPort;
  String _ssid = kDefaultSsid;
  String _password = kDefaultPassword;
  // The gaps around a WiFi stream's start (see [_stepAside]), in ms, tuned
  // in the WiFi dialog: after Bluetooth steps aside, before the hello; once
  // the stream is live, before Bluetooth is back with the buttons and before
  // it takes car data again (1 s, at once and 5 s held in the car; with the
  // switch on, one wait for both); and should no stream come, before
  // Bluetooth is back (not with the switch on: it waits for the stream).
  // Defaults: the owner's tuned settings from the car.
  int _settleMs = 3000, _buttonsMs = 500, _rejoinMs = 2000, _backMs = 15000;
  bool _wifiFirst = true; // Bluetooth waits for the WiFi stream, however long
  bool _smooth = false; // the power ring and pedal line glide on every change
  bool _minor = false; // the full layout's 12 V, other power and cell imbalance (off by default; basic shows them)
  late bool _basic = widget.basic; // basic layout: the ring between two stacks of big cards
  int _cardLeft = 0, _cardRight = 3; // the card each side shows: energy, the buttons
  int _ringPage = 0; // basic's ring: the power ring, or the speedometer
  bool _sparse = true; // slow ids polled rather than streamed (see Panda.sparse)
  int _lookMs = 3000; // the slider's look time; with the switch on the look has none

  /// What the look waits: the slider's time, or with the switch on, for the
  /// network however long, as Bluetooth waits for the stream just as long.
  void _applyLook() => _obd.lookMs = _wifiFirst ? 0 : _lookMs;

  /// How long after the stream goes live Bluetooth comes back. It first came
  /// back with the buttons and took its data after a second wait; with the
  /// switch on it has not been up before the stream, so its start and its
  /// data are one sequence and the data's wait stands for both. The dialog's
  /// merged slider is that same value: tuning it there retunes the data wait
  /// for when the switch is off.
  int get _startMs => _wifiFirst ? _rejoinMs : _buttonsMs;

  void _connect({bool now = false}) =>
      _obd.connect(_host, _port, ssid: _ssid, password: _password, now: now);

  @override
  void initState() {
    super.initState();
    _bt.onData = _obd.fromBt; // the Commander's data stands in for WiFi's
    if (widget.demo == null) _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('host') ?? kDefaultHost;
    _port = prefs.getInt('port') ?? kDefaultPort;
    _ssid = prefs.getString('ssid') ?? kDefaultSsid;
    _password = prefs.getString('password') ?? kDefaultPassword;
    _settleMs = prefs.getInt('btSettleMs') ?? _settleMs;
    _buttonsMs = prefs.getInt('btButtonsMs') ?? _buttonsMs;
    _rejoinMs = prefs.getInt('btRejoinMs') ?? _rejoinMs;
    _backMs = prefs.getInt('btBackMs') ?? _backMs;
    _wifiFirst = prefs.getBool('btWifiFirst') ?? _wifiFirst;
    _smooth = prefs.getBool('smoothRing') ?? _smooth;
    _minor = prefs.getBool('minorFigures') ?? _minor;
    _basic = prefs.getBool('basic') ?? _basic;
    // A card saved by a build with more of them: the last there is.
    _cardLeft = (prefs.getInt('cardLeft') ?? _cardLeft).clamp(0, kBasicCards.length - 1);
    _cardRight = (prefs.getInt('cardRight') ?? _cardRight).clamp(0, kBasicCards.length - 1);
    _ringPage = (prefs.getInt('ringPage') ?? _ringPage).clamp(0, 1); // the power ring or the speedometer
    _sparse = prefs.getBool('sparsePolling') ?? _sparse;
    _obd.sparse = _sparse;
    _applyCar(prefs.getString('car') ?? 'modelY7'); // the owner's, by default
    // Inside the slider's range, whatever was stored.
    _lookMs = (prefs.getInt('wifiLookMs') ?? _lookMs).clamp(1000, 10000).toInt();
    _applyLook();
    // The last pressures seen: the car sends them only on the move and shows
    // its stored ones when parked, as the dash then does too.
    final t = prefs.getStringList('tyres');
    if (t != null && t.length == 4) {
      final v = [for (final s in t) double.tryParse(s)];
      _obd
        ..tpFL ??= v[0]
        ..tpFR ??= v[1]
        ..tpRL ??= v[2]
        ..tpRR ??= v[3];
    }
    _tyres = [_obd.tpFL, _obd.tpFR, _obd.tpRL, _obd.tpRR];
    if (!mounted) return; // closed while loading: nothing to listen for
    setState(() {});
    // The first launch's pages until all are through: closed midway (the
    // phone may close the dash while the S3XY app is open), they come again.
    final firstRun = prefs.getString('car') == null || prefs.getBool('setupDone') == false;
    _obd.addListener(_linksChanged);
    _obd.addListener(_saveTyres);
    _obd.addListener(_tellMoving);
    _bt.addListener(_linksChanged);
    // Back in front (phone woke, or the S3XY app was used): try both now.
    _life = AppLifecycleListener(onResume: () {
      _obd.kick();
      _bt.kick();
      // Back from allowing installs: the update carries on, once (the
      // settings keep the button).
      final install = _installOnReturn;
      _installOnReturn = false;
      if (install) canInstallUpdates().then((ok) => ok ? _installUpdate() : null);
      // Back from Android's installer, its confirmation answered or left
      // behind (Home): a tap may start over.
      if (_handedOver) _installing = _handedOver = false;
    });
    // Bluetooth first, then the WiFi stream, took the Commander down; the
    // other way round held. So each new stream waits for Bluetooth to step
    // aside, and Bluetooth comes back once the stream runs.
    _obd.beforeStream = _stepAside;
    // And a Bluetooth link made before WiFi's try had the Commander switch
    // its WiFi off: no dial starts mid-try, at start, back in front or on a
    // retry ([_btWaitsFor]).
    _bt.waitFor = _btWaitsFor;
    // First launch: which car, then how to set up both links, before either
    // starts, so the phone's permission prompts come after the page that
    // says what they are for.
    if (firstRun && mounted) {
      prefs.setBool('setupDone', false);
      await _askCar();
      await _askLayout();
      await _setupHelp();
      if (!mounted) return;
      prefs.setBool('setupDone', true);
    }
    _connect();
    _linksStarted = true;
    _bt.connect();
    _startTrace();
    _checkUpdate();
    _whatsNew(prefs, firstRun);
  }

  /// After an update, what changed since the version last run, or the whole
  /// changelog to one who never saw it; none on a first launch (Android, the
  /// one platform that tells the app its version). The version is kept for
  /// the next start.
  Future<void> _whatsNew(SharedPreferences prefs, bool firstRun) async {
    await loadBuild();
    final current = versionOf(diagBuild);
    if (current == null) return;
    final last = prefs.getString('lastVersion');
    if (last == current || (last != null && isNewer(last, current))) return; // the same, or rolled back
    final news = firstRun ? const <Change>[] : changesSince(last, current);
    if (news.isNotEmpty) {
      await _calm(); // never over the dash on the move, nor over the approval prompt
      if (!mounted) return;
      // Closed (once) by the car as it leaves P, or by an approval prompt:
      // unread, it comes again at the next start.
      var cut = false;
      void close() {
        if (cut || !mounted) return;
        // A gear actually out of P (a stale one, as in a stall, is not).
        if ((_obd.live && const {'D', 'R', 'N'}.contains(_obd.gear)) || _approval != null) {
          cut = true;
          Navigator.of(context).pop();
        }
      }

      // An update offer up now would sit unseen behind it: offered again on
      // close. While it is open the offer waits (its listener stays on).
      final covered = _offeredAt != null && DateTime.now().difference(_offeredAt!) < _offerFor;
      _changelogOpen = true;
      _obd.addListener(close);
      _bt.addListener(close);
      await showWhatsNew(context, news);
      _obd.removeListener(close);
      _bt.removeListener(close);
      _changelogOpen = false;
      if (covered) {
        _obd.addListener(_offerUpdate); // now, or at the next stop if moving
        _offerUpdate();
      }
      if (cut) return;
    }
    await prefs.setString('lastVersion', current); // seen (or nothing to see)
  }

  bool _changelogOpen = false;
  DateTime? _offeredAt; // the update offer's snackbar, last shown
  static const _offerFor = Duration(seconds: 12); // how long it stays up

  /// Done once a stream (WiFi or Bluetooth) says P, with the dash in front
  /// and no approval prompt up. Without a stream it waits: unseen, the
  /// changelog comes again at the next start.
  Future<void> _calm() {
    final done = Completer<void>();
    late final Timer poll;
    poll = Timer.periodic(const Duration(seconds: 1), (_) {
      // The dash in front: nothing pushed over it (no dependency on the route,
      // which would redraw the dash each time a dialog comes or goes).
      if (!mounted || (_obd.live && _obd.parked && _approval == null && !Navigator.of(context).canPop())) {
        poll.cancel();
        done.complete();
      }
    });
    return done.future;
  }

  /// Why Bluetooth is not to start a link now, or null ([Commander.waitFor]).
  /// By default it waits out WiFi's tries; with the dialog's switch on, for
  /// the WiFi stream itself, however long.
  String? _btWaitsFor() => _wifiFirst
      ? _obd.wifiLive ? null : 'waiting for WiFi to go live'
      : _obd.trying ? 'waiting for WiFi to try first' : null;

  Timer? _btBack, _btButtons;

  /// A line a second to trace.log in the app's external files folder, to read
  /// a drive afterwards over adb:
  /// adb pull /sdcard/Android/data/io.github.cchvuth.wattline/files/trace.log
  /// Rolls to trace.log.1 past 50 MB, so the two stay under 100 MB (about 9
  /// hours of driving each, at 5.4 MB an hour).
  File? _traceFile;
  Timer? _traceTimer;

  Future<void> _startTrace() async {
    // ponytail: Android only; iOS would need path_provider and a file-sharing key.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final f = await traceLog();
    if (f == null || !mounted) return; // no folder (tests): no trace
    _traceFile = f;
    await loadBuild();
    if (!mounted) return;
    _trace('start: build=$diagBuild sparse=$_sparse car=${_obd.thirdRow ? 7 : 5}${_obd.rwd ? 'rwd' : 'awd'} wifiFirst=$_wifiFirst look=${_lookMs}ms settle=${_settleMs}ms buttons=${_buttonsMs}ms '
        'data=${_rejoinMs}ms back=${_backMs}ms');
    _traceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _trace('${_obd.traceLine()} | bt ${_bt.link.name} "${_bt.status}" wait=${_btWaitsFor()} push=${_bt.pushInfo}');
      // Twice a minute the whole Diagnostics report and every signal.
      if (t.tick % 30 == 0 && (_obd.frames.isNotEmpty || _obd.viaBt)) _trace('${_obd.traceDump()}\n${diagReport(_obd, _bt)}');
    });
  }

  void _trace(String line) => traceWrite(_traceFile!, '${DateTime.now().toIso8601String()} $line\n');
  bool _streamSeen = true; // the last step-aside was followed by a stream

  /// Before a WiFi stream starts: Bluetooth off the Commander (see
  /// [Commander.pause]), and back once the stream is live ([_linksChanged])
  /// or, should it never be, after a while.
  Future<void> _stepAside() async {
    // iOS cannot tell whether S3XY_OBD is joined, so every WiFi retry gets
    // here, ScanMyTesla off too, and Bluetooth (then the whole dash) would
    // never stay up. Once a step-aside brought no stream, none until one
    // shows. ponytail: a retry after that goes out with Bluetooth up.
    if (!_streamSeen && defaultTargetPlatform == TargetPlatform.iOS) return;
    _streamSeen = false;
    _btBack?.cancel();
    _btButtons?.cancel(); // the last stream's, still waiting: not into this one's start
    // Back only once the stream runs ([_linksChanged]): with the buttons, and
    // the data after its wait.
    _bt.dataHold = true;
    // Not with the switch on: Bluetooth waits for the stream however long, and
    // a Bluetooth resumed early would dial the instant the stream goes live.
    _bt.resumeAt = _wifiFirst ? null : DateTime.now().add(Duration(milliseconds: _backMs));
    if (!_wifiFirst) {
      _btBack = Timer(Duration(milliseconds: _backMs), () {
        _bt.dataHold = false; // no stream came: Bluetooth carries the dash
        _bt.resume();
      });
    }
    // A link was up: give the Commander a moment before the hello.
    if (await _bt.pause()) await Future<void>.delayed(Duration(milliseconds: _settleMs));
  }

  AppLifecycleListener? _life;
  List<double?> _tyres = const [null, null, null, null];

  /// Keeps new pressures for the next start (see [_load]).
  void _saveTyres() {
    final o = _obd, t = [o.tpFL, o.tpFR, o.tpRL, o.tpRR];
    if (listEquals(t, _tyres)) return;
    _tyres = t;
    SharedPreferences.getInstance()
        .then((p) => p.setStringList('tyres', [for (final v in t) v?.toString() ?? '']));
  }
  /// The cars offered: a 7-seat Model Y comes with two motors only; a
  /// 5-seat one with one (RWD) or two.
  static const _cars = {'modelY5rwd': '5 seats RWD', 'modelY5': '5 seats AWD', 'modelY7': '7 seats'};

  /// The car as picked: a 5-seater's third row leaves the seat map, a
  /// rear-motor car's front leaves the ring; and back.
  void _applyCar(String car) => _obd
    ..thirdRow = car == 'modelY7'
    ..rwd = car == 'modelY5rwd';
  String get _car => _obd.thirdRow ? 'modelY7' : _obd.rwd ? 'modelY5rwd' : 'modelY5';

  /// Which car: a picture of each layout to tap, then for a 5-seater its
  /// drive. Asked on the first launch; the settings change it after. Back
  /// asks again (from the drive, the car): the dash needs the car.
  Future<void> _askCar() async {
    while (true) {
      if (!mounted) return;
      final seven = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: const Text('Which car do you have?'),
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final s in [false, true])
              InkWell(
                onTap: () => Navigator.pop(ctx, s),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(children: [
                    CarSeats(thirdRow: s, height: 150),
                    const SizedBox(height: 8),
                    Text('Model Y\n${s ? 7 : 5} seats', textAlign: TextAlign.center),
                  ]),
                ),
              ),
          ]),
        ),
      );
      if (!mounted) return;
      if (seven == true) return _setCar('modelY7');
      if (seven == false) {
        final rwd = await _choose('Which drive?', const [
          (true, 'Rear-wheel drive', 'one motor'),
          (false, 'All-wheel drive', 'two motors'),
        ]);
        if (rwd != null && mounted) return _setCar(rwd ? 'modelY5rwd' : 'modelY5');
      }
    }
  }

  /// A first-launch question: each option its label and what it means.
  Future<T?> _choose<T>(String title, List<(T, String, String)> options) => showDialog<T>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SimpleDialog(
          title: Text(title),
          children: [
            for (final (value, label, about) in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, value),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Text('$label ($about)', style: const TextStyle(fontSize: 18)),
              ),
          ],
        ),
      );

  /// Which layout, on the first launch (the settings switch it later):
  /// everything at once, or basic's bigger cards.
  Future<void> _askLayout() async {
    if (!mounted) return;
    // Each as it looks, to tap, as the car's question has its pictures.
    final basic = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Which layout?'),
        // Halves of what room there is: a narrower screen shrinks them.
        content: SizedBox(
          width: 600,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (basic, label, about, shot) in const [
            (false, 'Full', 'everything at once', 'cold-morning'),
            (true, 'Basic', 'bigger text on three cards, left, centre and right; swipe any for the next', 'basic-1'),
          ])
            Expanded(
              child: InkWell(
                onTap: () => Navigator.pop(ctx, basic),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 6, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8), child: Image.asset('assets/whatsnew/$shot.jpg')),
                    Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(about, style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
    if (basic != null && mounted) await _setBasic(basic);
  }

  /// The basic layout on or off, kept: the first launch's question, the
  /// settings' switch and the gear's tap.
  Future<void> _setBasic(bool on) async {
    setState(() => _basic = on);
    (await SharedPreferences.getInstance()).setBool('basic', on);
  }

  /// How to turn on the Commander's WiFi stream (ScanMyTesla) in the S3XY
  /// app, with its own screens. After the car on the first launch; the
  /// settings link back to it ([_setupHelp]).
  Future<void> _smtHelp() async {
    if (!mounted) return;
    Widget step(String text, String image, [String? then]) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(image)),
            if (then != null) ...[const SizedBox(height: 16), Text(then)],
          ]),
        );
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, redraw) => AlertDialog(
        scrollable: true,
        title: const Text('Turn on ScanMyTesla'),
        content: SizedBox(
          width: 620,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The third step under the first, where the shorter picture leaves room.
            step('1. In the S3XY app, open Commander, then Scan My Tesla.', 'assets/smt/step1.jpg',
                // An iPhone joins in Settings; Android's dash joins by itself.
                defaultTargetPlatform == TargetPlatform.iOS
                    ? '3. In Settings, join the $_ssid WiFi (password $_password); the dash finds it there.'
                    : '3. That\'s all: the dash joins the $_ssid WiFi by itself. Allow it if the phone asks.'),
            const SizedBox(width: 20),
            step('2. Turn on ScanMyTesla support and ScanMyTesla Always ON.', 'assets/smt/step2.jpg'),
          ]),
        ),
        actions: [
          // Not the standard name and password: they go in before the first try.
          TextButton(
            onPressed: () async {
              await _wifiLoginDialog();
              redraw(() {});
            },
            child: const Text('Changed the WiFi name or password?'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      )),
    );
  }

  /// The links have been started: a changed WiFi name or password then
  /// reconnects at once, not at the end of the first-launch pages.
  bool _linksStarted = false;

  /// The Commander's WiFi name and password, for a Commander whose were
  /// changed in the S3XY app: asked inside the setup pages, before the first
  /// connection, where a wrong password would otherwise only fail.
  Future<void> _wifiLoginDialog() async {
    final ssid = TextEditingController(text: _ssid);
    final password = TextEditingController(text: _password);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('The Commander\'s WiFi'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('As set in the S3XY app. Its standard name is $kDefaultSsid, '
              'its standard password $kDefaultPassword.'),
          TextField(controller: ssid, decoration: const InputDecoration(labelText: 'WiFi name')),
          TextField(controller: password, decoration: const InputDecoration(labelText: 'WiFi password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final name = ssid.text.trim(), pass = password.text;
    // After the dialog's exit animation, which still builds its fields.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      ssid.dispose();
      password.dispose();
    });
    if (ok != true) return;
    await _saveWifi(name, pass);
    if (_linksStarted) _connect(now: true);
  }

  /// Keeps the WiFi login (an empty name is the standard one).
  Future<void> _saveWifi(String name, String password) async {
    _ssid = name.trim().isEmpty ? kDefaultSsid : name.trim();
    _password = password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssid', _ssid);
    await prefs.setString('password', _password);
  }

  /// A newer release on GitHub, once looked for at start (Android only).
  Update? _update;

  Future<void> _checkUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _obd.onUpdateFailed = (why) {
      _installing = false;
      _say(why.contains('ABORTED') || why == 'cancelled' ? 'Update cancelled' : 'Update not installed: $why');
    };
    await loadBuild();
    final u = await checkUpdate(diagBuild);
    if (u == null || !mounted) return;
    setState(() => _update = u);
    _obd.addListener(_offerUpdate);
    _offerUpdate();
  }

  /// Offers the update once, never on the move: at once when parked or with
  /// no stream, else at the next stop in P. The settings keep the button.
  void _offerUpdate() {
    final u = _update;
    if (u == null || !mounted || _installing || _changelogOpen || (_obd.live && !_obd.parked)) return;
    _obd.removeListener(_offerUpdate);
    _offeredAt = DateTime.now();
    _say('Wattline ${u.version} is available',
        duration: _offerFor, action: SnackBarAction(label: 'UPDATE', onPressed: _installUpdate));
  }

  /// Allowed to install apps first: going to Settings mid-install cancels
  /// Android's install, so the permission comes before the download, and
  /// the update carries on when the app is back in front ([_life]).
  Future<void> _installUpdate() async {
    final u = _update;
    if (u == null || _installing) return; // one download at a time
    if (_obd.live && !_obd.parked) {
      _say('Shift to P to update'); // Android's installer closes the dash
      return;
    }
    // The tap's word on moving, as the guard's: a link lost on the move and
    // never back would hold Android's confirmation for good ([_tellMoving]).
    if (_movingTold) setMoving(_movingTold = false);
    _installOnReturn = false;
    _installing = true; // across the check too: a second tap is turned away
    if (!await canInstallUpdates()) {
      _installing = false;
      _installOnReturn = true;
      _say('Allow Wattline to install updates, then come back here');
      await allowInstallUpdates();
      return;
    }
    // Busy until Android's installer is done: it replaces the app, or says
    // why not ([Panda.onUpdateFailed]); a download that fails says so here.
    _handedOver = false;
    _obd.removeListener(_offerUpdate); // started from the settings: no offer at the next stop
    _say('Downloading Wattline ${u.version}…');
    final err = await installUpdate(u);
    if (err == null) {
      _handedOver = true;
    } else if (worthRetrying(err)) {
      _installing = false;
      _say('Update download failed ($err): try again in a few minutes',
          duration: const Duration(seconds: 10), action: SnackBarAction(label: 'RETRY', onPressed: _installUpdate));
    } else {
      _installing = false;
      _say('Update not installed: $err');
    }
  }

  bool _installOnReturn = false, _installing = false, _handedOver = false;

  bool _movingTold = false;

  /// Android's install confirmation waits while the car moves ([setMoving]):
  /// a link lost on the move is no stop, so only a live gear changes it.
  void _tellMoving() {
    if (!_obd.live) return;
    final m = !_obd.parked;
    if (m != _movingTold) setMoving(_movingTold = m);
  }

  /// A message in the snackbar, in place of the last; behind the approval
  /// prompt while that is up, as the car is waiting on it.
  void _say(String text, {Duration duration = const Duration(seconds: 4), SnackBarAction? action}) {
    if (!mounted) return;
    final bar = ScaffoldMessenger.of(context);
    if (_approval == null) bar.hideCurrentSnackBar();
    bar.showSnackBar(SnackBar(content: Text(text), duration: duration, action: action));
  }

  /// Both setup pages: the WiFi stream's, then the Bluetooth link's.
  Future<void> _setupHelp() async {
    await _smtHelp();
    await _btHelp();
  }

  /// The Bluetooth link, for the buttons: one phone at a time, approved once
  /// in the car; what the phone asks for and why; and the S3XY Dash.
  Future<void> _btHelp() async {
    if (!mounted) return;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Connect the buttons'),
        content: SizedBox(
          width: 620,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: [
            const Text('1. Close the S3XY app. The Commander takes one phone at a time over Bluetooth, '
                'and the dash\'s buttons need it.'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: 16, children: [
              const Expanded(
                  child: Text('2. The first time, approve this phone in the car: double-press the right '
                      'scroll wheel when the car asks.')),
              Image.asset('assets/bt/wheel.png', width: 190),
            ]),
            Text(ios
                ? '3. The phone then asks for Bluetooth, for the Commander, and the local network, '
                    'for its $kDefaultSsid WiFi.'
                : '3. The phone then asks for nearby devices, for the Commander\'s Bluetooth, and '
                    'location: Android lets an app find a WiFi network or a Bluetooth device only with '
                    'it. The dash uses both for the Commander alone.'),
            const Text('Have an S3XY Dash? It goes blank while ScanMyTesla is on: the Commander drops '
                'its own link to the car in that mode.',
                style: TextStyle(color: Colors.white70)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  Future<void> _setCar(String car) async {
    if (mounted) setState(() => _applyCar(car));
    (await SharedPreferences.getInstance()).setString('car', car);
  }

  bool _wasLive = false, _wasReady = false, _wasApproving = false;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _approval;

  void _linksChanged() {
    _bt.wifiLive = _obd.wifiLive;
    // The stream runs: Bluetooth back on after a moment, onto a Commander
    // already streaming. Either link reaching the Commander means it is
    // awake: the other one tries without waiting out its backoff.
    if (_obd.wifiLive && !_wasLive) {
      _streamSeen = true;
      _btBack?.cancel();
      _btButtons?.cancel(); // a quiet link back: not a second one beside it
      // Bluetooth comes back after [_startMs]. Switch off: with the buttons
      // only (at once by default), and what WiFi lacks after the data's own
      // wait, on the same link. Switch on: one wait, and it comes back already
      // with its data, the hold lifting at that same moment.
      _bt.resumeAt = DateTime.now().add(Duration(milliseconds: _startMs));
      _btButtons = Timer(Duration(milliseconds: _startMs), () {
        _bt.resume();
        _bt.kick();
      });
      _bt.dataAt = DateTime.now().add(Duration(milliseconds: _rejoinMs));
      _btBack = Timer(Duration(milliseconds: _rejoinMs), () => _bt.dataHold = false);
    }
    if (_bt.ready && !_wasReady) _obd.kick(); // it still scans: no WiFi with ScanMyTesla off
    final flipped = _bt.approving != _wasApproving;
    _wasLive = _obd.wifiLive;
    _wasReady = _bt.ready;
    _wasApproving = _bt.approving;

    // The one step that needs a hand: say so until it is done. Another
    // message may have replaced the prompt meanwhile; only close our own.
    if (!flipped || !mounted) return;
    _approval?.close();
    _approval = null;
    if (!_bt.approving) return;
    // Cleared first, so the prompt is the current bar and close() is safe.
    final bar = (ScaffoldMessenger.of(context)..clearSnackBars()).showSnackBar(SnackBar(
      duration: const Duration(minutes: 2),
      content: Row(spacing: 16, children: [
        Image.asset('assets/bt/wheel.png', height: 72), // the scroll wheel to press
        const Expanded(
            child: Text('Approve this phone for the Commander: in the car, double-press the right scroll wheel')),
      ]),
    ));
    bar.closed.then((_) {
      if (identical(_approval, bar)) _approval = null;
    });
    _approval = bar;
  }

  @override
  void dispose() {
    _traceTimer?.cancel();
    _btBack?.cancel();
    _btButtons?.cancel();
    _life?.dispose();
    if (widget.demo == null) _obd.dispose(); // only what we created
    if (widget.bt == null) _bt.dispose();
    super.dispose();
  }

  /// Google Maps in the other half of the screen; the dash then lays itself
  /// out for the half it keeps (see [_Compact]).
  Future<void> _maps() async {
    final r = await const MethodChannel('tesla_dash/net')
        .invokeMethod<String>('openMaps')
        .catchError((_) => 'missing');
    // The first time, Android asks to let the app hold the split landscape.
    final say = switch (r) {
      'opened' => null,
      'asked' => 'Allow Wattline to modify system settings, so split screen '
          'stays landscape, then tap the map again',
      _ => 'Google Maps is not installed',
    };
    if (say != null) _say(say, duration: const Duration(seconds: 10));
  }

  /// The Bluetooth icon: try the link now, and the settings, which say what
  /// it is doing.
  void _btStatus() {
    if (_approval != null) return; // the approval prompt already says it all
    if (!_bt.ready) _bt.kick(ask: true);
    _settings();
  }

  /// Presses an S3XY function over Bluetooth. Frunk and trunk only in P: a
  /// lid rising at speed blinds the driver, whatever the car would allow.
  Future<void> _press(S3xyAction a) async {
    String? err;
    if (!_bt.ready) {
      _bt.kick(ask: true); // look now, and offer to switch Bluetooth on
      err = 'Commander Bluetooth: ${_bt.status}';
    } else if (a.opens && !_obd.parked) {
      err = const {'R', 'N', 'D'}.contains(_obd.gear)
          ? '${a.label} opens in P only'
          : _bt.dash && !_obd.live
              ? '${a.label}: no gear while the S3XY Dash has the car data (turn ScanMyTesla on)'
              : '${a.label}: gear unknown — no live data';
    } else if (a == S3xyAction.mirrorTilt && const {'P', 'N', 'D'}.contains(_obd.gear)) {
      err = 'Mirror tilt acts in R only'; // S3XY: auto-tilt override, Reverse
    } else {
      _obd.pressed();
      try {
        await _bt.tryAction(a);
      } catch (e) {
        err = '${a.label}: $e';
      }
    }
    // While approving, the approval prompt already says what is needed, if
    // it is still up.
    if (err == null || (_bt.approving && _approval != null)) return;
    _say(err);
  }

  Future<void> _settings() async {
    final scroll = ScrollController();
    final host = TextEditingController(text: _host);
    final port = TextEditingController(text: '$_port');
    final ssid = TextEditingController(text: _ssid);
    final password = TextEditingController(text: _password);
    // A gap, in seconds, on a slider; it applies and is kept on release.
    Widget gap(String label, int ms, double maxS, String key, void Function(int) set, StateSetter redraw,
            {bool on = true, double min = 0}) =>
        Row(children: [
          Expanded(child: Text('$label: ${(ms / 1000).toStringAsFixed(1)} s')),
          SizedBox(
            width: 240,
            child: Slider(
              value: ms / 1000,
              min: min,
              max: maxS,
              divisions: ((maxS - min) * 10).round(), // 100 ms steps
              onChanged: on ? (v) => redraw(() => set((v * 1000).round())) : null,
              onChangeEnd: (v) async =>
                  (await SharedPreferences.getInstance()).setInt(key, (v * 1000).round()),
            ),
          ),
        ]);
    // A switch row: [set] applies it at once, kept under [key] (or by [set]).
    Widget toggle(String label, bool value, void Function(bool) set, StateSetter redraw, {String? key}) =>
        Row(children: [
          Expanded(child: Text(label)),
          Switch(
            value: value,
            onChanged: (v) async {
              set(v); // may be async (the layout's own save): outside setState
              redraw(() {});
              setState(() {});
              if (key != null) (await SharedPreferences.getInstance()).setBool(key, v);
            },
          ),
        ]);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, redraw) => AlertDialog(
        // The padding scrolls too, so a big keyboard leaves room for the
        // buttons alone; the bar at the dialog's edge.
        contentPadding: EdgeInsets.zero,
        // The landscape screen is short: the fields go two to a row to fit
        // above the buttons, and the rest scrolls, with a bar that shows
        // there is more. The title scrolls with it: fixed, it pushed the
        // buttons under a keyboard taking half the screen.
        content: Scrollbar(
          controller: scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Commander link', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
          // What the WiFi icon stands for.
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                _obd.wifiLive
                    ? 'Live: ${_obd.speedHz} speed frames/s (the car sends about 50), ${_obd.frameHz} frames/s in all, from $_host:$_port'
                    : _obd.status,
                style: const TextStyle(color: Colors.white70)),
          ),
          // And what the Bluetooth icon stands for.
          Align(
            alignment: Alignment.centerLeft,
            child: ListenableBuilder(
              listenable: _bt,
              builder: (context, _) => Text(
                  _bt.ready
                      ? 'Commander Bluetooth: connected. Car data: ${_bt.pushInfo}, ${_bt.pushCount} pushes. ${_bt.carLink}.'
                      : 'Commander Bluetooth: ${_bt.status}',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(children: [ // onto a second line rather than off a narrow screen
              // A WiFi login changed there is the one to keep: the fields
              // here take it, or saving would put the old one back. Not
              // changed, what is typed here stays.
              TextButton(
                  onPressed: () async {
                    final was = (_ssid, _password);
                    await _setupHelp();
                    if ((_ssid, _password) != was) {
                      ssid.text = _ssid;
                      password.text = _password;
                    }
                  },
                  child: const Text('Setup steps')),
              // Every release (the changelog is this build's).
              TextButton(onPressed: () => showWhatsNew(context, kChangelog), child: const Text("What's new")),
              if (_update case final u?)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _installUpdate();
                  },
                  child: Text('Update to ${u.version}'),
                ),
            ]),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ssid,
                decoration: const InputDecoration(labelText: 'WiFi name'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: password,
                decoration: const InputDecoration(labelText: 'WiFi password'),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: host,
                decoration: const InputDecoration(labelText: 'Host'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port'),
              ),
            ),
          ]),
          // How long the look for the network waits for the phone's scan, at
          // most: it answers on the first results that hold the network. Not
          // below 1 s, which only reads the scan before (a miss, or a stale
          // yes). None with the switch on: the look then has no limit, as
          // Bluetooth has none. Android only: iOS joins in Settings.
          if (defaultTargetPlatform == TargetPlatform.android && !_wifiFirst)
            gap('WiFi scan time', _lookMs, 10, 'wifiLookMs',
                (v) { _lookMs = v; _applyLook(); }, redraw, min: 1),
          // Bluetooth never starts a link while WiFi is mid-try. This holds it
          // back until the WiFi stream runs, however long: for a Commander
          // that drops its WiFi when Bluetooth comes first. With no WiFi
          // stream (ScanMyTesla off) there is then no Bluetooth either. It also
          // takes the time limit off WiFi's look for the network.
          const SizedBox(height: 8),
          toggle('Bluetooth waits for the WiFi stream, no time limit', _wifiFirst, (v) {
            _wifiFirst = v;
            _applyLook();
            _obd.relook(); // a look in progress takes the new limit now
          }, redraw, key: 'btWifiFirst'),
          // Bluetooth stays off the Commander while its WiFi stream starts:
          // the dash has no buttons for that spell, shorter if these hold.
          gap('Bluetooth off before WiFi starts', _settleMs, 5, 'btSettleMs',
              (v) => _settleMs = v, redraw),
          // Two waits, the buttons then the data; one with the switch on
          // (see [_startMs]).
          if (!_wifiFirst)
            gap('Bluetooth buttons after WiFi is live', _buttonsMs, 10, 'btButtonsMs',
                (v) => _buttonsMs = v, redraw),
          gap(_wifiFirst ? 'Bluetooth after WiFi is live' : 'Bluetooth data after WiFi is live',
              _rejoinMs, 10, 'btRejoinMs', (v) => _rejoinMs = v, redraw),
          // With the switch on Bluetooth waits for the stream however long,
          // so this fallback has nothing to time.
          gap('Bluetooth back if no WiFi stream', _backMs, 30, 'btBackMs',
              (v) => _backMs = v, redraw, on: !_wifiFirst),
          // Gliding on every change keeps the screen redrawing at its full
          // rate: a third of the app's CPU in a replayed drive. Off, small
          // changes land at once and only jumps glide.
          const SizedBox(height: 8),
          toggle('Basic layout (bigger text, swipe the side cards)', _basic, _setBasic, redraw),
          toggle('Smooth power ring (more battery)', _smooth, (v) => _smooth = v, redraw, key: 'smoothRing'),
          // The figures few glance at: off, the rows go, the rest closes up.
          toggle('Show 12 V, other power and cell imbalance', _minor, (v) => _minor = v, redraw, key: 'minorFigures'),
          // Off, every id streams: doors and belts live, but more frames for
          // the Commander to drop, speed's among them.
          toggle('Sparse polling (steadier speed, slower doors and belts)', _sparse, (v) => _obd.sparse = _sparse = v,
              redraw, key: 'sparsePolling'),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('Car: Model Y')),
            SegmentedButton<String>(
              segments: [
                for (final MapEntry(:key, :value) in _cars.entries) ButtonSegment(value: key, label: Text(value)),
              ],
              selected: {_car},
              onSelectionChanged: (v) {
                _setCar(v.first);
                redraw(() {});
              },
            ),
          ]),
        ]),
          ),
        ),
        actions: [
          // Bluetooth sticks to the Commander it was approved on; this lets
          // it pair with a replacement.
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'forget'),
            child: const Text('Find another Commander'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'diag'),
            child: const Text('Diagnostics'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Reconnect'),
          ),
        ],
      )),
    );
    Future<void>.delayed(const Duration(milliseconds: 500), scroll.dispose); // after the exit animation
    if (!mounted) return;
    if (action == 'diag') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DiagPage(obd: _obd, bt: _bt)),
      );
      return;
    }
    if (action == 'forget') {
      await _bt.forget();
      return;
    }
    if (action != 'save') return;
    final prefs = await SharedPreferences.getInstance();
    _host = host.text.trim();
    _port = int.tryParse(port.text.trim()) ?? kDefaultPort;
    await prefs.setString('host', _host);
    await prefs.setInt('port', _port);
    await _saveWifi(ssid.text, password.text);
    if (mounted) setState(() {});
    _connect(now: true); // asked for: try the network even if not seen yet
  }

  /// The full layout's figures under the battery: what the pack feeds besides
  /// the motors (WiFi) and its health; the air outside is by the ring.
  Widget _figures(Panda o) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (o.wifiLive && o.otherKw != null) _Draws(obd: o, minor: _minor),
        _Pack(obd: o, minor: _minor),
      ]);

  /// The bar along the foot: the links, the route ([nav]: basic has it on a
  /// card), Google Maps and the car panel.
  Widget _controls({bool nav = true}) =>
      _Controls(obd: _obd, bt: _bt, onWifi: _settings, onBt: _btStatus, onMaps: _maps, nav: nav);

  /// A page the basic layout shows, kept for the next start.
  Future<void> _keep(String key, int page) async => (await SharedPreferences.getInstance()).setInt(key, page);

  /// The speed and power ring, the same in both layouts, with the assist
  /// state at its top right: just outside the ring's arc, a little below its
  /// box's corner. [outside]: the air outside at its top left, level with
  /// the assist state and as clear of the arc (both layouts; not compact).
  /// [pages]: the basic layout's, swiped up or down to the speedometer
  /// ([_Speedo]) and kept; the assist state and the air outside stay put.
  Widget _ring(Panda o, {bool outside = false, bool pages = false}) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, box) {
          const size = _ApIcon.size;
          // Up and right, 5 clear of the arcs.
          final half = box.maxWidth / 2, d = RingGauge.outerRadius(box.maxWidth) + size / 2 + 5;
          const a = -38 * pi / 180;
          final icon = _autopilot(o);
          void gear() => _setBasic(!_basic); // the gear's tap, on every face
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
                child: pages
                    ? _Pages(
                        key: const ValueKey('ringPages'),
                        initial: _ringPage,
                        onPage: (p) => setState(() {
                          _keep('ringPage', _ringPage = p);
                          _fitSubscription(); // the speedometer needs less
                        }),
                        children: [
                          _powerRing(o, smooth: _smooth, onGear: gear),
                          RepaintBoundary(
                              child: ListenableBuilder(
                                  listenable: o.fast,
                                  builder: (context, _) => _Speedo(obd: o, onGear: gear))),
                        ],
                      )
                    : _powerRing(o, smooth: _smooth, onGear: gear)),
            if (icon != null)
              Positioned(
                left: half + d * cos(a) - size / 2,
                top: half + d * sin(a) - size / 2,
                child: icon,
              ),
            // Mirroring the icon: its right edge where the icon's left one is.
            if (outside)
              Positioned(
                right: half + d * cos(a) - size / 2 + 3,
                top: half + d * sin(a) - size / 2,
                child: _Outside(obd: o, rowHeight: size),
              ),
          ]);
        }),
      );

  /// Only what is on screen, in the basic layout beside nothing else; worked
  /// out again only when that changes.
  void _fitSubscription() {
    final now = (_basic && MediaQuery.sizeOf(context).width >= 700, _cardLeft, _cardRight, _ringPage == 1);
    if (now == _fitted) return;
    _fitted = now;
    _obd.skip = now.$1 ? basicSkip(_cardLeft, _cardRight, speedo: now.$4) : const {};
  }

  (bool, int, int, bool)? _fitted;

  /// The basic layout: the ring between two stacks of cards (energy, drive,
  /// the car, the buttons, the route), one of each showing, swiped up or down
  /// for the next; either side shows any card and keeps its own.
  Widget _basicRow(Panda o) {
    final cards = [
      // The dial and its rows together in the card's middle; the dial as
      // big on screen as the full layout's, not bigger than the ring.
      _Card(Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _Battery(obd: o, width: 128 / kBasicFigures))),
        const SizedBox(height: 12),
        // All the draws and the pack's health, whatever the full
        // layout's switch says.
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (o.wifiLive && o.charging) _Charge(obd: o) else _Draws(obd: o),
          _Pack(obd: o),
        ]),
      ])),
      // The g-meter's circle the power card's: as wide and as high; the
      // lamps over it, its figures under. WiFi only, as in the full layout:
      // Bluetooth has no g, and a stalled stream would freeze the dot.
      _Card(LayoutBuilder(builder: (context, box) {
        // Room kept above and below for the lamps and the figures.
        final side = max(0.0, min(box.maxWidth, box.maxHeight - 96));
        return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          if (o.wifiLive) _GBall(obd: o, dial: side),
          Positioned(left: 0, right: 0, bottom: box.maxHeight / 2 + side / 2 + 4, child: _Lights(obd: o)),
        ]);
      })),
      _Card.fill((height) => _BasicCar(obd: o, height: height)),
      _Card(
          _fit(Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
            _Actions(obd: o, bt: _bt, onTap: _press),
            _Actions(obd: o, bt: _bt, onTap: _press, right: true),
          ])),
          scale: kBasicButtons),
      // Centred in its card, which bounds its width so a long name wraps
      // rather than shrinks it.
      _Card(Center(child: _Nav(obd: o, bt: _bt, tall: true))),
      // The pack's power and the battery on a dial, as big as the card.
      _Card(Center(
          child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                  child: ListenableBuilder(listenable: o.fast, builder: (context, _) => _PowerDial(obd: o)))))),
    ];
    return Row(children: [
      Expanded(child: _Cards(key: const ValueKey('left'), cards: cards, initial: _cardLeft, dotsLeft: true,
          onPage: (p) {
            _keep('cardLeft', _cardLeft = p);
            _fitSubscription();
          })),
      // The ring with the bar under it, as wide as the ring: the cards
      // either side take the screen's whole height (the bar has no route
      // here, only the links and the buttons).
      IntrinsicWidth(
        child: Column(children: [
          Expanded(child: _ring(o, outside: true, pages: true)),
          Padding(padding: const EdgeInsets.only(top: 6), child: _controls(nav: false)),
        ]),
      ),
      Expanded(child: _Cards(key: const ValueKey('right'), cards: cards, initial: _cardRight,
          onPage: (p) {
            _keep('cardRight', _cardRight = p);
            _fitSubscription();
          })),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // ponytail: the fixed landscape layout fits the S23 Ultra up to a 1.15
    // font scale; a FittedBox per column if bigger settings must apply.
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.15, child: Scaffold(
      // Nothing to type on the dash itself: a dialog's keyboard slides over
      // it rather than squeezing the fixed layout into what is left.
      resizeToAvoidBottomInset: false,
      body: ListenableBuilder(
        listenable: Listenable.merge([_obd, _bt]),
        builder: (context, _) {
          final o = _obd;
          _fitSubscription();
          // Nothing moving on screen outlives the stream: a stalled link
          // blanks speed, power and pedal and drops the glows.
          final live = o.live;
          return Stack(fit: StackFit.expand, children: [
            // Edge glows sit under the dash so they never cover the buttons:
            // indicators blink green in step with the car's flasher, blind
            // spot holds a steady red, brake red at the foot.
            RepaintBoundary(
              child: ListenableBuilder(
              listenable: o.fast,
              builder: (context, _) => Stack(fit: StackFit.expand, children: [
                if (o.live && o.braking) const _Edge(side: _Side.bottom, color: Color(0xFFE23D3D)),
                if (o.live && (o.blindL || (o.indL && o.blinkLit)))
                  _Edge(side: _Side.left, color: o.blindL ? const Color(0xFFE23D3D) : kRegen),
                if (o.live && (o.blindR || (o.indR && o.blinkLit)))
                  _Edge(side: _Side.right, color: o.blindR ? const Color(0xFFE23D3D) : kRegen),
              ]),
            )),
            // Beside Google Maps, or in any split, the window is about half
            // as wide: the essentials only, laid out for it.
            if (MediaQuery.sizeOf(context).width < 700)
              SafeArea(child: _Compact(obd: o, bt: _bt, smooth: _smooth))
            else
              SafeArea(
                child: Stack(children: [
                // The pedal: a solid line along the top, growing from the
                // ring's centre as it goes down; no figure. Within the safe
                // area as the ring is: edge to edge, the camera's cutout
                // widens one side and the screen's centre is not the ring's.
                // Not on a rear-motor car: its ring has the pedal (but not
                // basic's speedometer face).
                if (live && (!o.rwd || (_basic && _ringPage == 1)))
                  IgnorePointer(
                    child: RepaintBoundary(child: ListenableBuilder(
                      listenable: o.fast,
                      builder: (context, _) => Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: _smooth ? const Duration(milliseconds: 140) : Duration.zero,
                          widthFactor: (o.pedalPct ?? 0).clamp(0, 100) / 100,
                          child: Container(height: 4, color: kAccent),
                        ),
                      ),
                    )),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: _basic ? _basicRow(o) : Column(children: [
                    Expanded(
                      child: Row(children: [
                        _Actions(obd: o, bt: _bt, onTap: _press),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Column(children: [
                              _Lights(obd: o),
                              const SizedBox(height: 4),
                              // A little lower: more of the road ahead.
                              Expanded(
                                  child: FittedBox(
                                      child: FractionalTranslation(
                                          translation: const Offset(0, 0.07), child: _Cabin(obd: o)))),
                            ]),
                          ),
                        ),
                        _ring(o, outside: true),
                        // Driving: the battery dial and the g-meter pinned top
                        // and bottom, the pack's figures between them: the
                        // dial's top level with the first button's; the
                        // g-meter's place kept while it has nothing to say
                        // (parked it only reads 0; no WiFi, no reading), so the
                        // figures do not jump. Charging (no g-meter): the dial,
                        // the charge and the figures together in the middle.
                        Expanded(
                          child: o.wifiLive && o.charging
                              ? _SideColumn(children: [_Battery(obd: o), _Charge(obd: o), _figures(o)])
                              : Column(children: [
                                  Padding(padding: const EdgeInsets.fromLTRB(8, 14, 8, 0), child: _Battery(obd: o)),
                                  Expanded(child: _SideColumn(children: [_figures(o)])),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                                    child: Builder(builder: (context) {
                                      final shown = o.wifiLive && o.gear != 'P' && (o.gLong != null || o.gLat != null);
                                      return Visibility.maintain(visible: shown, child: _GBall(obd: o, listen: shown));
                                    }),
                                  ),
                                ]),
                        ),
                        _Actions(obd: o, bt: _bt, onTap: _press, right: true),
                      ]),
                    ),
                    Padding(padding: const EdgeInsets.only(top: 6), child: _controls()),
                  ]),
                ),
                ]),
              ),
          ]);
        },
      ),
    ));
  }
}

/// The driver-assist state as the car shows it, its Autopilot wheel on a
/// disc: grey while Autosteer is ready (or has just ended), blue while it
/// steers (Autopilot, Navigate on Autopilot, FSD); the cruise gauge on blue
/// while TACC alone holds the speed. The hands-on nag flashes it amber, red
/// once it chimes; red flashing while it slows the car or says to take over, red and struck
/// through once it locks Autopilot out (grey and struck through on a fault).
/// Its words on a long press.
_ApIcon? _autopilot(Panda o) {
  const blue = Color(0xFF0048FF), grey = Color(0xFF5E5E5E); // the car's own blue
  return switch (o.live ? o.handsOn : null) {
    3 => const _ApIcon(disc: kWarn, flash: true, words: 'HOLD WHEEL'),
    4 || 5 || 9 || 10 => const _ApIcon(disc: kAlert, flash: true, words: 'HOLD WHEEL'), // chiming: about to act
    6 => const _ApIcon(disc: kAlert, flash: true, words: 'SLOWING'),
    7 => const _ApIcon(disc: kAlert, struck: true, words: 'AP LOCKED'),
    // On WiFi, TACC is the assist ready with cruise holding a speed.
    _ => switch (o.autopilot == 'AP READY' && o.cruiseSet != null ? 'TACC' : o.autopilot) {
        null => null,
        'TACC' => const _ApIcon(disc: blue, glyph: Glyph.cruise, words: 'TACC'),
        'AUTOPILOT' || 'NAV ON AP' || 'FSD' => _ApIcon(disc: blue, words: o.autopilot!),
        'AP ENDING' => const _ApIcon(disc: kAlert, flash: true, words: 'TAKE OVER'),
        'AP FAULT' => const _ApIcon(disc: grey, struck: true, words: 'AP FAULT'),
        final ap => _ApIcon(disc: grey, words: ap), // ready, or just ended
      },
  };
}

/// The speed and power ring, the speed in its hole ([_Centre], [onGear] its
/// gear's tap), redrawn on the fast tick on its own layer (the rest of the
/// page stays as it is).
Widget _powerRing(Panda o, {required bool smooth, VoidCallback? onGear}) => RepaintBoundary(
      child: ListenableBuilder(
        listenable: o.fast,
        builder: (context, _) => RingGauge(
          glideAll: smooth,
          frontKw: o.live ? o.frontKw : null,
          rearKw: o.live ? o.rearKw : null,
          rearOnly: o.rwd,
          pedalPct: o.live ? o.pedalPct : null,
          brakePct: o.wifiLive ? o.brakePct : null, // WiFi's alone: frozen once it stalls
          regenCapKw: o.live && o.gear != 'P' ? o.regenMaxKw : null, // no regen parked
          child: _Centre(obd: o, onGear: onGear),
        ),
      ),
    );

/// The dash in half a screen, beside Google Maps or any other split: speed
/// and power in the ring, the gear and the battery above, the assist state
/// and the route below. Lights, tyres, pack, pedal, the seat map and the
/// buttons wait for the full screen.
class _Compact extends StatelessWidget {
  const _Compact({required this.obd, required this.bt, this.smooth = true});

  final Panda obd;
  final Commander bt;
  final bool smooth; // see RingGauge.glideAll

  @override
  Widget build(BuildContext context) {
    final o = obd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(children: [
        SizedBox(
          height: 38,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(o.gear,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const {'P', 'R', 'N', 'D'}.contains(o.gear)
                        ? Colors.white
                        : Colors.white38)),
            // Between them, only what earns a look: someone unbuckled (the
            // seat, red; WiFi only), the air outside, the grip lamp while lit.
            // The grip glyph keeps its place while dark, so the temperature
            // does not jump as it comes and goes; the group shrinks to fit.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (o.wifiLive && o.anyBeltUnbuckled)
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.airline_seat_recline_normal, size: 24, color: kAlert)),
                  if (o.outsideC case final c?)
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(_deg(c),
                            style: TextStyle(fontSize: 18, color: _airColor(c, Colors.white70)))),
                  if (o.wifiLive)
                    Opacity(
                      opacity: o.gripLit ? 1 : 0,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GlyphIcon(Glyph.grip,
                              size: 22, color: o.gripHeld ? kWarn : kCold)),
                    ),
                ]),
              ),
            ),
            _BatteryLine(obd: o),
          ]),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _powerRing(o, smooth: smooth),
            ),
          ),
        ),
        Row(children: [
          if (_autopilot(o) case final ap?)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(height: 26, child: FittedBox(child: ap)),
            ),
          Expanded(
              child: o.wifiLive && o.charging
                  ? _Charge(obd: o, oneLine: true)
                  : _Nav(obd: o, bt: bt, oneLine: true)),
        ]),
      ]),
    );
  }
}

/// The battery for the compact dash: a thin gauge over the charge and the
/// range, as wide as they are.
class _BatteryLine extends StatelessWidget {
  const _BatteryLine({required this.obd});

  final Panda obd;

  @override
  Widget build(BuildContext context) {
    final pct = obd.socPct, range = obd.range;
    return IntrinsicWidth(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
      // Painted, not a FractionallySizedBox: that one's intrinsic width is
      // its child's over the fraction, infinite at 0 % (or no reading),
      // which IntrinsicWidth cannot lay out.
      SizedBox(
        height: 5,
        child: CustomPaint(
            painter: _BarPainter(((pct ?? 0).clamp(0, 100) / 100).toDouble(),
                (pct ?? 100) < 20 ? kAlert : kRegen)),
      ),
      const SizedBox(height: 3),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(pct == null ? '—' : '${pct.round()}%',
            style: const TextStyle(fontSize: 16, height: 1.2, color: Colors.white)),
        // The pack too cold for full regen and power: the car's own sign.
        if ((obd.packTempC ?? 99) <= 10)
          const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.ac_unit, size: 14, color: kCold)),
        if (range != null)
          Text('  ${range.round()} ${obd.rangeUnit}',
              style: const TextStyle(fontSize: 13, height: 1.2, color: Colors.white70)),
      ]),
    ]));
  }
}

/// A thin rounded gauge on a faint track, filled to [fraction] of its width.
class _BarPainter extends CustomPainter {
  _BarPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = Colors.white10);
    if (fraction > 0) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & Size(size.width * fraction, size.height), r),
          Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.fraction != fraction || old.color != color;
}

import 'dart:async';
import 'dart:io' show File;
import 'dart:math' show atan2, cos, max, min, pi, sin, tan;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'car_panel.dart';
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
  0x399, 0x3F5, 0x286, 0x3F8, // limit and blind spots, indicators, cruise set and gap
  0x212, 0x472, // charging: the centre's charge power and why it is capped
};
const kBasicCards = <Set<int>>[
  {0x33A, 0x332, 0x352, 0x392, 0x3A1, 0x347, 0x333, 0x33B}, // energy: battery, pack heat, health, charge
  {0x3F6, 0x2B6, 0x101, 0x321}, // drive: lamps, grip, g-meter (yaw), outside
  {0x3A1, 0x3C2, 0x31A, 0x2F3, 0x25A, 0x219, 0x129, 0x3F6}, // car: belts, fans, tyres, path lines, lamps
  {0x102, 0x103, 0x2E1, 0x25D, 0x273, 0x3E2, 0x243}, // buttons: doors, trunk, frunk, port, tilt, lights, recirc
  {0x238, 0x347, 0x3FD, 0x33A, 0x352}, // route: on a route, energy and minutes, battery now
];

/// The basic layout's figures' rows and route, over the full layout's size on
/// screen (the rest of its cards are bigger still).
const kBasicFigures = 1.1;

/// The ids the basic layout has no use for with these two cards showing.
Set<int> basicSkip(int left, int right) {
  final need = {...kBasicBase, ...kBasicCards[left], ...kBasicCards[right]};
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
    _cardLeft = prefs.getInt('cardLeft') ?? _cardLeft;
    _cardRight = prefs.getInt('cardRight') ?? _cardRight;
    _sparse = prefs.getBool('sparsePolling') ?? _sparse;
    _obd
      ..sparse = _sparse
      ..thirdRow = _carSeven(prefs.getString('car'))
      ..rwd = prefs.getString('car') == 'modelY5rwd';
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
    if (mounted) setState(() {});
    final firstRun = prefs.getString('car') == null;
    _obd.addListener(_linksChanged);
    _obd.addListener(_saveTyres);
    _bt.addListener(_linksChanged);
    // Back in front (phone woke, or the S3XY app was used): try both now.
    _life = AppLifecycleListener(onResume: () {
      _obd.kick();
      _bt.kick();
      // Back from allowing installs: the update carries on.
      if (_installOnReturn) canInstallUpdates().then((ok) => ok ? _installUpdate() : null);
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
      await _askCar();
      await _askLayout();
      await _setupHelp();
      if (!mounted) return;
    }
    _connect();
    _linksStarted = true;
    _bt.connect();
    _startTrace();
    _checkUpdate();
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
  static bool _carSeven(String? car) => car == null || car == 'modelY7'; // the owner's, by default

  /// Which car: a picture of each layout to tap, then for a 5-seater its
  /// drive. Asked on the first launch; the settings change it after.
  /// Dismissed (back), it asks again next time.
  Future<void> _askCar() async {
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
    if (seven == null || !mounted) return;
    if (seven) return _setCar('modelY7');
    final rwd = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which drive?'),
        children: [
          for (final (r, label, about) in const [
            (true, 'Rear-wheel drive', 'one motor'),
            (false, 'All-wheel drive', 'two motors'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text('$label ($about)', style: const TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
    if (rwd != null) await _setCar(rwd ? 'modelY5rwd' : 'modelY5');
  }

  /// Which layout, on the first launch (the settings switch it later):
  /// everything at once, or basic's bigger cards.
  Future<void> _askLayout() async {
    final basic = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which layout?'),
        children: [
          for (final (b, label, about) in const [
            (false, 'Full', 'everything at once'),
            (true, 'Basic', 'bigger text, one card a side; swipe a card for the next'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, b),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text('$label ($about)', style: const TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
    if (basic == null || !mounted) return;
    setState(() => _basic = basic);
    (await SharedPreferences.getInstance()).setBool('basic', basic);
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
    _ssid = name.isEmpty ? kDefaultSsid : name;
    _password = pass;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssid', _ssid);
    await prefs.setString('password', _password);
    if (_linksStarted) _connect(now: true);
  }

  /// A newer release on GitHub, once looked for at start (Android only).
  Update? _update;
  bool _updateOffered = false;

  Future<void> _checkUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _obd.onUpdateFailed =
        (why) => _say(why.contains('ABORTED') ? 'Update cancelled' : 'Update not installed: $why');
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
    if (u == null || _updateOffered || !mounted || (_obd.live && !_obd.parked)) return;
    _updateOffered = true;
    _obd.removeListener(_offerUpdate);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 12),
          content: Text('Wattline ${u.version} is available'),
          action: SnackBarAction(label: 'UPDATE', onPressed: _installUpdate)));
  }

  /// Allowed to install apps first: going to Settings mid-install cancels
  /// Android's install, so the permission comes before the download, and
  /// the update carries on when the app is back in front ([_life]).
  Future<void> _installUpdate() async {
    final u = _update;
    if (u == null) return;
    _installOnReturn = false;
    if (!await canInstallUpdates()) {
      _installOnReturn = true;
      _say('Allow Wattline to install updates, then come back here');
      await allowInstallUpdates();
      return;
    }
    _say('Downloading Wattline ${u.version}…');
    final err = await installUpdate(u);
    if (err != null) _say('Update not installed: $err');
  }

  bool _installOnReturn = false;

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
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
            const Text('2. The first time, approve this phone in the car: double-press the right scroll '
                'wheel when the car asks.'),
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
    if (mounted) {
      setState(() => _obd
        ..thirdRow = _carSeven(car)
        ..rwd = car == 'modelY5rwd');
    }
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
    final bar = (ScaffoldMessenger.of(context)..clearSnackBars()).showSnackBar(const SnackBar(
      duration: Duration(minutes: 2),
      content: Text('Approve this phone for the Commander: '
          'in the car, double-press the right scroll wheel'),
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
    if (say != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(say), duration: const Duration(seconds: 10)));
    }
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
    if (err == null || !mounted || (_bt.approving && _approval != null)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(err)));
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
            child: Text(
                _bt.ready
                    ? 'Commander Bluetooth: connected. Car data: ${_bt.pushInfo}, ${_bt.pushCount} pushes. ${_bt.carLink}.'
                    : 'Commander Bluetooth: ${_bt.status}',
                style: const TextStyle(color: Colors.white70)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(children: [
              TextButton(onPressed: _setupHelp, child: const Text('Setup steps')),
              if (_update case final u?)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
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
          Row(children: [
            const Expanded(child: Text('Bluetooth waits for the WiFi stream, no time limit')),
            Switch(
              value: _wifiFirst,
              onChanged: (v) async {
                redraw(() => _wifiFirst = v);
                _applyLook();
                _obd.relook(); // a look in progress takes the new limit now
                (await SharedPreferences.getInstance()).setBool('btWifiFirst', v);
              },
            ),
          ]),
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
          Row(children: [
            const Expanded(child: Text('Basic layout (bigger text, swipe the side cards)')),
            Switch(
              value: _basic,
              onChanged: (v) async {
                redraw(() => _basic = v);
                setState(() {});
                (await SharedPreferences.getInstance()).setBool('basic', v);
              },
            ),
          ]),
          Row(children: [
            const Expanded(child: Text('Smooth power ring (more battery)')),
            Switch(
              value: _smooth,
              onChanged: (v) async {
                redraw(() => _smooth = v);
                setState(() {});
                (await SharedPreferences.getInstance()).setBool('smoothRing', v);
              },
            ),
          ]),
          // The figures few glance at: off, the rows go, the rest closes up.
          Row(children: [
            const Expanded(child: Text('Show 12 V, other power and cell imbalance')),
            Switch(
              value: _minor,
              onChanged: (v) async {
                redraw(() => _minor = v);
                setState(() {});
                (await SharedPreferences.getInstance()).setBool('minorFigures', v);
              },
            ),
          ]),
          // Off, every id streams: doors and belts live, but more frames for
          // the Commander to drop, speed's among them.
          Row(children: [
            const Expanded(child: Text('Sparse polling (steadier speed, slower doors and belts)')),
            Switch(
              value: _sparse,
              onChanged: (v) async {
                redraw(() => _sparse = v);
                _obd.sparse = v;
                (await SharedPreferences.getInstance()).setBool('sparsePolling', v);
              },
            ),
          ]),
          // The car picked on the first launch: a 5-seater's third row
          // leaves the seat map, a rear-motor car's front leaves the ring.
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('Car: Model Y')),
            SegmentedButton<String>(
              segments: [
                for (final MapEntry(:key, :value) in _cars.entries) ButtonSegment(value: key, label: Text(value)),
              ],
              selected: {_obd.thirdRow ? 'modelY7' : _obd.rwd ? 'modelY5rwd' : 'modelY5'},
              onSelectionChanged: (v) {
                _setCar(v.first); // sets it at once; the save follows
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
    _ssid = ssid.text.trim();
    _password = password.text;
    await prefs.setString('host', _host);
    await prefs.setInt('port', _port);
    await prefs.setString('ssid', _ssid);
    await prefs.setString('password', _password);
    if (mounted) setState(() {});
    _connect(now: true); // asked for: try the network even if not seen yet
  }

  /// The speed and power ring, the same in both layouts.
  /// Full to basic or back (the gear's tap), kept as the settings' switch is.
  Future<void> _toggleBasic() async {
    setState(() => _basic = !_basic);
    (await SharedPreferences.getInstance()).setBool('basic', _basic);
  }

  /// The bar along the foot: the links, the route ([nav]: basic has it on a
  /// card), Google Maps and the car panel.
  Widget _controls({bool nav = true}) =>
      _Controls(obd: _obd, bt: _bt, onWifi: _settings, onBt: _btStatus, onMaps: _maps, nav: nav);

  /// The speed and power ring, the same in both layouts, with the assist
  /// state at its top right: just outside the ring's arc, a little below its
  /// box's corner. [outside]: the air outside at its top left, level with
  /// the assist state and as clear of the arc (the full layout; basic has it
  /// on a card).
  Widget _ring(Panda o, {bool outside = false}) => AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(builder: (context, box) {
          const size = 30.0;
          // As RingGauge draws it: radius r, the motors' arcs 8.5 % of r wide.
          final half = box.maxWidth / 2, r = half - 6, d = r * 1.0425 + size / 2 + 5;
          const a = -38 * pi / 180;
          final icon = _autopilot(o, size: size);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: ListenableBuilder(
                listenable: o.fast,
                builder: (context, _) => RingGauge(
                  glideAll: _smooth,
                  frontKw: o.live ? o.frontKw : null,
                  rearKw: o.live ? o.rearKw : null,
                  rearOnly: o.rwd,
                  pedalPct: o.live ? o.pedalPct : null,
                  brakePct: o.live ? o.brakePct : null,
                  regenCapKw: o.live && o.gear != 'P' ? o.regenMaxKw : null, // no regen parked
                  // Digital speed sits in the ring, the gear under it; a tap
                  // on the gear swaps the layouts.
                  child: _Centre(obd: o, gear: true, onGear: _toggleBasic),
                ),
              ),
            ),
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

  bool _compactNow = false;

  /// Only what is on screen, in the basic layout beside nothing else.
  void _fitSubscription() =>
      _obd.skip = _basic && !_compactNow ? basicSkip(_cardLeft, _cardRight) : const {};

  /// The basic layout: the ring between two stacks of cards, one card of
  /// each showing, swiped up or down for the next. Each card answers one
  /// question, its graphic taking the room its text leaves: energy (the
  /// battery, what the pack feeds besides the motors or the charge, the
  /// pack's health), the drive (lamps and grip, g-meter, the air outside),
  /// the car as large as it fits (lowered for its beams ahead), the buttons,
  /// the route. Both stacks hold every card, so either side shows any; each
  /// side's card is kept. The assist state is at the ring's top right.
  Widget _basicRow(Panda o) {
    // The figures' rows (label and value) and the route a little over the
    // full layout's size on screen ([kBasicFigures]), not scaled up with the
    // rest: next to the ring they read as notes.
    const small = kBasicFigures / _CardsState._scale;
    List<Widget> cards() => [
          // The dial and its rows together in the card's middle.
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // The dial as big on screen as in the full layout: next to the
            // ring, not bigger than it (smaller only if the card is short).
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _Battery(obd: o, width: 128 / _CardsState._scale))),
            const SizedBox(height: 12),
            // The draws and the pack's health in one column, the values lined
            // up; all of them here, whatever the full layout's switch says.
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (o.wifiLive && o.charging) _Charge(obd: o, size: small) else _Draws(obd: o, size: small),
              _Pack(obd: o, outside: false, size: small),
            ]),
          ]),
          Column(children: [
            // The lamps and grip on top (the assist state is by the ring).
            _Lights(obd: o),
            const SizedBox(height: 6),
            // The g-meter (WiFi only), as big as the room.
            Expanded(child: ListenableBuilder(listenable: o.fast, builder: (context, _) => _GBall(obd: o, tall: true))),
            const SizedBox(height: 6),
            // The air outside.
            _Pack(obd: o, pack: false, size: small),
          ]),
          // The car, low going forward and high in reverse ([_BasicCar]).
          _Fill((height) => _BasicCar(obd: o, height: height)),
          _fit(Row(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
            _Actions(obd: o, bt: _bt, onTap: _press),
            _Actions(obd: o, bt: _bt, onTap: _press, right: true),
          ])),
          // The route at the figures' size too; centred in its card, which
          // bounds its width so a long name wraps rather than shrinks it.
          Center(child: _Nav(obd: o, bt: _bt, tall: true, size: small)),
        ];
    Future<void> keep(String key, int page) async => (await SharedPreferences.getInstance()).setInt(key, page);
    return Row(children: [
      Expanded(child: _Cards(key: const ValueKey('left'), cards: cards(), initial: _cardLeft, dotsLeft: true,
          onPage: (p) {
            keep('cardLeft', _cardLeft = p);
            _fitSubscription();
          })),
      // The ring with the bar under it, as wide as the ring: the cards
      // either side take the screen's whole height (the bar has no route
      // here, only the links and the buttons).
      IntrinsicWidth(
        child: Column(children: [
          Expanded(child: _ring(o)),
          Padding(padding: const EdgeInsets.only(top: 6), child: _controls(nav: false)),
        ]),
      ),
      Expanded(child: _Cards(key: const ValueKey('right'), cards: cards(), initial: _cardRight,
          onPage: (p) {
            keep('cardRight', _cardRight = p);
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
          // Beside Google Maps the compact dash shows its own few things.
          _compactNow = MediaQuery.sizeOf(context).width < 700;
          _fitSubscription();
          // Nothing moving on screen outlives the stream: a stalled link
          // blanks speed, power and pedal and drops the glows.
          final live = o.live;
          return Stack(fit: StackFit.expand, children: [
            // Edge glows sit under the dash so they never cover the buttons:
            // indicators blink green in step with the car's flasher, blind
            // spot holds a steady red, brake red at the foot.
            ListenableBuilder(
              listenable: o.fast,
              builder: (context, _) => Stack(fit: StackFit.expand, children: [
                if (o.live && o.braking) const _Edge(side: _Side.bottom, color: Color(0xFFE23D3D)),
                if (o.live && (o.blindL || (o.indL && o.blinkLit)))
                  _Edge(side: _Side.left, color: o.blindL ? const Color(0xFFE23D3D) : kRegen),
                if (o.live && (o.blindR || (o.indR && o.blinkLit)))
                  _Edge(side: _Side.right, color: o.blindR ? const Color(0xFFE23D3D) : kRegen),
              ]),
            ),
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
                // Not on a rear-motor car: its ring has the pedal.
                if (live && !o.rwd)
                  IgnorePointer(
                    child: ListenableBuilder(
                      listenable: o.fast,
                      builder: (context, _) => Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: _smooth ? const Duration(milliseconds: 140) : Duration.zero,
                          widthFactor: (o.pedalPct ?? 0).clamp(0, 100) / 100,
                          child: Container(height: 4, color: kAccent),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: _basic ? _basicRow(o) : Column(children: [
                    Expanded(
                      child: Row(children: [
                        _Actions(obd: o, bt: _bt, onTap: _press),
                        // The lamps, and under them the car as large as the
                        // room left (its figures with it).
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            child: Column(children: [
                              _Lights(obd: o),
                              const SizedBox(height: 4),
                              Expanded(child: FittedBox(child: _Cabin(obd: o))),
                            ]),
                          ),
                        ),
                        _ring(o, outside: true),
                        // The battery dial and the g-meter pinned top and
                        // bottom, the pack's figures between them: the dial's
                        // top level with the first button's; the g-meter's
                        // place kept while it has nothing to say (parked it
                        // only reads 0; no WiFi, no reading), so the figures
                        // do not jump. Charging, the charge over the figures.
                        Expanded(child: Column(children: [
                          Padding(padding: const EdgeInsets.fromLTRB(8, 14, 8, 0), child: _Battery(obd: o, width: 128)),
                          Expanded(child: _SideColumn(children: [
                            if (o.wifiLive && o.charging) _Charge(obd: o),
                            // What the pack feeds besides the motors (WiFi),
                            // and its health; the air outside is by the ring.
                            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              if (o.wifiLive && o.otherKw != null) _Draws(obd: o, minor: _minor),
                              _Pack(obd: o, outside: false, minor: _minor),
                            ]),
                          ])),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                            child: Visibility.maintain(
                              visible: o.wifiLive && !o.charging && o.gear != 'P' && (o.gLong != null || o.gLat != null),
                              child: ListenableBuilder(listenable: o.fast, builder: (context, _) => _GBall(obd: o)),
                            ),
                          ),
                        ])),
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
/// while TACC alone holds the speed. The hands-on nag flashes it amber; red
/// flashing while it slows the car or says to take over, red and struck
/// through once it locks Autopilot out (grey and struck through on a fault).
/// Its words on a long press.
Widget? _autopilot(Panda o, {double size = 30}) {
  const blue = Color(0xFF0048FF), grey = Color(0xFF5E5E5E); // the car's own blue
  final nag = o.live ? o.handsOn : null;
  final ap = o.autopilot;
  final state = switch (nag) {
    3 || 4 || 5 || 9 || 10 => (kWarn, Glyph.autopilot, true, false, 'HOLD WHEEL'),
    6 => (kAlert, Glyph.autopilot, true, false, 'SLOWING'),
    7 => (kAlert, Glyph.autopilot, false, true, 'AP LOCKED'),
    _ => switch (ap) {
        null => null,
        'TACC' => (blue, Glyph.cruise, false, false, ap),
        'AUTOPILOT' || 'NAV ON AP' || 'FSD' => (blue, Glyph.autopilot, false, false, ap),
        'AP ENDING' => (kAlert, Glyph.autopilot, true, false, 'TAKE OVER'),
        'AP FAULT' => (grey, Glyph.autopilot, false, true, ap),
        _ => (grey, Glyph.autopilot, false, false, ap), // ready, or just ended
      },
  };
  if (state == null) return null;
  final (disc, glyph, flash, struck, words) = state;
  return _ApIcon(disc: disc, glyph: glyph, flash: flash, struck: struck, words: words, size: size);
}

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
            // Just the gear it is in.
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
                        child: Text(_deg(c).replaceFirst(' °C', '°'),
                            style: TextStyle(fontSize: 18, color: c <= 3 ? kCold : Colors.white70))),
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
              child: ListenableBuilder(
                listenable: o.fast,
                builder: (context, _) => RingGauge(
                  glideAll: smooth,
                  frontKw: o.live ? o.frontKw : null,
                  rearKw: o.live ? o.rearKw : null,
                  rearOnly: o.rwd,
                  pedalPct: o.live ? o.pedalPct : null,
                  brakePct: o.live ? o.brakePct : null,
                  regenCapKw: o.live && o.gear != 'P' ? o.regenMaxKw : null, // no regen parked
                  child: _Centre(obd: o),
                ),
              ),
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

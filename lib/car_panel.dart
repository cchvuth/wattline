import 'package:flutter/material.dart';

import 'car_actions.dart';
import 'commander.dart';
import 'panda.dart';

/// Every S3XY function (car_actions.dart), in the S3XY app's groups, pressed
/// through the Commander over Bluetooth like the dash's own buttons. One with
/// a choice offers it in a menu; the risky ones ask first. Any can go on the
/// dash in place of one of its twelve buttons.
class CarPanel extends StatefulWidget {
  const CarPanel({super.key, this.bt, this.obd});

  final Commander? bt;
  final Panda? obd; // the gear: a door, the trunk or the frunk opens in P only

  @override
  State<CarPanel> createState() => _CarPanelState();
}

class _CarPanelState extends State<CarPanel> {
  String _msg = '';
  bool _busy = false;

  Future<void> _press(Press a) async {
    if (_busy) return;
    final bt = widget.bt;
    if (bt == null || !bt.ready) {
      bt?.kick(ask: true); // look now, and offer to switch Bluetooth on
      setState(() => _msg = 'Commander Bluetooth: ${bt?.status ?? 'off'}');
      return;
    }
    if (a.opens && !(widget.obd?.parked ?? false)) {
      setState(() => _msg = '${a.label}: opens in P only');
      return;
    }
    if (a.id == 17 && const {'P', 'N', 'D'}.contains(widget.obd?.gear)) {
      setState(() => _msg = 'Mirror tilt acts in R only'); // S3XY: auto-tilt override, Reverse
      return;
    }
    if (a.id == 98 || a.id == 99) massageStale[a.id - 98] = -2; // pressed: its reading counts again
    setState(() {
      _busy = true;
      _msg = '${a.label}…';
    });
    try {
      await bt.tryAction(a);
      // The Commander's 0 only means it took the press.
      if (mounted) {
        setState(() => _msg = a.id == 53 && a.state == 1
            ? '${a.label} sent: unlocks with the driver inside'
            : '${a.label} sent');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msg = a.id == 70
            ? '${a.label} failed: $e (needs the Commander linked to the car: ScanMyTesla off)'
            : '${a.label} failed: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Execute it, or put it on the dash in place of one of its twelve
  /// buttons (the slot picked).
  Future<void> _tap(BuildContext context, CarAction a) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (c) => SimpleDialog(title: Text('${a.group}: ${a.name}'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, false), child: const Text('Execute')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, true), child: const Text('Add to home screen')),
      ]),
    );
    if (add == null || !context.mounted) return;
    if (!add) return runCarAction(context, a, _press);
    final slots = homeSlots.value;
    String name(int i) => carActionAt(slots[i])?.name ?? kHomeButtons[i];
    final i = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('In place of'), children: [
        for (var i = 0; i < 12; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, i),
            child: Text('${i < 6 ? 'Left' : 'Right'} ${i % 6 + 1}: ${name(i)}'),
          ),
      ]),
    );
    if (i == null) return;
    final was = name(i);
    await setHomeSlot(i, carKey(a));
    if (mounted) setState(() => _msg = '${a.name} on the dash in place of $was');
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CarAction>>{};
    for (final a in kCarActions) {
      (groups[a.group] ??= []).add(a);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Car controls'), actions: [
        // The dash's own twelve buttons back.
        TextButton(
          onPressed: () async {
            await setHomeSlot(null, '');
            if (mounted) setState(() => _msg = 'The dash\'s own buttons are back');
          },
          child: const Text('Restore default buttons'),
        ),
      ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // What the last press did, above the list it came from.
        if (_msg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(_msg, style: const TextStyle(color: Colors.white)),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final MapEntry(key: g, value: actions) in groups.entries)
                _group(g, [for (final a in actions) _btn(a)]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _group(String title, List<Widget> buttons) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12, letterSpacing: 2, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ]),
      );

  // A choice to make: the menu's arrow after the name.
  Widget _btn(CarAction a) => Builder(
        builder: (context) => OutlinedButton.icon(
          onPressed: _busy ? null : () => _tap(context, a),
          // White whether or not it can be pressed right now, as on the dash.
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
          ),
          iconAlignment: IconAlignment.end,
          icon: a.options.length > 1 ? const Icon(Icons.arrow_drop_down, size: 18) : null,
          label: Text(a.name),
        ),
      );
}

/// [a] pressed through [press]: its choice first in Flutter's own menu over
/// [context]'s widget (if it has one), then asked to confirm if it is a risky
/// one. The car panel's Execute and a dash button put in its place.
Future<void> runCarAction(BuildContext context, CarAction a, Future<void> Function(Press) press) async {
  var option = 0;
  if (a.options.length > 1) {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final k = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(at, Offset.zero & overlay.size),
      items: [
        for (var k = 0; k < a.options.length; k++)
          PopupMenuItem(value: k, child: Text(a.options[k].$1 ?? '${a.options[k].$2}')),
      ],
    );
    if (k == null) return;
    option = k;
  }
  final p = a.press(option);
  if (a.confirm) {
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(p.label),
        content: const Text('Press it on the car now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Press')),
        ],
      ),
    );
    if (ok != true) return;
  }
  await press(p);
}

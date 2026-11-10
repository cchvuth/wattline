// What changed in each release, shown once after an update (every version
// since the one last run; all of them to one who never saw it) and from the
// settings, with a screenshot or two where the dash looks different. Newest first; a release adds its entry here (a test holds the
// pubspec's version to one), and its GitHub notes say the same.
import 'package:flutter/material.dart';

import 'update.dart';

typedef Change = ({String version, String title, List<String> notes, List<String> shots});

const kChangelog = <Change>[
  (
    version: '1.0.10',
    title: "What's new",
    notes: [
      "This list: after an update, what changed since the version you last ran, with screenshots; any time "
          "from the settings (What's new)",
      'First launch: the layout question shows each mode as it looks',
      'The car controls (locks, honk, flash, climate) have a car icon in the bottom bar',
    ],
    shots: [],
  ),
  (
    version: '1.0.9',
    title: 'Speedometer and power card fixes',
    notes: [
      'Speedometer: washer fluid low, the cruise set speed and the charging line show here too, under the gear; '
          'charging shows its power in place of the speed; the needle hides when the link drops',
      "The ring's page is kept when switching layouts",
      'Power card: battery and range keep updating whatever the other card shows; works over Bluetooth alone',
      'Rear-motor cars: the pedal bar shows on the speedometer face',
    ],
    shots: [],
  ),
  (
    version: '1.0.8',
    title: 'Speedometer and power card',
    notes: [
      "Basic layout: swipe the ring up or down to a speedometer, a gas car's dial with a needle that trails a "
          'blue glow as the speed changes',
      "A power card for either side: the battery's draw round a dial (regen in green), the battery level and "
          'the range at its foot',
      'The outside temperature on the ring, as in the full layout',
      'G-meter: a bigger dot in the basic layout, the drive\'s reach in a stronger blue',
    ],
    shots: ['basic-speedo.jpg', 'basic-dials.jpg'],
  ),
  (
    version: '1.0.7',
    title: 'Smoother speed',
    notes: [
      'The speed and the ring no longer stutter on the move: the steering angle streams only when parking, and '
          "moving, the path lines follow the car's own turn",
      'A picture of the steering wheel shows the right scroll wheel to double-press when approving the phone',
      'Full layout: the car a little lower, with more of the road ahead',
      'BRAKE APPLIED in bold',
    ],
    shots: [],
  ),
  (
    version: '1.0.6',
    title: 'Bug fixes',
    notes: [
      'Autopilot icon: TACC shows its blue cruise icon over WiFi too; the hands-on nag turns red once the car chimes',
      'Updates: never installed on the move; one download at a time',
      'First launch: closed midway, the setup pages come back at the next start',
      'A failed WiFi join blames the password only when the network was in range',
    ],
    shots: [],
  ),
  (
    version: '1.0.5',
    title: 'UI adjustments',
    notes: [
      "Autopilot as the car's own icon at the ring's top right; the outside temperature at its top left",
      'Tap the gear under the speed to switch between the full and basic layouts',
      'Full layout: a bigger car and battery dial; 12 V, other power and cell imbalance behind a settings switch',
    ],
    shots: ['cold-morning.jpg'],
  ),
  (
    version: '1.0.4',
    title: 'Basic layout',
    notes: [
      'Basic layout: the ring between two swipeable stacks of big cards (energy, drive, car, buttons, route); '
          'pick it in the settings',
      'BRAKE APPLIED under the brake line while braking',
    ],
    shots: ['basic-1.jpg'],
  ),
  (
    version: '1.0.3',
    title: 'Brake line',
    notes: [
      "The brake line from the wheels' brake torque: a light press shows, a hard one fills it",
      'Setup: change the WiFi name and password the app joins with',
    ],
    shots: [],
  ),
];

/// "1.0.9" from a build string such as "1.0.9-95b10f3-1110-0016", or null.
String? versionOf(String build) {
  final p = versionParts(build);
  return p.length < 3 ? null : p.take(3).join('.');
}

/// What changed after [last] up to [current]: every release between; with
/// no [last] (the changelog never seen), every release up to [current].
List<Change> changesSince(String? last, String current) => [
      for (final c in kChangelog)
        if (!isNewer(c.version, current) && (last == null || isNewer(c.version, last))) c,
    ];

/// The changes, newest first, each with its screenshots; a scrollbar shown
/// throughout when they run longer than the dialog.
Future<void> showWhatsNew(BuildContext context, List<Change> changes) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("What's new"),
        content: SizedBox(width: 620, child: _Changes(changes)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );

/// The list itself, owning its scroll position: kept to the end of the
/// dialog's closing animation, not dropped as it starts.
class _Changes extends StatefulWidget {
  const _Changes(this.changes);

  final List<Change> changes;

  @override
  State<_Changes> createState() => _ChangesState();
}

class _ChangesState extends State<_Changes> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.only(right: 14), // clear of the bar
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            for (final c in widget.changes) ...[
              Text('${c.version} · ${c.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              for (final n in c.notes) Text('•  $n', style: const TextStyle(color: Colors.white70)),
              for (final s in c.shots)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/whatsnew/$s')),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      );
}

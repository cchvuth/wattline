// What changed in each release, shown once after an update (every version
// since the one last run; all of them to one who never saw it) and from the
// settings, with a screenshot or two where the dash looks different. Newest
// first; a release adds its entry here (a test holds the pubspec's version to
// one), and its GitHub notes say the same. Each big feature its own line, the
// rest one line: "Bug fixes and improvements" (every entry rewritten so).
import 'package:flutter/material.dart';

import 'update.dart';

typedef Change = ({String version, String title, List<String> notes, List<String> shots});

const kChangelog = <Change>[
  (
    version: '1.7.0',
    title: 'Every S3XY function',
    notes: [
      'Seat massage: an L and an R button for the front seats; a tap offers Soft, Pulse and Hard, the running one ticked, and picking it again stops it',
      "Car controls: every S3XY function, in the S3XY app's groups and names; one with a choice offers it, the risky ones ask first",
      'Add to home screen puts any of them on the dash in place of one of its twelve buttons; Restore default buttons brings them back',
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (
    version: '1.6.1',
    title: 'Save logs',
    notes: [
      'Settings, Advanced: Save logs. Off (the default), the app keeps no log at all; on, the trace log as before',
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (
    version: '1.6.0',
    title: 'Plugged in',
    notes: [
      "Plugged in at the limit: the ring shows the wall's power, and the card what goes to the climate and the battery",
      "Battery % and charging power now match the car's screen",
      'Braking with WiFi: each tyre shows its brake % in red',
      'Bug fixes and improvements',
    ],
    shots: ['plugged-in.jpg'],
  ),
  (
    version: '1.5.1',
    title: 'G-meter in Park',
    notes: [
      "The g-meter stays up in Park, with the last drive's peak",
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (
    version: '1.5.0',
    title: 'Units',
    notes: [
      'Settings, Car: miles and mph, °F, and tyre pressure in psi or bar, each its own switch',
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (
    version: '1.4.1',
    title: 'Fahrenheit',
    notes: [
      'Temperatures in °F when the car is set to mph',
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (
    version: '1.4.0',
    title: 'More over Bluetooth',
    notes: [
      "On Bluetooth alone: the tyre pressures and the cabin's temperature on the car picture, once the Commander's firmware sends them",
      'On Bluetooth alone, all-wheel drive: the four brakes\' temperatures and the pedal in the g-meter\'s place',
      'Bug fixes and improvements',
    ],
    shots: ['bluetooth.jpg'],
  ),
  (
    version: '1.3.0',
    title: 'Model Y L',
    notes: [
      "The 6-seat Model Y L as a car to pick, with captain's chairs in the second row",
      "The front light bar lights as the car's own strip across the nose, on the Model Y and Y L",
      'Settings in pages (Connection, Car, Advanced); the car picked from its pictures, drawn to scale',
      'Bug fixes and improvements',
    ],
    shots: ['model-y-l.jpg'],
  ),
  (version: '1.2.1', title: 'Bug fixes', notes: ['Bug fixes and improvements'], shots: []),
  (
    version: '1.2.0',
    title: 'Model 3',
    notes: [
      'The Model 3 as a car to pick, rear- or all-wheel drive, with its own lights',
      'Bug fixes and improvements',
    ],
    shots: ['model-3.jpg'],
  ),
  (version: '1.1.1', title: 'Bug fixes', notes: ['Bug fixes and improvements'], shots: []),
  (
    version: '1.1.0',
    title: "What's new",
    notes: [
      "This list of what changed after an update, with screenshots; any time from the settings",
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (version: '1.0.9', title: 'Bug fixes', notes: ['Bug fixes and improvements'], shots: []),
  (
    version: '1.0.8',
    title: 'Speedometer and power card',
    notes: [
      "Basic layout: swipe the ring up or down to a speedometer",
      "A power card for either side: the battery's draw round a dial, its level and the range",
      'Bug fixes and improvements',
    ],
    shots: ['basic-speedo.jpg', 'basic-dials.jpg'],
  ),
  (
    version: '1.0.7',
    title: 'Smoother speed',
    notes: [
      'The speed and the ring no longer stutter on the move',
      'Bug fixes and improvements',
    ],
    shots: [],
  ),
  (version: '1.0.6', title: 'Bug fixes', notes: ['Bug fixes and improvements'], shots: []),
  (
    version: '1.0.5',
    title: 'Layout switch',
    notes: [
      'Tap the gear under the speed to switch between the full and basic layouts',
      'Bug fixes and improvements',
    ],
    shots: ['cold-morning.jpg'],
  ),
  (
    version: '1.0.4',
    title: 'Basic layout',
    notes: [
      'The basic layout: big cards beside the ring, swipe either side for more; pick it in the settings',
      'Bug fixes and improvements',
    ],
    shots: ['basic-1.jpg'],
  ),
  (
    version: '1.0.3',
    title: 'Brake line',
    notes: [
      "The brake line on the ring, from the wheels' brake torque",
      'Bug fixes and improvements',
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

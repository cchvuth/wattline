import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'commander.dart';

/// Every S3XY function the Commander can press for a Model 3 or Y, in the S3XY
/// app's groups and order and by its names (its Model S/X-only ones left out).
/// Wire ids are niklaswa's TeslaAction; each option sends its own state with
/// switch type 1, as [S3xyAction]s do. [confirm]: asked first (a gear, the
/// motors, drift, the park brake). The screens' copy (wattline-embedded
/// app/build/car_actions_gen.h) is generated from this file: keep each entry
/// on its own line, in this shape.
class CarAction {
  const CarAction(this.group, this.name, this.id, this.options, {this.confirm = false});

  final String group, name;
  final int id;

  /// (label, state): one with no label is pressed at once; more offer a
  /// choice.
  final List<(String?, int)> options;
  final bool confirm;

  /// Its press for [option]'s state.
  CarPress press(int option) {
    final (label, state) = options[option];
    return CarPress(id, state, '$group: $name${label == null ? '' : ': $label'}');
  }
}

/// A [CarAction] option as a press.
class CarPress with Press {
  const CarPress(this.id, this.state, this.label);

  @override
  final int id, state;
  @override
  final String label;
}

/// The dash's twelve buttons (_Actions: each side's six, the left first): ''
/// its own, else the car panel action put in its place ([carKey]), kept in
/// the settings.
final homeSlots = ValueNotifier<List<String>>(List.filled(12, ''));

/// The dash's own buttons, as the slot picker names them.
const kHomeButtons = ['Trunk', 'Mirror tilt', 'Front left door', 'Rear left door', 'Charge port',
    'Left Seat Massage', 'Frunk', 'Recirculation', 'Front right door', 'Rear right door',
    'Interior lights', 'Right Seat Massage'];

/// Each seat's massage reading set aside when the car ended it (a door
/// opened, P): -2 none. A press of that seat's massage clears it.
final massageStale = <int?>[-2, -2];

String carKey(CarAction a) => '${a.group}|${a.name}';

/// The action [key] names, or null ('' or one no longer in the list).
CarAction? carActionAt(String key) =>
    key.isEmpty ? null : kCarActions.where((a) => carKey(a) == key).firstOrNull;

Future<void> loadHomeSlots() async {
  final l = (await SharedPreferences.getInstance()).getStringList('homeSlots');
  if (l != null && l.length == 12) homeSlots.value = l;
}

/// Slot [i] to [key] ('' its own button again), or all of them back with
/// [i] null.
Future<void> setHomeSlot(int? i, String key) async {
  final l = List.of(i == null ? List.filled(12, '') : homeSlots.value);
  if (i != null) l[i] = key;
  homeSlots.value = l;
  await (await SharedPreferences.getInstance()).setStringList('homeSlots', l);
}

const kCarActions = <CarAction>[
  CarAction('Open', 'Trunk', 3, [(null, 0)]),
  CarAction('Open', 'Frunk', 2, [(null, 0)]),
  CarAction('Open', 'Front Left Door', 40, [(null, 1)]),
  CarAction('Open', 'Front Right Door', 40, [(null, 2)]),
  CarAction('Open', 'Rear Left Door', 40, [(null, 3)]),
  CarAction('Open', 'Rear Right Door', 40, [(null, 4)]),
  CarAction('Open', 'Glovebox', 1, [(null, 0)]),
  CarAction('Acceleration', 'Toggle', 4, [(null, 0)]),
  CarAction('Acceleration', 'Chill', 4, [(null, 1)]),
  CarAction('Acceleration', 'Standard', 4, [(null, 2)]),
  CarAction('Acceleration', 'Plaid', 4, [(null, 3)]),
  CarAction('Acceleration', 'Toggle Plaid', 4, [(null, 4)]),
  CarAction('Regen Braking', 'Toggle 0%', 5, [(null, 1)]),
  CarAction('Regen Braking', 'Toggle 25%', 5, [(null, 2)]),
  CarAction('Regen Braking', 'Toggle 50% (low)', 5, [(null, 3)]),
  CarAction('Regen Braking', 'Toggle 75%', 5, [(null, 4)]),
  CarAction('Regen Braking', 'Toggle 100% (standard)', 5, [(null, 5)]),
  CarAction('Regen Braking', 'UP (+25%)', 5, [(null, 6)]),
  CarAction('Regen Braking', 'DOWN (-25%)', 5, [(null, 7)]),
  CarAction('Regen Braking', 'LOOP UP (+25%)', 5, [(null, 9)]),
  CarAction('Regen Braking', 'LOOP DOWN (-25%)', 5, [(null, 8)]),
  CarAction('Regen Braking', 'Set to 0%', 5, [(null, 10)]),
  CarAction('Regen Braking', 'Set to 25%', 5, [(null, 11)]),
  CarAction('Regen Braking', 'Set to 50% (low)', 5, [(null, 12)]),
  CarAction('Regen Braking', 'Set to 75%', 5, [(null, 13)]),
  CarAction('Regen Braking', 'Set to 100% (standard)', 5, [(null, 14)]),
  CarAction('Autopilot', 'Cruising Speed -1', 56, [(null, 2)]),
  CarAction('Autopilot', 'Cruising Speed +1', 56, [(null, 1)]),
  CarAction('Autopilot', 'Cruising Speed -5', 56, [(null, 4)]),
  CarAction('Autopilot', 'Cruising Speed +5', 56, [(null, 3)]),
  CarAction('Autopilot', 'Cruise Control', 30, [(null, 0)]),
  CarAction('Autopilot', 'Autopilot', 29, [(null, 0)]),
  CarAction('Autopilot', 'Autopilot hands-on', 34, [(null, 0)]),
  CarAction('Autopilot', 'Autopilot ON', 29, [(null, 1)]),
  CarAction('Autopilot', 'Autopilot Max', 61, [(null, 1)]),
  CarAction('Autopilot', 'Follow Distance', 88, [('2', 2), ('3', 3), ('4', 4), ('5', 5), ('6', 6), ('7', 7)]),
  CarAction('Media', 'Volume Down', 9, [(null, 4)]),
  CarAction('Media', 'Volume Up', 9, [(null, 3)]),
  CarAction('Media', 'Next song', 9, [(null, 1)]),
  CarAction('Media', 'Previous Song', 9, [(null, 2)]),
  CarAction('Media', 'Play/Pause/Mute', 9, [(null, 5)]),
  CarAction('Charging', 'Battery Precondition (beta)', 42, [('30°C', 30), ('31°C', 31), ('32°C', 32), ('33°C', 33), ('34°C', 34), ('35°C', 35), ('36°C', 36), ('37°C', 37), ('38°C', 38), ('39°C', 39), ('40°C', 40), ('41°C', 41), ('42°C', 42), ('43°C', 43), ('44°C', 44), ('45°C', 45), ('46°C', 46), ('47°C', 47), ('48°C', 48), ('49°C', 49), ('MAX', 50)]),
  CarAction('Charging', 'Charge Port', 8, [(null, 0)]),
  CarAction('Mirrors', 'Tilt mirrors', 17, [(null, 0)]),
  CarAction('Mirrors', 'Dim mirrors', 22, [(null, 0)]),
  CarAction('Mirrors', 'Fold mirrors', 7, [(null, 0)]),
  CarAction('Heated Seats', 'Toggle FL', 25, [(null, 0)]),
  CarAction('Heated Seats', 'Toggle FR', 26, [(null, 0)]),
  CarAction('Heated Seats', 'On/Off FL', 25, [(null, 4)]),
  CarAction('Heated Seats', 'On/Off FR', 26, [(null, 4)]),
  CarAction('Heated Seats', 'On/Off RL', 18, [(null, 4)]),
  CarAction('Heated Seats', 'On/Off RR', 19, [(null, 4)]),
  CarAction('Heated Seats', 'On/Off RC', 20, [(null, 4)]),
  CarAction('Heated Seats', 'Toggle RL', 18, [(null, 0)]),
  CarAction('Heated Seats', 'Toggle RR', 19, [(null, 0)]),
  CarAction('Heated Seats', 'Toggle RC', 20, [(null, 0)]),
  CarAction('Heated Seats', 'Toggle All Rear', 21, [(null, 0)]),
  CarAction('Heated Seats', 'All Rear OFF', 21, [(null, 1)]),
  CarAction('Heated Seats', 'All Heaters OFF', 74, [(null, 2)]),
  CarAction('Seat Cooling', 'Toggle FL', 44, [(null, 0)]),
  CarAction('Seat Cooling', 'Toggle FR', 45, [(null, 0)]),
  CarAction('Seat Cooling', 'On/Off FL', 44, [(null, 4)]),
  CarAction('Seat Cooling', 'On/Off FR', 45, [(null, 4)]),
  CarAction('Seat Adjustment', 'Left Seat Forward', 63, [(null, 4)]),
  CarAction('Seat Adjustment', 'Left Seat Backward', 63, [(null, 5)]),
  CarAction('Seat Adjustment', 'Left Backrest Forward', 63, [(null, 6)]),
  CarAction('Seat Adjustment', 'Left Backrest Backward', 63, [(null, 7)]),
  CarAction('Seat Adjustment', 'Right Seat Forward', 64, [(null, 4)]),
  CarAction('Seat Adjustment', 'Right Seat Backward', 64, [(null, 5)]),
  CarAction('Seat Adjustment', 'Right Backrest Forward', 64, [(null, 6)]),
  CarAction('Seat Adjustment', 'Right Backrest Backward', 64, [(null, 7)]),
  CarAction('Seat Adjustment', 'Left Position Forward', 63, [(null, 2)]),
  CarAction('Seat Adjustment', 'Left Position Backward', 63, [(null, 3)]),
  CarAction('Seat Adjustment', 'Right Position Forward', 64, [(null, 2)]),
  CarAction('Seat Adjustment', 'Right Position Backward', 64, [(null, 3)]),
  CarAction('Seat Adjustment', 'Left Seat Profile', 79, [('Profile 1', 1), ('Profile 2', 2), ('Profile 3', 3), ('Profile 4', 4)]),
  CarAction('Seat Adjustment', 'Store Left Seat Profile', 78, [('Profile 1', 1), ('Profile 2', 2), ('Profile 3', 3), ('Profile 4', 4)]),
  CarAction('Seat Adjustment', 'Right Seat Profile', 81, [('Profile 1', 1), ('Profile 2', 2), ('Profile 3', 3), ('Profile 4', 4)]),
  CarAction('Seat Adjustment', 'Store Right Seat Profile', 80, [('Profile 1', 1), ('Profile 2', 2), ('Profile 3', 3), ('Profile 4', 4)]),
  CarAction('Seat Massage', 'Left Seat Massage', 98, [('Soft', 3), ('Hard', 4), ('Pulse', 2)]),
  CarAction('Seat Massage', 'Right Seat Massage', 99, [('Soft', 3), ('Hard', 4), ('Pulse', 2)]),
  CarAction('Climate Control', 'Steering Wheel Heater', 23, [(null, 0)]),
  CarAction('Climate Control', 'Fan speed +', 27, [(null, 12)]),
  CarAction('Climate Control', 'Fan speed -', 27, [(null, 13)]),
  CarAction('Climate Control', 'Fan speed +3', 27, [(null, 15)]),
  CarAction('Climate Control', 'Fan speed -3', 27, [(null, 16)]),
  CarAction('Climate Control', 'Fan speed MIN', 27, [(null, 1)]),
  CarAction('Climate Control', 'Fan speed MAX', 27, [(null, 10)]),
  CarAction('Climate Control', 'Rear Fan', 41, [(null, 6)]),
  CarAction('Climate Control', 'Defog/Defrost', 28, [(null, 0)]),
  CarAction('Climate Control', 'Recirculation Toggle', 48, [(null, 4)]),
  CarAction('Climate Control', 'Recirculation On', 48, [(null, 2)]),
  CarAction('Climate Control', 'Recirculation Fresh', 48, [(null, 3)]),
  CarAction('Climate Control', 'AC Toggle', 49, [(null, 4)]),
  CarAction('Climate Control', 'AC On', 49, [(null, 3)]),
  CarAction('Climate Control', 'AC Off', 49, [(null, 2)]),
  CarAction('Climate Control', 'Bioweapon Defence', 66, [(null, 0)]),
  CarAction('Climate Control', 'Keep Climate On', 67, [(null, 0)]),
  CarAction('Climate Control', 'Dog Mode', 68, [(null, 0)]),
  CarAction('Climate Control', 'Camp Mode', 69, [(null, 0)]),
  CarAction('Climate Control', 'Climate System ON/OFF', 70, [(null, 0)]),
  CarAction('Climate Control', 'Vent Windows', 71, [(null, 0)]),
  CarAction('Climate Control', 'Left Air Vent Toggle', 72, [(null, 0)]),
  CarAction('Climate Control', 'Left Air Vent OFF', 72, [(null, 2)]),
  CarAction('Climate Control', 'Right Air Vent Toggle', 73, [(null, 0)]),
  CarAction('Climate Control', 'Right Air Vent OFF', 73, [(null, 2)]),
  CarAction('Headlights', 'High Beam', 33, [(null, 5)]),
  CarAction('Headlights', 'Low Beam', 39, [(null, 0)]),
  CarAction('Headlights', 'High Beam Flash', 33, [(null, 6)]),
  CarAction('Headlights', 'High Beam Strobe', 84, [('2', 2), ('3', 3), ('4', 4), ('5', 5), ('6', 6), ('7', 7), ('8', 8), ('9', 9), ('10', 10)]),
  CarAction('Headlights', 'Fog Lights (beta)', 50, [(null, 0)]),
  CarAction('Headlights', 'Fog Lights Rear (beta)', 51, [(null, 0)]),
  CarAction('Headlights', 'Fog Lights all (beta)', 52, [(null, 0)]),
  CarAction('Headlights', 'Dynamic brake lights', 87, [('1', 1), ('2', 2), ('3', 3), ('4', 4), ('5', 5), ('6', 6), ('7', 7), ('8', 8), ('9', 9), ('10', 10)]),
  CarAction('Wipers', 'Standard Increase +1', 32, [(null, 1)]),
  CarAction('Wipers', 'Standard Decrease -1', 32, [(null, 2)]),
  CarAction('Wipers', 'Standard Loop +1', 32, [(null, 3)]),
  CarAction('Wipers', 'Standard Loop -1', 32, [(null, 22)]),
  CarAction('Wipers', 'Toggle OFF', 32, [(null, 15)]),
  CarAction('Wipers', 'Toggle 1', 32, [(null, 17)]),
  CarAction('Wipers', 'Toggle 2', 32, [(null, 19)]),
  CarAction('Wipers', 'Toggle 3', 32, [(null, 20)]),
  CarAction('Wipers', 'Toggle 4', 32, [(null, 21)]),
  CarAction('Wipers', 'Set to OFF', 32, [(null, 8)]),
  CarAction('Wipers', 'Set to 1', 32, [(null, 10)]),
  CarAction('Wipers', 'Set to 2', 32, [(null, 12)]),
  CarAction('Wipers', 'Set to 3', 32, [(null, 13)]),
  CarAction('Wipers', 'Set to 4', 32, [(null, 14)]),
  CarAction('Wipers', 'Return to AUTO', 32, [(null, 7)]),
  CarAction('Wipers', 'Single Wipe', 54, [(null, 1)]),
  CarAction('Wipers', 'Washers', 54, [(null, 2)]),
  CarAction('Stopping Mode', 'Creep', 46, [(null, 2)]),
  CarAction('Stopping Mode', 'Hold', 46, [(null, 1)]),
  CarAction('Stopping Mode', 'Roll', 46, [(null, 3)]),
  CarAction('Traction Control', 'Drift Mode', 55, [(null, 5)], confirm: true),
  CarAction('Traction Control', 'Drift Mode PRO', 55, [(null, 6)], confirm: true),
  CarAction('Traction Control', 'Slip Start', 55, [(null, 2)]),
  CarAction('Traction Control', 'Off-Road (Snow)', 55, [(null, 8)]),
  CarAction('Traction Control', 'Toggle', 55, [(null, 9)]),
  CarAction('Traction Control', 'Disable Front Motor', 65, [(null, 1)], confirm: true),
  CarAction('Traction Control', 'Disable Rear Motor', 65, [(null, 2)], confirm: true),
  CarAction('Accessibility', 'Left Turn', 33, [(null, 1)]),
  CarAction('Accessibility', 'Right Turn', 33, [(null, 3)]),
  CarAction('Accessibility', 'Short Left Turn', 33, [(null, 2)]),
  CarAction('Accessibility', 'Short Right Turn', 33, [(null, 4)]),
  CarAction('Accessibility', 'Short Honk', 15, [(null, 1)]),
  CarAction('Accessibility', 'Long Honk', 15, [(null, 2)]),
  CarAction('Accessibility', 'Very Short Honk', 15, [(null, 3)]),
  CarAction('Accessibility', 'Double Honk', 15, [(null, 4)]),
  CarAction('Accessibility', 'Hazard Lights', 10, [(null, 0)]),
  CarAction('Accessibility', 'Voice Command', 16, [(null, 0)]),
  CarAction('Accessibility', 'Camera View', 82, [(null, 0)]),
  CarAction('Gear Shift', 'Set to P', 57, [(null, 1)], confirm: true),
  CarAction('Gear Shift', 'Set to R', 57, [(null, 2)], confirm: true),
  CarAction('Gear Shift', 'Set to N', 57, [(null, 3)], confirm: true),
  CarAction('Gear Shift', 'Set to D', 57, [(null, 4)], confirm: true),
  CarAction('Gear Shift', 'Toggle D-P', 57, [(null, 5)], confirm: true),
  CarAction('Gear Shift', 'Toggle R-P', 57, [(null, 6)], confirm: true),
  CarAction('Gear Shift', 'Toggle D-R', 57, [(null, 7)], confirm: true),
  CarAction('Lock / Unlock', 'Toggle', 53, [(null, 3)]),
  CarAction('Lock / Unlock', 'Unlock', 53, [(null, 1)]),
  CarAction('Lock / Unlock', 'Lock', 53, [(null, 2)]),
  CarAction('Lock / Unlock', 'Silent Lock/Unlock', 53, [(null, 8)]),
  CarAction('Lock / Unlock', 'Child Unlock both', 35, [(null, 3)]),
  CarAction('Lock / Unlock', 'Child Unlock Left', 35, [(null, 1)]),
  CarAction('Lock / Unlock', 'Child Unlock Right', 35, [(null, 2)]),
  CarAction('Ride And Handling', 'Comfort (S/X) / Standard (3/Y)', 96, [(null, 1)]),
  CarAction('Ride And Handling', 'Sport', 96, [(null, 2)]),
  CarAction('Ride And Handling', 'Advanced (S/X) / Track (3/Y)', 96, [(null, 3)]),
  CarAction('Track Mode', 'Track Mode On', 14, [(null, 0)]),
  CarAction('Track Mode', 'Stability', 59, [('-10', 1), ('-9', 2), ('-8', 3), ('-7', 4), ('-6', 5), ('-5', 6), ('-4', 7), ('-3', 8), ('-2', 9), ('-1', 10), ('0', 11), ('1', 12), ('2', 13), ('3', 14), ('4', 15), ('5', 16), ('6', 17), ('7', 18), ('8', 19), ('9', 20), ('10', 21)]),
  CarAction('Track Mode', 'Handling', 60, [('100/0', 3), ('95/5', 4), ('90/10', 5), ('85/15', 6), ('80/20', 7), ('75/25', 8), ('70/30', 9), ('65/35', 10), ('60/40', 11), ('55/45', 12), ('50/50', 13), ('45/55', 14), ('40/60', 15), ('35/65', 16), ('30/70', 17), ('25/75', 18), ('20/80', 19), ('15/85', 20), ('10/90', 21), ('5/95', 22), ('0/100', 23)]),
  CarAction('Others', 'Interior Lights', 12, [(null, 0)]),
  CarAction('Others', 'Light Strip Brightness', 83, [('0 %', 101), ('25 %', 25), ('50 %', 50), ('75 %', 75), ('100 %', 100)]),
  CarAction('Others', 'Park Brake', 11, [(null, 0)], confirm: true),
  CarAction('Others', 'Thank you! (1)', 37, [(null, 1)]),
  CarAction('Others', 'Thank you! (2)', 37, [(null, 2)]),
  CarAction('Others', 'Thank you! (3)', 37, [(null, 0)]),
  CarAction('Others', 'Truck Thank You', 37, [(null, 3)]),
  CarAction('Others', 'Hand Wash', 89, [(null, 0)]),
  CarAction('Others', 'Grok', 94, [(null, 0)]),
  CarAction('Others', 'Pedestrian Chime', 97, [(null, 2)]),
];

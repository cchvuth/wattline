// The cars Wattline knows, and all that tells them apart: the body, its
// seats and its drive, and the body's steering for the path lines. Their CAN
// signals are the same (signals.dart, checked against both bodies' DBCs);
// each body's picture lives with the painter that draws it (widgets.dart).

/// A body, and the figures of the path lines' bicycle model: the road
/// wheel's angle at full lock comes from the turning circle (kerb to kerb),
/// the wheelbase and the track; the steering ratio from how far the wheel
/// turns to get there.
/// ponytail: published figures; set them from a full-lock reading in the trace.
enum Model {
  /// 12.1 m turning circle, 2.89 m wheelbase, 1.66 m track: the rear axle's
  /// centre 4.48 m from the turning point, 32.8° at full lock, which the
  /// wheel reaches about 450° each way.
  y('Model Y', length: 4.797, steerRatio: 13.7, wheelbase: 2.89, maxRoadDeg: 32.8),

  /// The Y's steering on a wheelbase 150 mm longer. Its lock is unconfirmed:
  /// the one turning circle published repeats the Y's 12.1 m, which this
  /// wheelbase would need 34.6° for.
  yL('Model Y L', length: 4.976, steerRatio: 13.7, wheelbase: 3.04, maxRoadDeg: 32.8),

  /// 11.6 m turning circle, 2.875 m wheelbase, 1.58 m track: 34.1° at full
  /// lock, about 360° of the wheel each way.
  three('Model 3', length: 4.72, steerRatio: 10.6, wheelbase: 2.875, maxRoadDeg: 34.1);

  const Model(this.label,
      {required this.length, required this.steerRatio, required this.wheelbase, required this.maxRoadDeg});

  final String label;

  /// Bumper to bumper, m: the car picker draws each to scale.
  final double length;

  /// Steering wheel turns per road wheel turn.
  final double steerRatio;

  /// m.
  final double wheelbase;

  /// The road wheel's angle at full lock, degrees.
  final double maxRoadDeg;
}

/// A car as picked: its body, the seats in each row and its drive. [id] is
/// what the settings keep, so it never changes.
enum Car {
  model3Rwd('model3rwd', Model.three, rwd: true),
  model3('model3', Model.three),
  modelY5Rwd('modelY5rwd', Model.y, rwd: true),
  modelY5('modelY5', Model.y),
  modelY7('modelY7', Model.y, rows: [2, 3, 2]), // two motors only, as the L
  modelYL('modelYL', Model.yL, rows: [2, 2, 2]);

  const Car(this.id, this.model, {this.rows = const [2, 3], this.rwd = false});

  final String id;
  final Model model;

  /// The seats in each row, front first.
  final List<int> rows;
  int get seats => rows.fold(0, (sum, row) => sum + row);

  /// One motor, at the back: no front motor frames to wait for or show.
  final bool rwd;

  bool get thirdRow => rows.length > 2;

  /// Its seats by the names the belts go by, row by row: D and P, then each
  /// row's L and R with a middle seat's C between (2L, 2C, 2R).
  List<List<String>> get seatRows => _seatRows[this]!;

  List<String> get seatNames => _seatNames[this]!;

  // Worked out once a car: the dash asks every frame.
  static final _seatRows = {
    for (final c in values)
      c: [
        for (final (i, n) in c.rows.indexed)
          i == 0 ? const ['D', 'P'] : ['${i + 1}L', if (n == 3) '${i + 1}C', '${i + 1}R'],
      ],
  };
  static final _seatNames = {for (final c in values) c: _seatRows[c]!.expand((r) => r).toList()};

  /// The names in row [row] (1 front); none past the last.
  List<String> seatsIn(int row) => seatRows.elementAtOrNull(row - 1) ?? const [];

  /// The owner's: the car until one is picked.
  static const fallback = modelY7;

  /// The car a setting names, or null for one this build does not know
  /// (none saved yet, or saved by a newer one): then it is asked again.
  static Car? tryId(String? id) => values.where((c) => c.id == id).firstOrNull;

  String get label => [model.label, if (model == Model.y) '$seats seats', if (bothDrives) rwd ? 'RWD' : 'AWD'].join(' ');

  /// The first question's choices: each body and seats once (the two-motor
  /// one where both come), its drive the second question.
  static List<Car> get bodies => [for (final c in values) if (!c.rwd || !c.bothDrives) c];

  Car? withDrive({required bool rwd}) =>
      values.where((c) => c.model == model && c.seats == seats && c.rwd == rwd).firstOrNull;

  /// Its drive is the first launch's second question.
  bool get bothDrives => withDrive(rwd: !rwd) != null;
}

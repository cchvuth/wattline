// The cars: what the settings keep must keep meaning the same car, and each
// body's figures are its own.
import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_dash/car.dart';

void main() {
  test('a saved car reads back as itself; an unknown one is asked again', () {
    // The ids the settings have kept since 1.0: an install keeps its car.
    expect([for (final c in Car.values) c.id], ['model3rwd', 'model3', 'modelY5rwd', 'modelY5', 'modelY7']);
    for (final c in Car.values) {
      expect(Car.tryId(c.id), c);
    }
    expect(Car.tryId(null), isNull);
    expect(Car.tryId('cybertruck'), isNull);
    expect(Car.fallback, Car.modelY7); // until one is picked
  });

  test('the settings list and the first launch questions', () {
    expect([for (final c in Car.values) c.label],
        ['Model 3 RWD', 'Model 3 AWD', 'Model Y 5 seats RWD', 'Model Y 5 seats AWD', 'Model Y 7 seats']);
    // One picture per body and seats; the drive asked only where there are two.
    expect(Car.bodies, [Car.model3, Car.modelY5, Car.modelY7]);
    expect([for (final b in Car.bodies) b.bothDrives], [true, true, false]);
    expect(Car.model3.withDrive(rwd: true), Car.model3Rwd);
    expect(Car.modelY5Rwd.withDrive(rwd: false), Car.modelY5);
    expect(Car.modelY7.withDrive(rwd: true), isNull);
    expect([for (final c in Car.values) c.thirdRow], [false, false, false, false, true]);
  });

  test('each body its own steering', () {
    expect((Model.y.steerRatio, Model.y.wheelbase, Model.y.maxRoadDeg), (13.7, 2.89, 32.8));
    expect((Model.three.steerRatio, Model.three.wheelbase, Model.three.maxRoadDeg), (10.6, 2.875, 34.1));
    expect({for (final c in Car.values) c.model}, {Model.y, Model.three});
  });
}

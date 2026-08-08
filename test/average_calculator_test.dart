import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/Misc/average_calculator.dart';

void main() {
  test('no grades yet means the target is simply the target', () {
    // NaN is what the markbook produces when nothing is graded (0/0).
    expect(
      requiredAverage(currentAverage: double.nan, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(4, 0.001),
    );
    expect(
      requiredAverage(currentAverage: 0, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(4, 0.001),
    );
  });

  test('existing grades pull the requirement up or down', () {
    // 30 credits at 3.0, wanting 4.0 overall across 60 credits -> 5.0 needed.
    expect(
      requiredAverage(currentAverage: 3, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(5, 0.001),
    );
    // Already above target, so less is needed.
    expect(
      requiredAverage(currentAverage: 5, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(3, 0.001),
    );
  });

  test('unequal credit weights', () {
    // 60 credits at 4.5, 10 left, target 4.0 -> only 1.0 needed on the remainder.
    expect(
      requiredAverage(currentAverage: 4.5, currentCredits: 60, target: 4, remainingCredits: 10),
      closeTo(1.0, 0.001),
    );
  });

  test('no remaining credits is not answerable', () {
    expect(requiredAverage(currentAverage: 4, currentCredits: 30, target: 5, remainingCredits: 0), isNull);
  });
}

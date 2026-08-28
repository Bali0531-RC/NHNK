import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/haptics.dart';

void main() {
  // Android's VibrationEffect.createWaveform throws unless there is exactly one
  // amplitude per pattern slot. Every haptic used to pass amplitudes for the
  // vibrate slots only, so all of them threw and no haptic ever fired.
  test('every pattern slot gets an amplitude', () {
    final pattern = [0, 35, 125, 35];
    expect(AppHaptics.buildAmplitudes(pattern, [150, 100]).length, pattern.length);
  });

  test('wait slots are silent and vibrate slots keep their amplitude', () {
    expect(AppHaptics.buildAmplitudes([0, 35, 125, 35], [150, 100]), [0, 150, 0, 100]);
  });

  test('a short pattern still matches', () {
    expect(AppHaptics.buildAmplitudes([0, 10], [70]), [0, 70]);
  });

  test('missing amplitudes fall back to full strength rather than throwing', () {
    expect(AppHaptics.buildAmplitudes([0, 10, 20, 10], [70]), [0, 70, 0, 255]);
  });

  test('the bounce pattern lines up', () {
    final pattern = [0, 45, 75, 35, 70, 25, 45, 15, 25, 10, 10, 10, 5, 5];
    final amplitudes =
        AppHaptics.buildAmplitudes(pattern, [200, 170, 140, 110, 80, 55, 35]);
    expect(amplitudes.length, pattern.length);
    expect(amplitudes, [0, 200, 0, 170, 0, 140, 0, 110, 0, 80, 0, 55, 0, 35]);
  });
}

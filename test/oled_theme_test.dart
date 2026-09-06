import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/colors.dart';

/// An OLED theme is only worth having if picking it sticks. The palette values
/// themselves are checked by tool/contrast_check.py, which reads colors.dart.
void main() {
  test('only the two system themes follow the system brightness', () {
    expect(AppColors.followsSystemBrightness('Light'), isTrue);
    expect(AppColors.followsSystemBrightness('Dark'), isTrue);
    expect(AppColors.followsSystemBrightness(null), isTrue);
    expect(AppColors.followsSystemBrightness('OLED'), isFalse);
    expect(AppColors.followsSystemBrightness('SomeDownloadedTheme'), isFalse);
  });
}

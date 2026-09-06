import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/language.dart';

/// The OOBE rework promises English for users outside Hungary. This checks the
/// existing locale fallback actually delivers that, including for a language the
/// app has no pack for at all.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('an unsupported device locale falls back to the English pack', () {
    binding.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    AppStrings.initialize();

    expect(AppStrings.getCurrentLangCode(), isNot('hu'));
    expect(AppStrings.getLanguagePack().language_flag, '🇺🇸/🇬🇧');
  });
}

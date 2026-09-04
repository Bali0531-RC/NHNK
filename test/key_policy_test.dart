import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/dev/dev_diagnostics.dart';

void main() {
  test('plaintext credential keys are never even listed', () {
    for (final key in ['Password', 'AccessToken', 'Username', 'URL',
                       'URL_Fallbacks', 'ICS_FileLocation']) {
      expect(KeyPolicy.of(key), KeyTier.hidden, reason: '$key must not be listed');
    }
  });

  test('keystore-shaped keys are never listed either', () {
    expect(KeyPolicy.of('neptun_password'), KeyTier.hidden);
    expect(KeyPolicy.of('neptun_totp_secret'), KeyTier.hidden);
    expect(KeyPolicy.of('devicecookie_ABC123'), KeyTier.hidden);
  });

  // A boring looking key holding somebody's grades is the whole reason the
  // policy classifies by what the value is rather than what the name looks like.
  test('cached academic data is listed but never shown', () {
    for (final key in ['CachedMarkbook_3', 'CachedMails_0', 'CachedCalendar_12',
                       'CachedPayments_1', 'TermCache_70876', 'room_abc',
                       'teacher_abc', 'task_res_9']) {
      expect(KeyPolicy.of(key), KeyTier.opaque, reason: '$key must not show a value');
    }
  });

  test('settings and flags may show their value', () {
    expect(KeyPolicy.of('SETTING_NeedHaptics'), KeyTier.open);
    expect(KeyPolicy.of('CONFIG_IsInstalledFromGPlay'), KeyTier.open);
    expect(KeyPolicy.of('HasLogin'), KeyTier.open);
    expect(KeyPolicy.of('CalendarCacheTime'), KeyTier.open);
  });

  // The property that matters: the open tier is an allowlist, so forgetting to
  // classify a new key hides it rather than leaking it.
  test('a key nobody has classified yet defaults to withheld', () {
    expect(KeyPolicy.of('SomeKeyAddedNextYear'), KeyTier.opaque);
    expect(KeyPolicy.of('NeptunSessionThing'), KeyTier.opaque);
    expect(KeyPolicy.of(''), KeyTier.opaque);
  });
}

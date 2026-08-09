import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Platform checks that also survive the web build.
///
/// dart:io's Platform throws the moment it is touched on web, so nothing here may
/// import it. The Android-only checks left in the codebase are deliberate: Play
/// in-app updates and APK self-install have no iOS equivalent.
class AppPlatform {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile => isAndroid || isIOS;

  /// Same shape as Platform.localeName ("hu_HU"), read from the engine instead.
  static String get localeName {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    return country == null || country.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$country';
  }
}

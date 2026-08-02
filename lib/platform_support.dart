import 'dart:io';

/// Guards for plugins that work on phones but not on the desktop build.
///
/// The Android-only checks left in the codebase are deliberate: Play in-app
/// updates and APK self-install have no iOS equivalent.
class AppPlatform {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
}

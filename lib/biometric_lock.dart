import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'Pages/main_page.dart' as main_page;
import 'colors.dart';
import 'haptics.dart';
import 'language.dart';
import 'platform_support.dart';
import 'storage.dart';

/// Device biometric / PIN / pattern lock gate.
///
/// Kept separate from [FlutterSecureStorage] so background WorkManager checks and
/// home-screen widget refreshes can still read credentials while the phone is in a
/// pocket with the screen locked.
class BiometricLock {
  static const MethodChannel channel = MethodChannel('hu.bali0531.nhnk/biometrics');

  static bool _sessionUnlocked = false;
  static bool get isSessionUnlocked => _sessionUnlocked;

  static void markSessionUnlocked() {
    _sessionUnlocked = true;
  }

  static void resetSession() {
    _sessionUnlocked = false;
  }

  /// True when the current account should be gated by biometric/device credential lock.
  static bool shouldRequireLock() {
    if (AppPlatform.isWeb) return false;
    if (!(DataCache.getHasLogin() ?? false)) return false;
    if (DataCache.getIsDemoAccount() ?? false) return false;
    return DataCache.getBiometricLockEnabled();
  }

  /// Returns true if the device has a secure lock screen or biometrics configured.
  static Future<bool> isDeviceSupported() async {
    if (!AppPlatform.isMobile) return false;
    try {
      return await channel.invokeMethod<bool>('isDeviceSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Prompts the OS biometric / PIN / pattern sheet.
  /// If the device has no lock screen configured at all, returns true so the user
  /// is never locked out.
  static Future<bool> authenticate({String? title, String? subtitle}) async {
    if (!AppPlatform.isMobile) return true;
    final isHu = AppStrings.getCurrentLangCode() == 'hu';
    try {
      final supported = await isDeviceSupported();
      if (!supported) {
        return true;
      }
      final ok = await channel.invokeMethod<bool>('authenticate', <String, String>{
        'title': title ?? (isHu ? 'NHNK feloldása' : 'Unlock NHNK'),
        'subtitle': subtitle ??
            (isHu
                ? 'Azonosítsd magad ujjlenyomattal, arccal vagy képernyőzárral'
                : 'Authenticate with biometrics or your screen lock'),
        'cancel': isHu ? 'Mégse' : 'Cancel',
      });
      if (ok ?? false) {
        _sessionUnlocked = true;
        return true;
      }
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }
}

/// Wraps [main_page.HomePage] when biometric lock is active and the session has not
/// been unlocked yet.
class BiometricLockGate extends StatefulWidget {
  final Widget child;

  const BiometricLockGate({
    super.key,
    this.child = const main_page.HomePage(),
  });

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  bool _unlocked = false;
  bool _authenticating = false;

  String _t(String hu, String en) => AppStrings.getCurrentLangCode() == 'hu' ? hu : en;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    if (!BiometricLock.shouldRequireLock() || BiometricLock.isSessionUnlocked) {
      _unlocked = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _unlock();
      });
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || _unlocked) return;
    setState(() => _authenticating = true);
    final ok = await BiometricLock.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return widget.child;
    }

    final theme = AppColors.getTheme();
    return Scaffold(
      backgroundColor: theme.rootBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: theme.secondary.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.large)),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 42,
                    color: theme.secondary,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _t('Az NHNK zárolva van', 'NHNK is locked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'A folytatáshoz oldd fel ujjlenyomattal, arcfelismeréssel vagy a készülék képernyőzárával.',
                    'Unlock with your fingerprint, face or device screen lock to continue.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedText(0.65),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _authenticating
                        ? null
                        : () {
                            AppHaptics.lightImpact();
                            _unlock();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.secondary,
                      foregroundColor: theme.onSecondary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(
                      _t('Feloldás', 'Unlock'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

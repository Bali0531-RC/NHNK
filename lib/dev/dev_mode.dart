import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../storage.dart';

/// The hidden developer tab.
///
/// Off by default and unlocked by tapping the version badge in About. The tab
/// shows storage and network activity, so it is deliberately awkward to reach
/// rather than a switch someone flips by accident.
class DevMode {
  static const String _key = 'DEV_ModeEnabled';
  static const int tapsToUnlock = 7;

  static bool _enabled = false;
  static int _taps = 0;

  static bool get isEnabled => _enabled;

  static Future<void> load() async {
    _enabled = (await getInt(_key) ?? 0) != 0;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    await saveInt(_key, value ? 1 : 0);
    if (!value) {
      // Leaving developer mode should not leave a browsable history behind.
      NetTraceBridge.clear();
      DevLog.clear();
    }
  }

  /// Returns how many taps remain, or 0 once unlocked.
  static int registerTap() {
    if (_enabled) return 0;
    _taps++;
    final left = tapsToUnlock - _taps;
    if (left <= 0) {
      _taps = 0;
      setEnabled(true);
      return 0;
    }
    return left;
  }

  static void resetTaps() => _taps = 0;
}

/// Indirection so [DevMode] does not have to import the trace layer.
class NetTraceBridge {
  static void Function()? onClear;
  static void clear() => onClear?.call();
}

/// Keeps the most recent notable lines so a bug report does not require a cable
/// and a laptop.
///
/// Hooking debugPrint alone would leave this empty in release, which is the only
/// build the tab actually ships in, so uncaught errors are recorded directly.
/// Nothing is written to disk; the buffer dies with the process.
class DevLog {
  static const int _max = 400;
  static final Queue<String> _lines = Queue<String>();
  static bool _installed = false;

  static List<String> get lines => List.unmodifiable(_lines);

  static void record(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _lines.addLast('$stamp  $message');
    while (_lines.length > _max) {
      _lines.removeFirst();
    }
  }

  static void install() {
    if (_installed) return;
    _installed = true;

    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) record(message);
      previousPrint(message, wrapWidth: wrapWidth);
    };

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      record('flutter error: ${details.exceptionAsString()}');
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      record('uncaught: $error');
      return false;
    };
  }

  static void clear() => _lines.clear();
}

/// Counts janky frames.
///
/// A frame that takes longer than the display's budget is a dropped one. The
/// counter answers "is scrolling actually bad" with a number instead of a
/// feeling, which is what a reviewer told me they could not judge.
class FrameStats {
  static const int _historyLength = 120;
  static const double budgetMs = 16.7;
  static const double severeMs = 33.3;

  static final List<double> _recent = [];
  static int _total = 0;
  static int _janky = 0;
  static int _severe = 0;
  static double _worst = 0;
  static bool _installed = false;

  static List<double> get recent => List.unmodifiable(_recent);
  static int get total => _total;
  static int get janky => _janky;
  static int get severe => _severe;
  static double get worst => _worst;

  static double get jankPercent => _total == 0 ? 0 : (_janky / _total) * 100;

  static void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final ms = t.totalSpan.inMicroseconds / 1000.0;
        _total++;
        if (ms > budgetMs) _janky++;
        if (ms > severeMs) _severe++;
        if (ms > _worst) _worst = ms;
        _recent.add(ms);
        if (_recent.length > _historyLength) {
          _recent.removeRange(0, _recent.length - _historyLength);
        }
      }
    });
  }

  static void reset() {
    _recent.clear();
    _total = 0;
    _janky = 0;
    _severe = 0;
    _worst = 0;
  }
}

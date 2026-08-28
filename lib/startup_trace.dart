import 'package:flutter/foundation.dart';

/// Timings for the cold start path.
///
/// The app had no instrumentation at all, so "is startup slow" was only ever
/// answered by feel. Android's am start -W stops at the native splash, which
/// says nothing about how long the timetable takes to appear.
///
/// Marks go to stdout rather than developer.log, which profile builds do not
/// forward to logcat. Read them with:
///   adb logcat -s flutter | grep NHNK-TRACE
class StartupTrace {
  static final Stopwatch _watch = Stopwatch();
  static final List<MapEntry<String, int>> _marks = [];
  static bool _finished = false;

  /// Called as early as main() can manage.
  static void begin() {
    if (kReleaseMode) return;
    if (_watch.isRunning) return;
    _watch.start();
    _marks.clear();
    _finished = false;
  }

  static void mark(String label) {
    if (!_watch.isRunning || _finished) return;
    final ms = _watch.elapsedMilliseconds;
    _marks.add(MapEntry(label, ms));
    debugPrint('NHNK-TRACE $ms ms  $label');
  }

  /// The moment the user can actually see their timetable.
  static void finish(String label) {
    if (!_watch.isRunning || _finished) return;
    mark(label);
    _finished = true;
    _watch.stop();

    if (kReleaseMode) return;
    var previous = 0;
    for (final entry in _marks) {
      debugPrint('NHNK-TRACE-SUM '
          '${entry.value.toString().padLeft(5)} ms  '
          '(+${(entry.value - previous).toString().padLeft(4)})  ${entry.key}');
      previous = entry.value;
    }
  }
}

/// Counts and times Neptun API calls.
///
/// Only the URL path is logged. Query strings and bodies carry credentials and
/// must never reach logcat.
class NetTrace {
  static int _count = 0;
  static int _totalMs = 0;

  static void record(String path, int ms) {
    if (kReleaseMode) return;
    _count++;
    _totalMs += ms;
    debugPrint('NHNK-NET #$_count  ${ms.toString().padLeft(5)} ms  $path'
        '  (total ${_totalMs}ms)');
  }

  static void reset(String label) {
    if (kReleaseMode) return;
    debugPrint('NHNK-NET reset at $label: was $_count calls / $_totalMs ms');
    _count = 0;
    _totalMs = 0;
  }
}

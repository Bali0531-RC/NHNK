import 'package:flutter/foundation.dart';

/// Timings for the cold start path.
///
/// The app had no instrumentation at all, so "is startup slow" was only ever
/// answered by feel. Android's am start -W stops at the native splash, which
/// says nothing about how long the timetable takes to appear.
///
/// Marks are kept in memory in every build so the developer tab can show them.
/// Printing stays out of release, where it would only be noise.
class StartupTrace {
  static final Stopwatch _watch = Stopwatch();
  static final List<MapEntry<String, int>> _marks = [];
  static bool _finished = false;

  static List<MapEntry<String, int>> get marks => List.unmodifiable(_marks);
  static bool get hasFinished => _finished;

  /// Called as early as main() can manage.
  static void begin() {
    if (_watch.isRunning) return;
    _watch.start();
    _marks.clear();
    _finished = false;
  }

  static void mark(String label) {
    if (!_watch.isRunning || _finished) return;
    final ms = _watch.elapsedMilliseconds;
    _marks.add(MapEntry(label, ms));
    if (!kReleaseMode) debugPrint('NHNK-TRACE $ms ms  $label');
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

/// One line of the network log, already stripped of anything private.
///
/// There is no field here for a query string, a body or a header, so a screen
/// rendering these cannot show one by mistake.
@immutable
class NetEntry {
  final DateTime at;
  final String method;
  final String host;
  final String path;
  final int? status;
  final int ms;
  final int bytes;
  final int sentBytes;
  final bool failed;

  const NetEntry({
    required this.at,
    required this.method,
    required this.host,
    required this.path,
    required this.status,
    required this.ms,
    required this.bytes,
    required this.sentBytes,
    required this.failed,
  });
}

/// Records every Neptun call, with the redaction done here rather than at the
/// call sites.
///
/// [record] deliberately takes the whole [Uri] and throws away everything except
/// host and path. A "log this string" API would eventually mean somebody logs a
/// full URL, and one of ours is itself a credential: the calendar export link
/// authenticates on its own, so printing it hands the timetable to anyone
/// reading the screen. Those pass [redactUrl].
class NetTrace {
  static const int _maxEntries = 200;
  static final List<NetEntry> _entries = [];

  static int _count = 0;
  static int _totalMs = 0;
  static int _received = 0;
  static int _sent = 0;
  static final DateTime _startedAt = DateTime.now();

  static List<NetEntry> get entries => List.unmodifiable(_entries);
  static int get count => _count;
  static int get totalMs => _totalMs;

  /// Wired up by main() so failures reach the developer log without this file
  /// having to know the log exists.
  static void Function(String)? onNotable;
  static int get receivedBytes => _received;
  static int get sentBytes => _sent;

  /// Average bytes per second across the whole session, downloaded plus uploaded.
  static double get bytesPerSecond {
    final seconds = DateTime.now().difference(_startedAt).inMilliseconds / 1000.0;
    if (seconds <= 0) return 0;
    return (_received + _sent) / seconds;
  }

  /// Throughput over the last [window], which is what "is it slow right now"
  /// actually means.
  static double recentBytesPerSecond({Duration window = const Duration(seconds: 10)}) {
    final cutoff = DateTime.now().subtract(window);
    var total = 0;
    for (final e in _entries) {
      if (e.at.isAfter(cutoff)) total += e.bytes + e.sentBytes;
    }
    return total / window.inSeconds;
  }

  static void record(
    Uri url,
    int ms, {
    String method = 'POST',
    int? status,
    int bytes = 0,
    int sentBytes = 0,
    bool failed = false,
    bool redactUrl = false,
  }) {
    _count++;
    _totalMs += ms;
    _received += bytes;
    _sent += sentBytes;

    _entries.add(NetEntry(
      at: DateTime.now(),
      method: method,
      // Only these two survive. url.query, url.userInfo and url.fragment are
      // dropped here and there is nowhere further down to put them.
      host: redactUrl ? 'self-authenticating link' : url.host,
      path: redactUrl ? '(redacted)' : url.path,
      status: status,
      ms: ms,
      bytes: bytes,
      sentBytes: sentBytes,
      failed: failed,
    ));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    if (failed || (status ?? 200) >= 400) {
      final where = redactUrl ? '(redacted)' : url.path;
      onNotable?.call(failed
          ? '$method $where failed after ${ms}ms'
          : '$method $where returned $status');
    }

    if (!kReleaseMode) {
      final where = redactUrl ? '(redacted)' : url.path;
      debugPrint('NHNK-NET #$_count  ${ms.toString().padLeft(5)} ms  $where'
          '  (total ${_totalMs}ms)');
    }
  }

  static void reset(String label) {
    if (!kReleaseMode) {
      debugPrint('NHNK-NET reset at $label: was $_count calls / $_totalMs ms');
    }
    _count = 0;
    _totalMs = 0;
  }

  /// Dropped on sign out, so a shared phone keeps nothing.
  static void clear() {
    _entries.clear();
    _count = 0;
    _totalMs = 0;
    _received = 0;
    _sent = 0;
  }
}

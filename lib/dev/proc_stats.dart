import 'dart:io';

/// Process counters read straight out of /proc.
///
/// A process may always read its own /proc entries, so none of this needs a
/// permission or a platform channel. Everything is best effort: if a field is
/// missing or the format differs, the getter returns null rather than throwing
/// inside a diagnostics screen.
class ProcStats {
  /// The kernel reports CPU time in clock ticks. Android has used 100 Hz for as
  /// long as anyone cares about, and there is no portable way to ask from Dart.
  static const int _ticksPerSecond = 100;

  static int? _lastTicks;
  static DateTime? _lastSampledAt;
  static double _cpuPercent = 0;
  static DateTime? _launchedAt;

  static double get cpuPercent => _cpuPercent;

  static bool get available => Platform.isAndroid || Platform.isLinux;

  /// Called from main(). /proc/uptime is not readable by an app on recent
  /// Android, so the clock starts at Dart main rather than at process fork.
  static void markLaunch() => _launchedAt ??= DateTime.now();

  /// CPU used since the previous call, as a percentage of one core.
  ///
  /// Needs two samples to say anything, so the first call always reports the
  /// previous value.
  static double sampleCpu() {
    if (!available) return 0;
    final ticks = _readCpuTicks();
    final now = DateTime.now();
    if (ticks == null) return _cpuPercent;

    final lastTicks = _lastTicks;
    final lastAt = _lastSampledAt;
    _lastTicks = ticks;
    _lastSampledAt = now;

    if (lastTicks == null || lastAt == null) return _cpuPercent;
    final elapsed = now.difference(lastAt).inMicroseconds / 1000000.0;
    if (elapsed <= 0) return _cpuPercent;

    final seconds = (ticks - lastTicks) / _ticksPerSecond;
    _cpuPercent = (seconds / elapsed) * 100;
    if (_cpuPercent < 0) _cpuPercent = 0;
    return _cpuPercent;
  }

  static int? _readCpuTicks() {
    try {
      final raw = File('/proc/self/stat').readAsStringSync();
      // The comm field is wrapped in parentheses and may itself contain spaces,
      // so fields are counted from after the last ')'.
      final tail = raw.substring(raw.lastIndexOf(')') + 2).split(' ');
      // After comm and state, utime is index 11 and stime 12.
      final utime = int.tryParse(tail[11]);
      final stime = int.tryParse(tail[12]);
      if (utime == null || stime == null) return null;
      return utime + stime;
    } catch (_) {
      return null;
    }
  }

  static Map<String, int> _readStatus(Set<String> wanted) {
    final out = <String, int>{};
    if (!available) return out;
    try {
      for (final line in File('/proc/self/status').readAsLinesSync()) {
        final colon = line.indexOf(':');
        if (colon < 0) continue;
        final key = line.substring(0, colon);
        if (!wanted.contains(key)) continue;
        final digits = RegExp(r'\d+').firstMatch(line.substring(colon));
        if (digits != null) out[key] = int.parse(digits.group(0)!);
      }
    } catch (_) { }
    return out;
  }

  /// Resident and peak memory in bytes, plus the thread count.
  static Map<String, int> memory() {
    final status = _readStatus({'VmRSS', 'VmHWM', 'Threads'});
    return {
      if (status['VmRSS'] != null) 'rss': status['VmRSS']! * 1024,
      if (status['VmHWM'] != null) 'peak': status['VmHWM']! * 1024,
      if (status['Threads'] != null) 'threads': status['Threads']!,
      if (proportionalSet() != null) 'pss': proportionalSet()!,
    };
  }

  /// Proportional set size: shared pages divided by how many processes map them.
  ///
  /// RSS counts the whole Flutter engine, the mapped fonts and the apk itself,
  /// most of which is shared with the zygote, so it reads far higher than what
  /// the app actually costs. Returns null where SELinux blocks the read.
  static int? proportionalSet() {
    if (!available) return null;
    try {
      for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
        if (line.startsWith('Pss:')) {
          final digits = RegExp(r'\d+').firstMatch(line);
          if (digits != null) return int.parse(digits.group(0)!) * 1024;
        }
      }
    } catch (_) { }
    return null;
  }

  /// Device wide memory, so "the app uses 180 MB" has something to sit against.
  static Map<String, int> systemMemory() {
    final out = <String, int>{};
    if (!available) return out;
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        for (final key in const ['MemTotal', 'MemAvailable']) {
          if (line.startsWith('$key:')) {
            final digits = RegExp(r'\d+').firstMatch(line);
            if (digits != null) out[key] = int.parse(digits.group(0)!) * 1024;
          }
        }
      }
    } catch (_) { }
    return out;
  }

  /// Time since the app started.
  static Duration? uptime() {
    final launched = _launchedAt;
    if (launched == null) return null;
    return DateTime.now().difference(launched);
  }
}

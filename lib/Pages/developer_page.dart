import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../colors.dart';
import '../dev/dev_diagnostics.dart';
import '../dev/dev_mode.dart';
import '../dev/proc_stats.dart';
import '../haptics.dart';
import '../startup_trace.dart';

/// Everything the app knows about itself, minus everything it must not say.
///
/// Reachable only after unlocking developer mode in About. What each section may
/// render is decided by [KeyPolicy] and by [NetTrace], not here, so this file
/// cannot widen it by accident.
class DeveloperPage extends StatefulWidget {
  const DeveloperPage({super.key});

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  List<StoredKey> _keys = const [];
  List<CacheEntry> _caches = const [];
  Map<String, String> _build = const {};
  Map<String, int> _footprint = const {};
  bool _loading = true;

  Timer? _ticker;
  final List<double> _cpuHistory = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    // The live numbers are only meaningful as a series, so they sample on their
    // own rather than waiting for a pull to refresh.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final cpu = ProcStats.sampleCpu();
      _cpuHistory.add(cpu);
      if (_cpuHistory.length > 60) _cpuHistory.removeAt(0);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final keys = await DevDiagnostics.readStoredKeys();
    final caches = await DevDiagnostics.readCaches();
    final build = await DevDiagnostics.readBuildInfo();
    final footprint = await DevDiagnostics.readFootprint();
    if (!mounted) return;
    setState(() {
      _keys = keys;
      _caches = caches;
      _build = build;
      _footprint = footprint;
      _loading = false;
    });
  }

  String _bytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _ago(Duration? d) {
    if (d == null) return 'never';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        foregroundColor: theme.textColor,
        title: const Text('Developer'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: theme.textColor))
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _buildSection(theme),
                _liveSection(theme),
                _startupSection(theme),
                _frameSection(theme),
                _networkSection(theme),
                _cacheSection(theme),
                _storageSection(theme),
                _logSection(theme),
                _exportSection(theme),
                _dangerSection(theme),
              ],
            ),
    );
  }

  Widget _header(AppPalette theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: AppColors.mutedText(0.55), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card(AppPalette theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _row(AppPalette theme, String left, String right, {Color? rightColour}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(left, style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5)),
          ),
          Expanded(
            flex: 5,
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: rightColour ?? theme.textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rate(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(2)} MB/s';
  }

  String _duration(Duration? d) {
    if (d == null) return 'unknown';
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  /// Live counters, sampled once a second.
  Widget _liveSection(AppPalette theme) {
    final mem = ProcStats.memory();
    final sys = ProcStats.systemMemory();
    final cpu = ProcStats.cpuPercent;
    final cpuColour = cpu > 60 ? theme.errorRed : cpu > 25 ? Colors.amber.shade600 : theme.currentClassGreen;

    final rss = mem['rss'] ?? _footprint['rss'] ?? 0;
    final total = sys['MemTotal'] ?? 0;
    final share = total == 0 ? 0.0 : (rss / total) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Live', 'sampled every second while this screen is open'),
        _card(theme, [
          _row(theme, 'cpu (one core)', '${cpu.toStringAsFixed(1)} %', rightColour: cpuColour),
          if (_cpuHistory.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: CustomPaint(
                size: const Size(double.infinity, 38),
                painter: _SparkPainter(
                  samples: _cpuHistory,
                  ceiling: 100,
                  colour: cpuColour,
                  guide: theme.textColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          _row(theme, 'threads', '${mem['threads'] ?? 0}'),
          _row(theme, 'process uptime', _duration(ProcStats.uptime())),
          const Divider(height: 18),
          if (mem['pss'] != null)
            _row(theme, 'memory (pss)', _bytes(mem['pss']!)),
          _row(theme, 'memory (rss)', _bytes(rss)),
          _row(theme, 'memory peak', _bytes(mem['peak'] ?? _footprint['peakRss'] ?? 0)),
          if (mem['pss'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'pss is the honest one. rss counts the engine, fonts and apk that are shared with other apps.',
                style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 10.5),
              ),
            ),
          if (total > 0) ...[
            _row(theme, 'device memory', '${_bytes(sys['MemAvailable'] ?? 0)} free of ${_bytes(total)}'),
            _row(theme, 'this app', '${share.toStringAsFixed(1)} % of device memory'),
          ],
          const Divider(height: 18),
          _row(theme, 'downloaded', _bytes(NetTrace.receivedBytes)),
          _row(theme, 'uploaded', _bytes(NetTrace.sentBytes)),
          _row(theme, 'session average', _rate(NetTrace.bytesPerSecond)),
          _row(theme, 'last 10 seconds', _rate(NetTrace.recentBytesPerSecond())),
        ]),
      ],
    );
  }

  Widget _buildSection(AppPalette theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Build', 'what is actually running'),
        _card(theme, [
          for (final e in _build.entries) _row(theme, e.key, e.value),
        ]),
      ],
    );
  }

  Widget _startupSection(AppPalette theme) {
    final marks = StartupTrace.marks;
    if (marks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, 'Startup', 'time to a visible timetable'),
          _card(theme, [Text('No marks recorded.', style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5))]),
        ],
      );
    }
    final total = marks.last.value;
    var previous = 0;
    final rows = <Widget>[];
    for (final m in marks) {
      final delta = m.value - previous;
      previous = m.value;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              child: Text('${m.value} ms',
                  style: TextStyle(color: theme.textColor, fontSize: 11.5, fontFamily: 'monospace')),
            ),
            Expanded(
              child: Stack(
                children: [
                  Container(height: 14, decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  )),
                  FractionallySizedBox(
                    widthFactor: total == 0 ? 0 : (delta / total).clamp(0.02, 1.0),
                    child: Container(height: 14, decoration: BoxDecoration(
                      color: theme.secondary,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: Text(m.key,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 11)),
            ),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Startup', 'time to a visible timetable'),
        _card(theme, [...rows, const SizedBox(height: 6), _row(theme, 'total', '$total ms')]),
      ],
    );
  }

  Widget _frameSection(AppPalette theme) {
    final pct = FrameStats.jankPercent;
    final colour = pct > 10 ? theme.errorRed : pct > 3 ? Colors.amber.shade600 : theme.currentClassGreen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Frames', 'anything over 16.7 ms dropped a frame'),
        _card(theme, [
          _row(theme, 'frames measured', '${FrameStats.total}'),
          _row(theme, 'over budget', '${FrameStats.janky}  (${pct.toStringAsFixed(1)}%)', rightColour: colour),
          _row(theme, 'over 33 ms', '${FrameStats.severe}'),
          _row(theme, 'worst', '${FrameStats.worst.toStringAsFixed(1)} ms'),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: CustomPaint(
              size: const Size(double.infinity, 44),
              painter: _FramePainter(
                samples: FrameStats.recent,
                budget: FrameStats.budgetMs,
                good: theme.currentClassGreen,
                bad: theme.errorRed,
                guide: theme.textColor.withValues(alpha: 0.18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () { FrameStats.reset(); setState(() {}); },
              child: Text('Reset', style: TextStyle(color: theme.secondary, fontSize: 12)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _networkSection(AppPalette theme) {
    final entries = NetTrace.entries.reversed.take(40).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Network', 'host and path only, never queries or bodies'),
        _card(theme, [
          _row(theme, 'calls this session', '${NetTrace.count}'),
          _row(theme, 'time in requests', '${NetTrace.totalMs} ms'),
          const Divider(height: 18),
          if (entries.isEmpty)
            Text('Nothing yet.', style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5)),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(e.method,
                        style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 10.5, fontFamily: 'monospace')),
                  ),
                  Expanded(
                    child: Text(
                      e.path,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textColor, fontSize: 11.5, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e.failed ? 'failed' : '${e.status ?? "-"}',
                    style: TextStyle(
                      color: e.failed || (e.status ?? 200) >= 400 ? theme.errorRed : theme.currentClassGreen,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: Text('${e.ms} ms',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 11, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  Widget _cacheSection(AppPalette theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Caches', 'age against the TTL each one uses'),
        _card(theme, [
          for (final c in _caches)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(c.label, style: TextStyle(color: theme.textColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _ago(c.age),
                      style: TextStyle(
                        color: c.isStale ? Colors.amber.shade600 : theme.currentClassGreen,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${c.ttl.inHours}h',
                        style: TextStyle(color: AppColors.mutedText(0.55), fontSize: 11.5, fontFamily: 'monospace')),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Invalidate',
                    icon: Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.mutedText(0.6)),
                    onPressed: () async {
                      AppHaptics.lightImpact();
                      await DevDiagnostics.invalidate(c.key);
                      await _refresh();
                    },
                  ),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  Widget _storageSection(AppPalette theme) {
    final opaque = _keys.where((k) => k.tier == KeyTier.opaque).length;
    final open = _keys.where((k) => k.tier == KeyTier.open).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Storage', '$open shown, $opaque withheld, credentials not listed'),
        _card(theme, [
          _row(theme, 'memory now', _bytes(_footprint['rss'] ?? 0)),
          _row(theme, 'memory peak', _bytes(_footprint['peakRss'] ?? 0)),
          _row(theme, 'documents', _bytes(_footprint['documents'] ?? 0)),
          _row(theme, 'cache dir', _bytes(_footprint['cache'] ?? 0)),
          const Divider(height: 18),
          for (final k in _keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(k.key,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textColor, fontSize: 11.5, fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Text(
                      k.value ?? '${k.type} · ${_bytes(k.bytes)}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: k.value == null ? AppColors.mutedText(0.5) : theme.secondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontStyle: k.value == null ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  Widget _logSection(AppPalette theme) {
    final lines = DevLog.lines.reversed.take(60).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Log', '${DevLog.lines.length} errors and failed requests, memory only'),
        _card(theme, [
          if (lines.isEmpty)
            Text('Nothing captured.', style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5))
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(lines[i],
                      style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 10.5, fontFamily: 'monospace')),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  /// Built from the same redacted material the screen shows.
  ///
  /// This one leaves the device, so it matters more than the display does: the
  /// storage section reuses [KeyPolicy], meaning withheld values stay withheld
  /// and credential keys are not listed at all.
  String _diagnosticsReport() {
    final b = StringBuffer('NHNK diagnostics\n');
    b.writeln('generated ${DateTime.now().toIso8601String()}');
    b.writeln('no credentials, request bodies, query strings or cached academic '
        'data are included\n');
    _build.forEach((k, v) => b.writeln('$k: $v'));

    final mem = ProcStats.memory();
    final sys = ProcStats.systemMemory();
    b.writeln('\nprocess');
    b.writeln('  cpu: ${ProcStats.cpuPercent.toStringAsFixed(1)}% of one core');
    b.writeln('  threads: ${mem['threads'] ?? 0}');
    b.writeln('  uptime: ${_duration(ProcStats.uptime())}');
    b.writeln('  memory: ${_bytes(mem['rss'] ?? 0)} rss'
        '${mem['pss'] != null ? ", ${_bytes(mem['pss']!)} pss" : ""}'
        ', peak ${_bytes(mem['peak'] ?? 0)}');
    if ((sys['MemTotal'] ?? 0) > 0) {
      b.writeln('  device memory: ${_bytes(sys['MemAvailable'] ?? 0)} free of ${_bytes(sys['MemTotal']!)}');
    }
    b.writeln('  storage: ${_bytes(_footprint['documents'] ?? 0)} documents, ${_bytes(_footprint['cache'] ?? 0)} cache');

    b.writeln('\nstartup');
    for (final m in StartupTrace.marks) {
      b.writeln('  ${m.value} ms  ${m.key}');
    }
    b.writeln('\nframes: ${FrameStats.total} measured, ${FrameStats.janky} over budget, worst ${FrameStats.worst.toStringAsFixed(1)} ms');
    b.writeln('\nnetwork: ${NetTrace.count} calls, ${NetTrace.totalMs} ms');
    b.writeln('  ${_bytes(NetTrace.receivedBytes)} down, ${_bytes(NetTrace.sentBytes)} up, '
        '${_rate(NetTrace.bytesPerSecond)} average');
    for (final e in NetTrace.entries.reversed.take(40)) {
      b.writeln('  ${e.method} ${e.path} ${e.status ?? "-"} ${e.ms}ms ${_bytes(e.bytes)}');
    }

    b.writeln('\ncaches');
    for (final c in _caches) {
      b.writeln('  ${c.label}: ${_ago(c.age)}${c.isStale ? " (stale)" : ""} (ttl ${c.ttl.inHours}h)');
    }

    final withheld = _keys.where((k) => k.tier == KeyTier.opaque).length;
    b.writeln('\nstored keys (${_keys.length} listed, $withheld values withheld)');
    for (final k in _keys) {
      b.writeln('  ${k.key} = ${k.value ?? "<${k.type}, ${_bytes(k.bytes)}>"}');
    }

    final log = DevLog.lines;
    b.writeln('\nlog (${log.length} lines)');
    if (log.isEmpty) {
      b.writeln('  nothing recorded');
    } else {
      for (final line in log.reversed.take(80)) {
        b.writeln('  $line');
      }
    }
    return b.toString();
  }

  Future<void> _shareReport() async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${dir.path}/nhnk-diagnostics-$stamp.txt');
      await file.writeAsString(_diagnosticsReport(), flush: true);

      // Same lesson as the calendar export: without an explicit type this lands
      // on a generic previewer that refuses to open it.
      final result = await OpenFilex.open(file.path, type: 'text/plain');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not write the report: $e')),
      );
    }
  }

  Widget _exportSection(AppPalette theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(theme, 'Export', 'for attaching to a bug report'),
        _card(theme, [
          Text(
            'Everything on this page, with the same things left out. No password, '
            'no tokens, no request bodies, and cached grades and messages appear '
            'as sizes rather than contents.',
            style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _diagnosticsReport()));
                    AppHaptics.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diagnostics copied')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.secondary,
                    side: BorderSide(color: theme.secondary.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () { AppHaptics.lightImpact(); _shareReport(); },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.secondary,
                    foregroundColor: theme.rootBackground,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: const Text('Save as file'),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _dangerSection(AppPalette theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: OutlinedButton.icon(
        onPressed: () async {
          await DevMode.setEnabled(false);
          if (!context.mounted) return;
          Navigator.of(context).pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.errorRed,
          side: BorderSide(color: theme.errorRed.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.lock_rounded, size: 18),
        label: const Text('Turn developer mode off'),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> samples;
  final double ceiling;
  final Color colour;
  final Color guide;

  _SparkPainter({
    required this.samples,
    required this.ceiling,
    required this.colour,
    required this.guide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2),
        Paint()..color = guide..strokeWidth = 1);

    final step = size.width / (samples.length - 1);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final y = size.height - (samples[i] / ceiling).clamp(0.0, 1.0) * size.height;
      final x = i * step;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

class _FramePainter extends CustomPainter {
  final List<double> samples;
  final double budget;
  final Color good;
  final Color bad;
  final Color guide;

  _FramePainter({
    required this.samples,
    required this.budget,
    required this.good,
    required this.bad,
    required this.guide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final ceiling = (samples.reduce((a, b) => a > b ? a : b)).clamp(budget * 1.5, 80.0);
    final barWidth = size.width / samples.length;

    final guideY = size.height - (budget / ceiling) * size.height;
    canvas.drawLine(Offset(0, guideY), Offset(size.width, guideY), Paint()..color = guide..strokeWidth = 1);

    for (var i = 0; i < samples.length; i++) {
      final h = (samples[i] / ceiling).clamp(0.0, 1.0) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth * 0.8, h),
        Paint()..color = samples[i] > budget ? bad : good,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => true;
}

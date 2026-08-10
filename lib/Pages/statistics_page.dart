import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';

/// Semester history: averages, credits and grade spread across every term.
///
/// The charts are painted by hand rather than pulled from a package. A chart
/// library would add more to the download than the whole feature is worth, and
/// the web demo pays for every kilobyte.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<api.SemesterResult> _semesters = [];
  bool _loading = true;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await api.MarkbookRequest.getSemesterHistory(force: force);
    if (!mounted) return;
    setState(() {
      _semesters = data;
      _loading = false;
    });
  }

  bool get _hu => AppStrings.getCurrentLangCode() == 'hu';

  String _t(String hu, String en) => _hu ? hu : en;

  /// Weighted across every term, which is the number that decides scholarships.
  double get _cumulativeAverage {
    var points = 0.0;
    var credits = 0;
    for (final s in _semesters) {
      for (final sub in s.subjects) {
        if (sub.completed && sub.grade >= 2) {
          points += sub.grade * sub.credit;
          credits += sub.credit;
        }
      }
    }
    return credits == 0 ? 0 : points / credits;
  }

  int get _totalCompletedCredits =>
      _semesters.fold(0, (a, s) => a + s.completedCredits);

  Map<int, int> get _overallDistribution {
    final out = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
    for (final s in _semesters) {
      s.gradeDistribution.forEach((k, v) => out[k] = out[k]! + v);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();

    return Scaffold(
      backgroundColor: theme.rootBackground,
      appBar: AppBar(
        backgroundColor: theme.rootBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
          tooltip: _t('Vissza', 'Back'),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _t('Statisztika', 'Statistics'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textColor),
            tooltip: _t('Frissítés', 'Refresh'),
            onPressed: _loading
                ? null
                : () {
                    AppHaptics.lightImpact();
                    _load(force: true);
                  },
          ),
        ],
      ),
      body: _loading
          ? _buildLoading(theme)
          : _semesters.isEmpty
              ? _buildEmpty(theme)
              : _buildContent(theme),
    );
  }

  Widget _buildLoading(AppPalette theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.secondary),
          const SizedBox(height: 20),
          Text(
            _t('Félévek betöltése...', 'Loading semesters...'),
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.6), fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 260,
            child: Text(
              _t('Az első lekérés hosszabb, utána a lezárt félévek a gyorsítótárból jönnek.',
                  'The first fetch is slow; after that closed semesters come from the cache.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.4), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppPalette theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 56, color: theme.textColor.withValues(alpha: 0.25)),
            const SizedBox(height: 18),
            Text(
              _t('Még nincs lezárt féléved', 'No completed semesters yet'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              _t('Amint lesz jegyed, itt megjelenik a féléves átlagod és a kreditjeid alakulása.',
                  'Once you have grades, your semester averages and credit progress show up here.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppPalette theme) {
    final graded = _semesters.where((s) => s.hasGrades).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _buildSummaryRow(theme),
        const SizedBox(height: 22),
        if (graded.length >= 2) ...[
          _sectionTitle(theme, _t('Féléves átlag', 'Average per semester')),
          const SizedBox(height: 12),
          _card(
            theme,
            Semantics(
              label: _t('Féléves átlagok grafikonja', 'Chart of semester averages'),
              value: graded
                  .map((s) => '${s.termName}: ${s.average.toStringAsFixed(2)}')
                  .join(', '),
              child: SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _AverageChartPainter(graded, theme),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _sectionTitle(theme, _t('Teljesített kreditek', 'Credits completed')),
          const SizedBox(height: 12),
          _card(
            theme,
            Semantics(
              label: _t('Félévenkénti kreditek', 'Credits per semester'),
              value: _semesters
                  .map((s) => '${s.termName}: ${s.completedCredits}')
                  .join(', '),
              child: SizedBox(
                height: 170,
                child: CustomPaint(
                  painter: _CreditsChartPainter(_semesters, theme),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        _sectionTitle(theme, _t('Jegyek megoszlása', 'Grade distribution')),
        const SizedBox(height: 12),
        _card(theme, _buildDistribution(theme)),
        const SizedBox(height: 22),
        _sectionTitle(theme, _t('Félévek', 'Semesters')),
        const SizedBox(height: 12),
        ..._semesters.reversed.toList().asMap().entries.map(
              (e) => _buildSemesterTile(theme, e.value, _semesters.length - 1 - e.key),
            ),
      ],
    );
  }

  Widget _buildSummaryRow(AppPalette theme) {
    final avg = _cumulativeAverage;
    return Row(
      children: [
        Expanded(
          child: _statCard(theme, _t('Halmozott átlag', 'Cumulative average'),
              avg == 0 ? '-' : avg.toStringAsFixed(2), theme.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(theme, _t('Kredit', 'Credits'),
              '$_totalCompletedCredits', theme.currentClassGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(theme, _t('Félév', 'Semesters'),
              '${_semesters.length}', theme.onPrimaryContainer),
        ),
      ],
    );
  }

  Widget _statCard(AppPalette theme, String label, String value, Color colour) {
    return Semantics(
      label: label,
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 26)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.55), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(AppPalette theme, String text) {
    return Text(text,
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 17));
  }

  Widget _card(AppPalette theme, Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _buildDistribution(AppPalette theme) {
    final dist = _overallDistribution;
    final max = dist.values.fold(0, math.max);
    final colours = <int, Color>{
      1: theme.grade1,
      2: theme.grade2,
      3: theme.grade3,
      4: theme.grade4,
      5: theme.grade5,
    };

    if (max == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            _t('Még nincs számmal értékelt tárgyad.', 'No numerically graded subjects yet.'),
            style: TextStyle(color: theme.textColor.withValues(alpha: 0.5), fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var grade = 5; grade >= 1; grade--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label: _t('$grade-es jegy', 'Grade $grade'),
              value: _t('${dist[grade]} darab', '${dist[grade]} subjects'),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text('$grade',
                        style: TextStyle(
                            color: colours[grade], fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        children: [
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: theme.textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: 22,
                            width: c.maxWidth * (dist[grade]! / max),
                            decoration: BoxDecoration(
                              color: colours[grade],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text('${dist[grade]}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: theme.textColor.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSemesterTile(AppPalette theme, api.SemesterResult sem, int index) {
    final open = _expanded == index;
    final avg = sem.average;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Semantics(
              button: true,
              label: sem.termName,
              value: _t(
                  'Átlag ${avg == 0 ? "nincs" : avg.toStringAsFixed(2)}, ${sem.completedCredits} kredit',
                  'Average ${avg == 0 ? "none" : avg.toStringAsFixed(2)}, ${sem.completedCredits} credits'),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  AppHaptics.lightImpact();
                  setState(() => _expanded = open ? null : index);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sem.termName,
                                style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              _t('${sem.completedCredits} kredit · ${sem.subjects.length} tárgy',
                                  '${sem.completedCredits} credits · ${sem.subjects.length} subjects'),
                              style: TextStyle(
                                  color: theme.textColor.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(avg == 0 ? '-' : avg.toStringAsFixed(2),
                          style: TextStyle(
                              color: theme.secondary,
                              fontWeight: FontWeight.w900,
                              fontSize: 20)),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.textColor.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  children: [
                    Divider(color: theme.textColor.withValues(alpha: 0.08), height: 14),
                    for (final sub in sem.subjects)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(sub.name,
                                  style: TextStyle(
                                      color: theme.textColor.withValues(alpha: 0.85),
                                      fontSize: 13)),
                            ),
                            Text(_t('${sub.credit} kr', '${sub.credit} cr'),
                                style: TextStyle(
                                    color: theme.textColor.withValues(alpha: 0.4),
                                    fontSize: 12)),
                            const SizedBox(width: 12),
                            _gradeChip(theme, sub),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gradeChip(AppPalette theme, api.Subject sub) {
    if (!sub.completed) {
      return Icon(Icons.hourglass_empty_rounded,
          size: 18, color: theme.textColor.withValues(alpha: 0.35));
    }
    if (sub.grade < 1) {
      return Icon(Icons.check_rounded, size: 18, color: theme.currentClassGreen);
    }
    final colours = <int, Color>{
      1: theme.grade1,
      2: theme.grade2,
      3: theme.grade3,
      4: theme.grade4,
      5: theme.grade5,
    };
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colours[sub.grade]!.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${sub.grade}',
          style: TextStyle(
              color: colours[sub.grade], fontWeight: FontWeight.w900, fontSize: 14)),
    );
  }
}

/// Line chart of the credit weighted average, locked to the 1-5 grade scale so
/// semesters stay comparable instead of the axis rescaling under them.
class _AverageChartPainter extends CustomPainter {
  final List<api.SemesterResult> semesters;
  final AppPalette theme;

  _AverageChartPainter(this.semesters, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 26;
    const double bottom = 22;
    final chart = Rect.fromLTRB(left, 6, size.width, size.height - bottom);
    if (chart.width <= 0 || semesters.isEmpty) return;

    final grid = Paint()
      ..color = theme.textColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    double yFor(double value) =>
        chart.bottom - ((value - 1) / 4) * chart.height;

    for (var g = 1; g <= 5; g++) {
      final y = yFor(g.toDouble());
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _label(canvas, '$g', Offset(2, y - 7), theme.textColor.withValues(alpha: 0.4), 11);
    }

    final step = semesters.length == 1
        ? 0.0
        : chart.width / (semesters.length - 1);
    final points = <Offset>[];
    for (var i = 0; i < semesters.length; i++) {
      final x = semesters.length == 1 ? chart.center.dx : chart.left + step * i;
      points.add(Offset(x, yFor(semesters[i].average.clamp(1.0, 5.0))));
    }

    if (points.length >= 2) {
      final fill = Path()..moveTo(points.first.dx, chart.bottom);
      for (final p in points) {
        fill.lineTo(p.dx, p.dy);
      }
      fill.lineTo(points.last.dx, chart.bottom);
      fill.close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.secondary.withValues(alpha: 0.30),
              theme.secondary.withValues(alpha: 0.02),
            ],
          ).createShader(chart),
      );

      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = theme.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 5, Paint()..color = theme.rootBackground);
      canvas.drawCircle(
        points[i],
        5,
        Paint()
          ..color = theme.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _label(
        canvas,
        _shortTerm(semesters[i].termName),
        Offset(points[i].dx - 18, chart.bottom + 6),
        theme.textColor.withValues(alpha: 0.45),
        10,
      );
    }
  }

  /// "2024/25/1" is too wide to repeat along the axis; "24/1" still reads.
  String _shortTerm(String name) {
    final parts = name.split('/');
    if (parts.length >= 3) {
      final year = parts[0].length >= 4 ? parts[0].substring(2) : parts[0];
      return '$year/${parts[2]}';
    }
    return name.length > 7 ? name.substring(0, 7) : name;
  }

  void _label(Canvas canvas, String text, Offset at, Color colour, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: colour, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _AverageChartPainter old) =>
      old.semesters != semesters || old.theme != theme;
}

/// Bars of completed credits per semester, with the running total behind them.
class _CreditsChartPainter extends CustomPainter {
  final List<api.SemesterResult> semesters;
  final AppPalette theme;

  _CreditsChartPainter(this.semesters, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    const double bottom = 22;
    final chart = Rect.fromLTRB(0, 6, size.width, size.height - bottom);
    if (chart.width <= 0 || semesters.isEmpty) return;

    final maxCredits = semesters
        .map((s) => s.completedCredits)
        .fold(1, (a, b) => math.max(a, b))
        .toDouble();

    final slot = chart.width / semesters.length;
    final barWidth = math.min(38.0, slot * 0.55);

    for (var i = 0; i < semesters.length; i++) {
      final value = semesters[i].completedCredits.toDouble();
      final h = (value / maxCredits) * chart.height;
      final cx = chart.left + slot * i + slot / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barWidth / 2, chart.bottom - h, barWidth, h),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );
      canvas.drawRRect(rect, Paint()..color = theme.currentClassGreen.withValues(alpha: 0.85));

      _label(canvas, '${semesters[i].completedCredits}',
          Offset(cx - 9, chart.bottom - h - 16), theme.textColor.withValues(alpha: 0.65), 11);
      _label(canvas, _shortTerm(semesters[i].termName),
          Offset(cx - 16, chart.bottom + 6), theme.textColor.withValues(alpha: 0.45), 10);
    }
  }

  String _shortTerm(String name) {
    final parts = name.split('/');
    if (parts.length >= 3) {
      final year = parts[0].length >= 4 ? parts[0].substring(2) : parts[0];
      return '$year/${parts[2]}';
    }
    return name.length > 7 ? name.substring(0, 7) : name;
  }

  void _label(Canvas canvas, String text, Offset at, Color colour, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: colour, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _CreditsChartPainter old) =>
      old.semesters != semesters || old.theme != theme;
}

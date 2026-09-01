import 'package:flutter/material.dart';

import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';
import '../storage.dart';

/// Everything the app knows about one subject, gathered in one place.
///
/// The pieces already existed but were scattered: the grade sat in the markbook,
/// the room and teacher in a timetable card, and the exam somewhere in a future
/// week of the calendar.
class SubjectDetailPage extends StatefulWidget {
  final api.Subject subject;
  final String? termName;

  const SubjectDetailPage({super.key, required this.subject, this.termName});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  List<api.CalendarEntry> _classes = [];
  List<api.CalendarEntry> _dated = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _hu => AppStrings.getCurrentLangCode() == 'hu';

  String _t(String hu, String en) => _hu ? hu : en;

  /// Timetable titles carry a suffix the markbook does not ("Analízis I. (előadás)"),
  /// so the two are compared on a stripped-down form of the name.
  static String _normalise(String value) {
    var out = value.toLowerCase().trim();
    final paren = out.indexOf('(');
    if (paren > 0) out = out.substring(0, paren);
    return out.replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]'), '');
  }

  bool _matches(api.CalendarEntry e) {
    final a = _normalise(widget.subject.name);
    final b = _normalise(e.title);
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  Future<void> _load() async {
    final week = await _thisWeek();
    final upcoming = await api.CalendarRequest.fetchUpcoming();
    if (!mounted) return;
    setState(() {
      _classes = week.where((e) => _matches(e) && !e.isExam && !e.isTask).toList()
        ..sort((a, b) => a.startEpoch.compareTo(b.startEpoch));
      _dated = upcoming.where(_matches).toList();
      _loading = false;
    });
  }

  Future<List<api.CalendarEntry>> _thisWeek() async {
    try {
      final password = await DataCache.getPassword() ?? '';
      final raw = await api.CalendarRequest.makeCalendarRequest(
        api.CalendarRequest.getCalendarOneWeekJSON(
          DataCache.getUsername() ?? '', password, 1,
        ),
      );
      return api.CalendarRequest.getCalendarEntriesFromJSON(raw);
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.getTheme();
    final s = widget.subject;

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
          _t('Tárgy', 'Subject'),
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(s.name,
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 24, height: 1.25)),
          if (widget.termName != null) ...[
            const SizedBox(height: 6),
            Text(widget.termName!,
                style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 14)),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _stat(theme, _t('Kredit', 'Credits'), '${s.credit}', theme.onPrimaryContainer)),
              const SizedBox(width: 12),
              Expanded(child: _stat(theme, _t('Jegy', 'Grade'), _gradeText(s), _gradeColour(theme, s))),
              const SizedBox(width: 12),
              Expanded(child: _stat(theme, _t('Állapot', 'Status'), _statusText(s), _statusColour(theme, s))),
            ],
          ),
          const SizedBox(height: 26),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: theme.secondary)),
            )
          else ...[
            if (_dated.isNotEmpty) ...[
              _section(theme, _t('Közelgő', 'Upcoming')),
              const SizedBox(height: 10),
              ..._dated.map((e) => _datedRow(theme, e)),
              const SizedBox(height: 22),
            ],
            _section(theme, _t('Órák ezen a héten', 'Classes this week')),
            const SizedBox(height: 10),
            if (_classes.isEmpty)
              Text(
                _t('Ezen a héten nincs órád ebből a tárgyból.',
                    'No classes for this subject this week.'),
                style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 13),
              )
            else
              ..._classes.map((e) => _classRow(theme, e)),
          ],
        ],
      ),
    );
  }

  Widget _section(AppPalette theme, String text) => Text(text,
      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16));

  Widget _stat(AppPalette theme, String label, String value, Color colour) {
    return Semantics(
      label: label,
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _classRow(AppPalette theme, api.CalendarEntry e) {
    final start = DateTime.fromMillisecondsSinceEpoch(e.startEpoch);
    final end = DateTime.fromMillisecondsSinceEpoch(e.endEpoch);
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(api.Generic.dayToText(start.weekday),
                  style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13)),
            ),
            Expanded(
              child: Text('${clock(start)} - ${clock(end)}',
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Text(e.location,
                style: TextStyle(color: theme.secondary, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _datedRow(AppPalette theme, api.CalendarEntry e) {
    final when = DateTime.fromMillisecondsSinceEpoch(e.startEpoch);
    final days = DateTime(when.year, when.month, when.day)
        .difference(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0))
        .inDays;
    final colour = days <= 1 ? theme.errorRed : days <= 3 ? Colors.amber.shade600 : theme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.07),
          border: Border.all(color: colour.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            Icon(e.isExam ? Icons.school_rounded : Icons.assignment_turned_in_rounded,
                color: colour, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
            Text(
              days <= 0 ? _t('ma', 'today') : days == 1 ? _t('holnap', 'tomorrow') : _t('$days nap', '$days days'),
              style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _gradeText(api.Subject s) {
    if (!s.completed) return '-';
    return s.grade >= 1 ? '${s.grade}' : '\u2713';
  }

  Color _gradeColour(AppPalette theme, api.Subject s) {
    if (!s.completed || s.grade < 1) return theme.textColor.withValues(alpha: 0.6);
    switch (s.grade) {
      case 5:
        return theme.grade5;
      case 4:
        return theme.grade4;
      case 3:
        return theme.grade3;
      case 2:
        return theme.grade2;
      default:
        return theme.grade1;
    }
  }

  String _statusText(api.Subject s) {
    if (s.failState == 1) return _t('Bukott', 'Failed');
    return s.completed ? _t('Kész', 'Done') : _t('Folyamatban', 'Ongoing');
  }

  Color _statusColour(AppPalette theme, api.Subject s) {
    if (s.failState == 1) return theme.errorRed;
    return s.completed ? theme.currentClassGreen : Colors.amber.shade600;
  }
}

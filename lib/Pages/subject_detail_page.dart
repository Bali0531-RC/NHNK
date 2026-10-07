import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart' as path;

import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../hidden_classes.dart';
import '../language.dart';
import '../storage.dart';

/// Neptun names the assessment form in Hungarian only, so English users get a translation.
String subjectRequirementLabel(String requirement) {
  if (AppStrings.getCurrentLangCode() == 'hu') return requirement;
  const english = {
    'vizsga': 'Exam',
    'kollokvium': 'Colloquium',
    'évközi jegy': 'Term grade',
    'folyamatos számonkérés': 'Continuous assessment',
    'aláírás': 'Signature',
    'gyakorlati jegy': 'Practical grade',
    'szigorlat': 'Comprehensive exam',
  };
  return english[requirement.trim().toLowerCase()] ?? requirement;
}

String? _requirementHint(String requirement, bool hu) {
  const hints = {
    'vizsga': ('Vizsgával zárul, jegyet kapsz.', 'Ends with an exam; you get a grade.'),
    'kollokvium': ('Szóbeli vagy írásbeli számonkérés a félév végén, jeggyel.', 'An end-of-term oral or written check, graded.'),
    'évközi jegy': ('A jegyet a félév alatti teljesítményed alapján kapod, vizsga nélkül.', 'Graded on your work during the semester, no exam.'),
    'folyamatos számonkérés': ('A félév alatt folyamatosan számon kérik, külön vizsga nélkül.', 'Assessed throughout the semester, without a separate exam.'),
    'aláírás': ('Csak aláírást kell szerezned, jegy nincs.', 'You only need the signature; there is no grade.'),
    'gyakorlati jegy': ('Gyakorlati munkád alapján kapsz jegyet.', 'Graded on practical work.'),
    'szigorlat': ('Több tárgyat átfogó vizsga.', 'A comprehensive exam covering several subjects.'),
  };
  final hint = hints[requirement.trim().toLowerCase()];
  return hint == null ? null : (hu ? hint.$1 : hint.$2);
}

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
  bool _classesHidden = false;
  api.SubjectDetails? _details;
  bool _detailsLoading = true;
  bool _downloading = false;
  bool _descriptionOpen = false;

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

  Future<void> _loadDetails() async {
    await api.SubjectDetailsRequest.withIds(widget.subject);
    final details = await api.SubjectDetailsRequest.fetch(widget.subject);
    if (!mounted) return;
    setState(() {
      _details = details;
      _detailsLoading = false;
    });
  }

  Future<void> _downloadThematics() async {
    if (_downloading) return;
    AppHaptics.lightImpact();
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    String? failure;
    try {
      final file = await api.SubjectDetailsRequest.downloadThematics(widget.subject);
      if (file == null) {
        failure = _t('A tematika most nem tölthető le.', 'The syllabus could not be downloaded right now.');
      } else {
        final safeName = file.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final target = File('${(await path.getTemporaryDirectory()).path}/$safeName');
        await target.writeAsBytes(file.bytes, flush: true);
        final result = await OpenFilex.open(target.path, type: 'application/pdf');
        if (result.type != ResultType.done) {
          failure = _t('Nincs PDF-megnyitó alkalmazás a készüléken.', 'No PDF viewer is installed on this device.');
        }
      }
    } catch (_) {
      failure = _t('A tematika most nem tölthető le.', 'The syllabus could not be downloaded right now.');
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    if (failure != null) messenger.showSnackBar(SnackBar(content: Text(failure)));
  }

  Future<void> _load() async {
    _loadDetails();
    await HiddenClasses.load();
    final week = await _thisWeek();
    final upcoming = await api.CalendarRequest.fetchUpcoming();
    if (!mounted) return;
    setState(() {
      _classesHidden = HiddenClasses.isTitleHidden(widget.subject.name);
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
          if (s.code.isNotEmpty || widget.termName != null) ...[
            const SizedBox(height: 6),
            Text([if (s.code.isNotEmpty) s.code, if (widget.termName != null) widget.termName!].join(' · '),
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
          ..._aboutSections(theme),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_t('Órák elrejtése az órarendből', 'Hide classes from the timetable'),
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
                _t('A widgetről és az emlékeztetőkből is kimaradnak.', 'They also leave the widget and the reminders.'),
                style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 12)),
            activeThumbColor: theme.secondary,
            value: _classesHidden,
            onChanged: (value) async {
              AppHaptics.lightImpact();
              setState(() => _classesHidden = value);
              value ? await HiddenClasses.hide([s.name]) : await HiddenClasses.unhide(s.name);
            },
          ),
          const SizedBox(height: 14),
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

  Widget _infoRow(AppPalette theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(label, style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ],
        ),
      );

  String _hours(Map<String, int> rows, String unit) =>
      rows.entries.map((e) => '${e.key}: ${e.value} $unit').join('\n');

  /// How the subject is assessed, who runs it, and the syllabus download.
  List<Widget> _aboutSections(AppPalette theme) {
    final requirement = (_details?.requirementType.isNotEmpty ?? false)
        ? _details!.requirementType
        : widget.subject.requirementType;
    final hint = requirement.isEmpty ? null : _requirementHint(requirement, _hu);
    final details = _details;

    return [
      if (requirement.isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.secondary.withValues(alpha: 0.08),
            border: Border.all(color: theme.secondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fact_check_rounded, color: theme.secondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t('Számonkérés', 'Assessment'),
                        style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text(subjectRequirementLabel(requirement),
                        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w800, fontSize: 16)),
                    if (hint != null) ...[
                      const SizedBox(height: 4),
                      Text(hint, style: TextStyle(color: AppColors.mutedText(0.6), fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (_detailsLoading) ...[
        const SizedBox(height: 22),
        Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.secondary))),
      ] else if (details != null) ...[
        const SizedBox(height: 22),
        _section(theme, _t('Részletek', 'Details')),
        const SizedBox(height: 6),
        if (details.teacher.isNotEmpty) _infoRow(theme, _t('Oktató', 'Lecturer'), details.teacher),
        if (details.department.isNotEmpty) _infoRow(theme, _t('Tanszék', 'Department'), details.department),
        if (details.hoursPerWeek.isNotEmpty) _infoRow(theme, _t('Heti óraszám', 'Hours per week'), _hours(details.hoursPerWeek, _t('óra', 'h'))),
        if (details.hoursPerTerm.isNotEmpty) _infoRow(theme, _t('Féléves óraszám', 'Hours per term'), _hours(details.hoursPerTerm, _t('óra', 'h'))),
        if (details.resultType.isNotEmpty) _infoRow(theme, _t('Eredmény típusa', 'Result type'), details.resultType),
        if (details.preRequirement.isNotEmpty) _infoRow(theme, _t('Előkövetelmény', 'Prerequisite'), details.preRequirement),
        if (details.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            details.description,
            maxLines: _descriptionOpen ? null : 4,
            overflow: _descriptionOpen ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.mutedText(0.7), fontSize: 13, height: 1.4),
          ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), alignment: Alignment.centerLeft),
            onPressed: () => setState(() => _descriptionOpen = !_descriptionOpen),
            child: Text(_descriptionOpen ? _t('Kevesebb', 'Show less') : _t('Tovább', 'Show more'),
                style: TextStyle(color: theme.secondary)),
          ),
        ],
        if (details.thematicsAvailable) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _downloading ? null : _downloadThematics,
              icon: _downloading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_t('Tárgytematika letöltése', 'Download syllabus')),
            ),
          ),
        ],
      ],
    ];
  }

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

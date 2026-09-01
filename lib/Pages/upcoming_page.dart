import 'package:flutter/material.dart';

import '../API/api_coms.dart' as api;
import '../colors.dart';
import '../haptics.dart';
import '../language.dart';

/// Everything with a date attached, in one place.
///
/// Exams and deadlines live in the weekly timetable, which means anything more
/// than a few days out is invisible unless you page to exactly the right week.
/// Registration periods are folded in because a closing deadline is every bit as
/// urgent as an exam.
class UpcomingPage extends StatefulWidget {
  const UpcomingPage({super.key});

  @override
  State<UpcomingPage> createState() => _UpcomingPageState();
}

class _Item {
  final DateTime when;
  final DateTime? until;
  final String title;
  final String subtitle;
  final _Kind kind;

  _Item(this.when, this.until, this.title, this.subtitle, this.kind);
}

enum _Kind { exam, task, period }

class _UpcomingPageState extends State<UpcomingPage> {
  List<_Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _hu => AppStrings.getCurrentLangCode() == 'hu';

  String _t(String hu, String en) => _hu ? hu : en;

  Future<void> _load({bool force = false}) async {
    if (!mounted) return;
    setState(() => _loading = true);

    final now = DateTime.now();
    final items = <_Item>[];

    final entries = await api.CalendarRequest.fetchUpcoming(force: force);
    for (final e in entries) {
      final start = DateTime.fromMillisecondsSinceEpoch(e.startEpoch);
      final room = e.location.trim();
      final showRoom = room.isNotEmpty && room != 'NULL' && room != '-' && room != 'Nincs megadva';
      items.add(_Item(
        start,
        null,
        e.title,
        showRoom ? room : (e.teacher == '-' ? '' : e.teacher),
        e.isExam ? _Kind.exam : _Kind.task,
      ));
    }

    final periods = await api.PeriodsRequest.getPeriods() ?? [];
    for (final p in periods) {
      final end = DateTime.fromMillisecondsSinceEpoch(p.endEpoch);
      final start = DateTime.fromMillisecondsSinceEpoch(p.startEpoch);
      if (end.isBefore(now)) continue;
      // An open period matters for when it closes; one not yet open, for when it opens.
      final active = start.isBefore(now);
      items.add(_Item(
        active ? end : start,
        active ? end : null,
        p.name,
        active
            ? _t('most nyitva', 'open now')
            : _t('még nem nyílt meg', 'not open yet'),
        _Kind.period,
      ));
    }

    items.sort((a, b) => a.when.compareTo(b.when));

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
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
          _t('Közelgő', 'Upcoming'),
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
          ? Center(child: CircularProgressIndicator(color: theme.secondary))
          : _items.isEmpty
              ? _buildEmpty(theme)
              : _buildList(theme),
    );
  }

  Widget _buildEmpty(AppPalette theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 56, color: theme.currentClassGreen.withValues(alpha: 0.6)),
            const SizedBox(height: 18),
            Text(
              _t('Semmi sem vár rád', 'Nothing coming up'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              _t('Nincs vizsgád, határidőd vagy nyitott időszakod a következő hetekben.',
                  'No exams, deadlines or open periods in the coming weeks.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppPalette theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<_Item>>{};

    for (final item in _items) {
      final days = DateTime(item.when.year, item.when.month, item.when.day).difference(today).inDays;
      final key = days <= 7
          ? _t('Ezen a héten', 'This week')
          : days <= 30
              ? _t('Ebben a hónapban', 'This month')
              : _t('Később', 'Later');
      groups.putIfAbsent(key, () => []).add(item);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 10),
            child: Text(
              entry.key,
              style: TextStyle(color: AppColors.mutedText(0.55),
                  fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.4),
            ),
          ),
          ...entry.value.map((i) => _buildCard(theme, i, today)),
        ],
      ],
    );
  }

  Widget _buildCard(AppPalette theme, _Item item, DateTime today) {
    final days = DateTime(item.when.year, item.when.month, item.when.day).difference(today).inDays;
    final colour = _colourFor(item, days, theme);
    final count = _countdown(item.when, days);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: '${_kindLabel(item.kind)}, ${item.title}',
        value: '$count, ${_dateLabel(item.when)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.06),
            border: Border.all(color: colour.withValues(alpha: 0.4), width: 1),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(_iconFor(item.kind), color: colour, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.textColor,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle.isEmpty
                          ? _dateLabel(item.when)
                          : '${_dateLabel(item.when)} · ${item.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.mutedText(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(count,
                      style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 15)),
                  Text(_kindLabel(item.kind),
                      style: TextStyle(color: AppColors.mutedText(0.35), fontSize: 10.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colourFor(_Item item, int days, AppPalette theme) {
    if (days <= 1) return theme.errorRed;
    if (days <= 3) return Colors.amber.shade600;
    if (item.kind == _Kind.exam) return theme.secondary;
    return theme.currentClassGreen;
  }

  IconData _iconFor(_Kind kind) {
    switch (kind) {
      case _Kind.exam:
        return Icons.school_rounded;
      case _Kind.task:
        return Icons.assignment_turned_in_rounded;
      case _Kind.period:
        return Icons.event_note_rounded;
    }
  }

  String _kindLabel(_Kind kind) {
    switch (kind) {
      case _Kind.exam:
        return _t('vizsga', 'exam');
      case _Kind.task:
        return _t('határidő', 'deadline');
      case _Kind.period:
        return _t('időszak', 'period');
    }
  }

  String _countdown(DateTime when, int days) {
    if (days < 0) return _t('lejárt', 'passed');
    if (days == 0) {
      final hours = when.difference(DateTime.now()).inHours;
      if (hours >= 1) return _t('$hours óra', '${hours}h');
      return _t('ma', 'today');
    }
    if (days == 1) return _t('holnap', 'tomorrow');
    return _t('$days nap', '$days days');
  }

  String _dateLabel(DateTime when) {
    final month = api.Generic.monthToText(when.month);
    // 23:59 and 00:00 are how date-only items land, and neither is worth showing.
    final hideTime = (when.hour == 23 && when.minute == 59) || (when.hour == 0 && when.minute == 0);
    final time = hideTime
        ? ''
        : ' ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return '$month ${when.day}.$time';
  }
}

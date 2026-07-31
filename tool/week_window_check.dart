// Sanity-check for the Monday-start week window used by getCalendarOneWeekJSON.
void main() {
  DateTime mondayOf(DateTime now) =>
      DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));

  final samples = <DateTime>[
    DateTime(2026, 3, 2), // Monday
    DateTime(2026, 3, 3),
    DateTime(2026, 3, 6),
    DateTime(2026, 3, 8), // Sunday
    DateTime(2026, 3, 29), // EU DST spring-forward (CET -> CEST)
    DateTime(2026, 3, 30),
    DateTime(2026, 10, 25), // DST fall-back
    DateTime(2026, 1, 1),
    DateTime(2027, 1, 3), // Sunday spanning year end
  ];

  var failures = 0;
  for (final now in samples) {
    final monday = mondayOf(now);
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = DateTime(start.year, start.month, start.day + 6, 23, 59, 59);

    final ok = monday.weekday == DateTime.monday &&
        !now.isBefore(start) &&
        !now.isAfter(end) &&
        end.weekday == DateTime.sunday;
    if (!ok) failures++;
    print('${now.toIso8601String().substring(0, 10)} (${now.weekday}) -> '
        'week ${start.toIso8601String().substring(0, 10)} .. ${end.toIso8601String().substring(0, 10)} '
        '${ok ? "OK" : "FAIL"}');
  }

  // Offsets must step exactly one week and stay on Mondays.
  final base = mondayOf(DateTime(2026, 3, 25));
  for (final off in [-2, -1, 0, 1, 2]) {
    final s = DateTime(base.year, base.month, base.day + (off * 7));
    if (s.weekday != DateTime.monday) failures++;
    print('offset $off -> ${s.toIso8601String().substring(0, 10)} (weekday ${s.weekday})');
  }

  print(failures == 0 ? 'ALL PASS' : '$failures FAILURES');
}

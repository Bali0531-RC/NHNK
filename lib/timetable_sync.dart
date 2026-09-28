import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'API/api_coms.dart' as api;
import 'hidden_classes.dart';
import 'language.dart';
import 'notifications.dart';
import 'platform_support.dart';
import 'storage.dart' as storage;

class TimetableSync {
  static const provider = 'hu.bali0531.nhnk.app.TodayWidgetProvider';
  static const snapshotKey = 'calendar_snapshot';
  static const _backgroundKey = 'BackgroundCalendarEntries';

  static Future<bool> hasWidgets() async {
    if (!AppPlatform.isAndroid) return false;
    return (await HomeWidget.getInstalledWidgets()).isNotEmpty;
  }

  static Future<List<api.CalendarEntry>> _savedEntries() async {
    final rows = await storage.getStringList(_backgroundKey) ?? [];
    return [
      for (final row in rows)
        if (row.split('\n').length >= 5)
          api.CalendarEntry('0', '0', 'NULL', 'NULL', false)
              .fillWithExisting(row),
    ];
  }

  static Future<void> writeCurrentWeek(List<api.CalendarEntry> entries) async {
    final now = DateTime.now();
    final nextWeek = api.CalendarRequest.weekStartFor(2).millisecondsSinceEpoch;
    final saved = await _savedEntries();
    final combined = [
      ...entries,
      ...saved.where((entry) => entry.startEpoch >= nextWeek),
    ]..sort((first, second) => first.startEpoch.compareTo(second.startEpoch));

    for (var index = 0; index < entries.length; index++) {
      await storage.saveString(
          'CachedCalendar_$index', entries[index].toString());
    }
    await storage.saveInt('CachedCalendarLength', entries.length);
    await storage.saveString(
        'CalendarCacheTime', DateTime(now.year, now.month, now.day).toString());
    await storage.saveInt('CalendarCacheWrittenAt', now.millisecondsSinceEpoch);
    await storage.DataCache.setHasCachedCalendar(1);
    await storage.saveStringList(
        _backgroundKey, [for (final entry in combined) entry.toString()]);
    await publish(combined, writtenAt: now);
  }

  static Future<void> publish(List<api.CalendarEntry> entries,
      {required DateTime writtenAt}) async {
    if (!AppPlatform.isAndroid) return;
    await HiddenClasses.load();
    final visible = HiddenClasses.forWidget(entries);
    await HomeWidget.saveWidgetData(
        snapshotKey,
        jsonEncode({
          'writtenAt': writtenAt.millisecondsSinceEpoch,
          'language': AppStrings.getCurrentLangCode(),
          'account': storage.DataCache.getUsername() ?? '',
          'institution': storage.DataCache.getInstituteUrl() ?? '',
          'entries': [for (final entry in visible) entry.toString()],
        }));
    await HomeWidget.updateWidget(qualifiedAndroidName: provider);
  }

  /// Re-applies the hidden classes to the widget and the reminders without a network call.
  static Future<void> reapply() async {
    final saved = await _savedEntries();
    if (saved.isEmpty) return;
    final writtenAt = await storage.getInt('CalendarCacheWrittenAt');
    await publish(saved,
        writtenAt: writtenAt == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(writtenAt));
    await scheduleClasses(saved);
  }

  static Future<List<api.CalendarEntry>> readCurrentWeek() async {
    final length = await storage.getInt('CachedCalendarLength') ?? 0;
    final entries = <api.CalendarEntry>[];
    for (var index = 0; index < length; index++) {
      final raw = await storage.getString('CachedCalendar_$index');
      if (raw == null) continue;
      entries.add(api.CalendarEntry('0', '0', 'NULL', 'NULL', false)
          .fillWithExisting(raw));
    }
    return entries;
  }

  static Future<List<api.CalendarEntry>?> _fetchWeek(int week) async {
    final username = storage.DataCache.getUsername();
    final password = await storage.DataCache.getPassword();
    if (username == null || password == null) return null;
    final raw = await api.CalendarRequest.makeCalendarRequest(
      api.CalendarRequest.getCalendarOneWeekJSON(username, password, week),
      requireSuccess: true,
    );
    return api.CalendarRequest.getCalendarEntriesFromJSON(raw);
  }

  static Future<bool> refresh({
    Future<List<api.CalendarEntry>?> Function(int week)? fetchWeek,
  }) async {
    final session = (
      await storage.getString('Username'),
      await storage.getString('URL'),
      await storage.getInt('HasLogin'),
    );
    final load = fetchWeek ?? _fetchWeek;
    final current = await load(1);
    if (current == null) return false;
    final next = await load(2);
    if (next == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (session !=
        (
          prefs.getString('Username'),
          prefs.getString('URL'),
          prefs.getInt('HasLogin')
        )) return false;
    final entries = [...current, ...next];
    await storage.saveStringList(
        _backgroundKey, [for (final entry in entries) entry.toString()]);
    await writeCurrentWeek(current);
    await scheduleClasses(entries);
    return true;
  }

  static Future<void> scheduleClasses(List<api.CalendarEntry> entries) async {
    if (!(storage.DataCache.getNeedClassNotifications() ?? true)) {
      await AppNotifications.cancelScheduledNotifsId(1);
      return;
    }
    final nextWeek = api.CalendarRequest.weekStartFor(2).millisecondsSinceEpoch;
    final combined = [
      ...entries,
      ...(await _savedEntries()).where((entry) => entry.startEpoch >= nextWeek)
    ];
    final keep = <int>{};
    final seen = <String>{};
    final hungarian = AppStrings.getCurrentLangCode() == 'hu';
    final reminders = storage.DataCache.getClassReminderMinutes();
    await HiddenClasses.load();
    for (final entry in combined) {
      if (entry.isExam ||
          entry.isTask ||
          HiddenClasses.isHidden(entry) ||
          entry.startEpoch <= DateTime.now().millisecondsSinceEpoch) continue;
      if (!seen.add('${entry.startEpoch}|${entry.endEpoch}|${entry.title}'))
        continue;
      var room = entry.location;
      if (entry.classInstanceId?.isNotEmpty ?? false) {
        final cachedRoom =
            await storage.getString('room_${entry.classInstanceId}');
        if (cachedRoom != null &&
            cachedRoom.isNotEmpty &&
            cachedRoom != 'Nincs terem') room = cachedRoom;
      }
      for (final minutes in reminders) {
        final time = DateTime.fromMillisecondsSinceEpoch(entry.startEpoch)
            .subtract(Duration(minutes: minutes));
        final body = hungarian
            ? (minutes == 0
                ? '"${entry.title}" órád van itt: "$room"!'
                : '"${entry.title}" órád lesz itt: "$room" $minutes perc múlva!')
            : (minutes == 0
                ? '"${entry.title}" is starting in "$room".'
                : '"${entry.title}" starts in $minutes minutes in "$room".');
        final id = await AppNotifications.scheduleNotification(
            hungarian ? 'Óra' : 'Class', body, time, 1);
        if (id != null) keep.add(id);
      }
    }
    await AppNotifications.cancelScheduledNotifsId(1, keep: keep);
  }
}

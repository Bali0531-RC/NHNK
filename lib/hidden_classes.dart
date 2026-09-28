import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'API/api_coms.dart' as api;
import 'storage.dart' as storage;
import 'timetable_sync.dart';

/// Classes the user chose to keep out of the timetable, reminders and widget.
/// Exams and tasks are never hidden, only regular classes.
class HiddenClasses {
  static Map<String, String> _titles = {};
  static bool _showInWidget = false;

  /// Set by the home page so a change is reflected without a refetch.
  static void Function()? onChanged;

  static const _widgetKey = 'SETTING_HiddenClassesInWidget';

  static String _listKey() {
    final account = '${storage.DataCache.getInstituteUrl()}|${storage.DataCache.getUsername()}';
    return 'HiddenClasses_${sha256.convert(utf8.encode(account))}';
  }

  /// Timetable titles carry suffixes the markbook does not, so both sides are compared stripped.
  static String keyOf(String title) {
    var out = title.toLowerCase().trim();
    final paren = out.indexOf('(');
    if (paren > 0) out = out.substring(0, paren);
    return out.replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]'), '');
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _titles = {
      for (final title in prefs.getStringList(_listKey()) ?? const <String>[])
        if (keyOf(title).isNotEmpty) keyOf(title): title,
    };
    _showInWidget = prefs.getBool(_widgetKey) ?? false;
  }

  static List<String> get titles => _titles.values.toList()..sort();
  static bool get showInWidget => _showInWidget;

  static bool isTitleHidden(String title) => _titles.containsKey(keyOf(title));

  static bool isHidden(api.CalendarEntry entry) =>
      !entry.isExam && !entry.isTask && isTitleHidden(entry.title);

  static List<api.CalendarEntry> withoutHidden(List<api.CalendarEntry> entries) =>
      _titles.isEmpty ? entries : entries.where((entry) => !isHidden(entry)).toList();

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_listKey(), _titles.values.toList());
  }

  /// Persists the change and brings the widget, reminders and timetable in line with it.
  static Future<void> _commit() async {
    await _save();
    await TimetableSync.reapply();
    onChanged?.call();
  }

  static Future<void> hide(Iterable<String> titles) async {
    await load();
    for (final title in titles) {
      final key = keyOf(title);
      if (key.isNotEmpty) _titles.putIfAbsent(key, () => title);
    }
    await _commit();
  }

  static Future<void> unhide(String title) async {
    await load();
    _titles.remove(keyOf(title));
    await _commit();
  }

  static Future<void> setShowInWidget(bool value) async {
    _showInWidget = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetKey, value);
    await TimetableSync.reapply();
  }

  /// The widget follows the same list unless the user asked to see everything there.
  static List<api.CalendarEntry> forWidget(List<api.CalendarEntry> entries) =>
      _showInWidget ? entries : withoutHidden(entries);
}

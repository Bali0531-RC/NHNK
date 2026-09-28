import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'API/api_coms.dart' as api;
import 'language.dart';
import 'notifications.dart';
import 'storage.dart' as storage;

/// Shared by the in-app refresh and the background worker so both decide what
/// counts as a new grade the same way.
class GradeAlerts{
  static Future<void> _notificationQueue = Future<void>.value();

  /// The modern API reports every subject with id 0, so the name has to be part of the key.
  static String _identity(api.Subject subject) => '${subject.id}|${subject.name}';

  static String _ledgerKey(){
    final account = '${storage.DataCache.getInstituteUrl()}|${storage.DataCache.getUsername()}';
    return 'GradeAlert_notified_${sha256.convert(utf8.encode(account))}';
  }

  /// Must be read before the markbook cache is rewritten, otherwise the comparison
  /// is against the values that just arrived.
  static Future<Map<String, int>> readCachedGrades() async{
    final previous = <String, int>{};
    if(!(storage.DataCache.getHasCachedMarkbook() ?? false)){
      return previous;
    }
    final len = await storage.getInt('CachedMarkbookLength') ?? 0;
    for(int i = 0; i < len; i++){
      final raw = await storage.getString('CachedMarkbook_$i');
      if(raw == null) continue;
      final subject = api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(raw);
      if(subject.name != 'ERROR'){
        previous[_identity(subject)] = subject.grade;
      }
    }
    return previous;
  }

  static Future<void> writeCache(List<api.Subject> subjects) async{
    await storage.saveInt('CachedMarkbookLength', subjects.length);
    for(int i = 0; i < subjects.length; i++){
      await storage.saveString('CachedMarkbook_$i', subjects[i].toString());
    }
    await storage.saveString('MarkbookCacheTime', DateTime.now().toString());
    await storage.DataCache.setHasCachedMarkbook(1);
  }

  /// Only subjects that were already known and whose grade actually moved, so a
  /// first sync or a newly enrolled subject cannot produce a burst of alerts.
  static List<api.Subject> findNewGrades(Map<String, int> previous, List<api.Subject> fresh){
    if(previous.isEmpty){
      return const [];
    }
    final changed = <api.Subject>[];
    for(final subject in fresh){
      final before = previous[_identity(subject)];
      if(before == null) continue;
      if(subject.grade > 0 && subject.grade != before){
        changed.add(subject);
      }
    }
    return changed;
  }

  static Future<void> notify(List<api.Subject> changed){
    final operation = _notificationQueue.then((_) => _notifyOnce(changed));
    _notificationQueue = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> _notifyOnce(List<api.Subject> changed) async{
    if(changed.isEmpty) return;
    if(!(storage.DataCache.getNeedGradeNotifications() ?? true)) return;
    if(storage.DataCache.getIsDemoAccount() ?? false) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _ledgerKey();
    final notified = (prefs.getStringList(key) ?? []).toSet();

    // A grade that flickers to 0 and back must not alert twice, so the ledger
    // remembers every subject+grade pair permanently.
    final pending = <String, api.Subject>{
      for(final subject in changed)
        if(!notified.contains('${_identity(subject)}|${subject.grade}'))
          '${_identity(subject)}|${subject.grade}': subject,
    };
    if(pending.isEmpty) return;

    final lang = AppStrings.getLanguagePack();
    for(final subject in pending.values){
      await AppNotifications.showNotification(
        lang.notification_NewGrade_Title,
        AppStrings.getStringWithParams(lang.notification_NewGrade_One, [subject.name, subject.grade]),
      );
    }

    await prefs.reload();
    notified.addAll(prefs.getStringList(key) ?? []);
    notified.addAll(pending.keys);
    await prefs.setStringList(key, notified.toList());
  }
}

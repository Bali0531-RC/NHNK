import 'API/api_coms.dart' as api;
import 'language.dart';
import 'notifications.dart';
import 'storage.dart' as storage;

/// Shared by the in-app refresh and the background worker so both decide what
/// counts as a new grade the same way.
class GradeAlerts{
  /// Must be read before the markbook cache is rewritten, otherwise the comparison
  /// is against the values that just arrived.
  static Future<Map<int, int>> readCachedGrades() async{
    final previous = <int, int>{};
    if(!(storage.DataCache.getHasCachedMarkbook() ?? false)){
      return previous;
    }
    final len = await storage.getInt('CachedMarkbookLength') ?? 0;
    for(int i = 0; i < len; i++){
      final raw = await storage.getString('CachedMarkbook_$i');
      if(raw == null) continue;
      final subject = api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(raw);
      if(subject.name != 'ERROR'){
        previous[subject.id] = subject.grade;
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
  static List<api.Subject> findNewGrades(Map<int, int> previous, List<api.Subject> fresh){
    if(previous.isEmpty){
      return const [];
    }
    final changed = <api.Subject>[];
    for(final subject in fresh){
      final before = previous[subject.id];
      if(before == null) continue;
      if(subject.grade > 0 && subject.grade != before){
        changed.add(subject);
      }
    }
    return changed;
  }

  static Future<void> notify(List<api.Subject> changed) async{
    if(changed.isEmpty) return;
    if(!(storage.DataCache.getNeedGradeNotifications() ?? true)) return;
    if(storage.DataCache.getIsDemoAccount() ?? false) return;

    final lang = AppStrings.getLanguagePack();
    final body = changed.length == 1
        ? AppStrings.getStringWithParams(lang.notification_NewGrade_One, [changed.first.name, changed.first.grade])
        : AppStrings.getStringWithParams(lang.notification_NewGrade_Many, [changed.length]);

    await AppNotifications.showNotification(lang.notification_NewGrade_Title, body);
  }
}

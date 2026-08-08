import 'API/api_coms.dart' as api;
import 'language.dart';
import 'notifications.dart';
import 'storage.dart' as storage;

/// Shared by the in-app refresh and the background worker so both decide what
/// counts as a new message the same way.
class MailAlerts{
  /// Must be read before the mail cache is rewritten.
  static Future<Set<String>> readCachedMailIds() async{
    final seen = <String>{};
    if(!(storage.DataCache.getHasCachedMail() ?? false)){
      return seen;
    }
    final len = await storage.getInt('CachedMailsLength') ?? 0;
    for(int i = 0; i < len; i++){
      final raw = await storage.getString('CachedMails_$i');
      if(raw == null) continue;
      final mail = api.MailEntry("ERROR", "ERROR", "ERROR", 0, false, "").fillWithExisting(raw);
      if(mail.ID.isNotEmpty){
        seen.add(mail.ID);
      }
    }
    return seen;
  }

  static Future<void> writeCache(List<api.MailEntry> mails, int unread, int total) async{
    await storage.saveInt('CachedMailsLength', mails.length);
    await storage.saveInt('CachedMailsUnread', unread);
    await storage.saveInt('CachedMailsTotal', total);
    for(int i = 0; i < mails.length; i++){
      await storage.saveString('CachedMails_$i', mails[i].toString());
    }
    await storage.saveString('MailCacheTime', DateTime.now().toString());
    await storage.DataCache.setHasCachedMail(1);
  }

  /// Unread arrivals only, and nothing at all on a first sync, so restoring a
  /// device cannot announce the whole inbox.
  static List<api.MailEntry> findNewMails(Set<String> previous, List<api.MailEntry> fresh){
    if(previous.isEmpty){
      return const [];
    }
    return fresh.where((m) => m.ID.isNotEmpty && !m.isRead && !previous.contains(m.ID)).toList();
  }

  static Future<void> notify(List<api.MailEntry> fresh) async{
    if(fresh.isEmpty) return;
    if(!(storage.DataCache.getNeedMailNotifications() ?? true)) return;
    if(storage.DataCache.getIsDemoAccount() ?? false) return;

    final lang = AppStrings.getLanguagePack();
    final body = fresh.length == 1
        ? AppStrings.getStringWithParams(lang.notification_NewMail_One, [fresh.first.senderName, fresh.first.subject])
        : AppStrings.getStringWithParams(lang.notification_NewMail_Many, [fresh.length]);

    await AppNotifications.showNotification(lang.notification_NewMail_Title, body);
  }
}

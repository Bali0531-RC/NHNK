import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'API/api_coms.dart' as api;
import 'language.dart';
import 'notifications.dart';
import 'storage.dart' as storage;

/// Shared by the in-app refresh and the background worker so both decide what
/// counts as a new message the same way.
class MailAlerts{
  static Future<void> _notificationQueue = Future<void>.value();

  static String _historyKey(String kind){
    final account = '${storage.DataCache.getInstituteUrl()}|${storage.DataCache.getUsername()}';
    return 'MailAlert_${kind}_${sha256.convert(utf8.encode(account))}';
  }

  /// Must be read before the mail cache is rewritten.
  static Future<Set<String>> readCachedMailIds() async{
    final seen = (await storage.getStringList(_historyKey('seen')) ?? []).toSet();
    final len = await storage.getInt('CachedMailsLength') ?? 0;
    for(int i = 0; i < len; i++){
      final raw = await storage.getString('CachedMails_$i');
      if(raw == null) continue;
      try{
        final mail = api.MailEntry("ERROR", "ERROR", "ERROR", 0, false, "").fillWithExisting(raw);
        if(mail.ID.isNotEmpty) seen.add(mail.ID);
      } catch(_) {}
    }
    return seen;
  }

  static Future<void> writeCache(List<api.MailEntry> mails, int unread, int total) async{
    final seen = await readCachedMailIds();
    seen.addAll(mails.map((mail) => mail.ID).where((id) => id.isNotEmpty));
    await storage.saveStringList(_historyKey('seen'), seen.toList());
    await storage.saveInt('CachedMailsUnread', unread);
    await storage.saveInt('CachedMailsTotal', total);
    for(int i = 0; i < mails.length; i++){
      await storage.saveString('CachedMails_$i', mails[i].toString());
    }
    await storage.saveInt('CachedMailsLength', mails.length);
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

  static Future<void> markCachedMailRead(String id) async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final length = prefs.getInt('CachedMailsLength') ?? 0;
    var changed = false;
    for(var index = 0; index < length; index++){
      final key = 'CachedMails_$index';
      final raw = prefs.getString(key);
      if(raw == null) continue;
      try{
        final mail = api.MailEntry('', '', '', 0, false, '').fillWithExisting(raw);
        if(mail.ID != id || mail.isRead) continue;
        mail.isRead = true;
        await prefs.setString(key, mail.toString());
        changed = true;
      } catch(_) {}
    }
    if(changed){
      final count = prefs.getInt('CachedMailsUnread') ?? 0;
      await prefs.setInt('CachedMailsUnread', count > 0 ? count - 1 : 0);
    }
  }

  static Future<void> notify(List<api.MailEntry> fresh){
    final operation = _notificationQueue.then((_) => _notifyOnce(fresh));
    _notificationQueue = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> _notifyOnce(List<api.MailEntry> fresh) async{
    if(fresh.isEmpty) return;
    if(!(storage.DataCache.getNeedMailNotifications() ?? true)) return;
    if(storage.DataCache.getIsDemoAccount() ?? false) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final key = _historyKey('notified');
    final notified = (prefs.getStringList(key) ?? []).toSet();
    final unique = <String, api.MailEntry>{
      for(final mail in fresh)
        if(mail.ID.isNotEmpty && !mail.isRead && !notified.contains(mail.ID)) mail.ID: mail,
    };
    if(unique.isEmpty) return;
    final pending = unique.values.toList();
    final lang = AppStrings.getLanguagePack();
    if(pending.length == 1){
      await AppNotifications.showMailNotification(
        lang.notification_NewMail_Title,
        AppStrings.getStringWithParams(lang.notification_NewMail_One, [pending.first.senderName, pending.first.subject]),
        pending.first.ID,
      );
    } else {
      final ids = unique.keys.toList()..sort();
      await AppNotifications.showMailNotification(
        lang.notification_NewMail_Title,
        AppStrings.getStringWithParams(lang.notification_NewMail_Many, [pending.length]),
        null,
        batchKey: '$key|${jsonEncode(ids)}',
      );
    }
    await prefs.reload();
    notified.addAll(prefs.getStringList(key) ?? []);
    notified.addAll(unique.keys);
    await prefs.setStringList(key, notified.toList());
  }
}

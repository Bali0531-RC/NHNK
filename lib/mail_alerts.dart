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

  /// Host-independent key so automatic failover between institute servers
  /// (e.g. neptun-ws01 -> neptun-ws03) never resets the notified set.
  static String? _userHistoryKey(String kind){
    final user = (storage.DataCache.getUsername() ?? '').trim().toUpperCase();
    if (user.isEmpty) return null;
    return 'MailAlertUser_${kind}_${sha256.convert(utf8.encode(user))}';
  }

  static Future<void> _safeReload(SharedPreferences prefs) async {
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('CachedMails_')) continue;
      final raw = prefs.getString(key);
      if (raw != null && raw.contains('\u0000')) {
        return;
      }
    }
    try {
      await prefs.reload();
    } catch (_) {}
  }

  /// Must be read before the mail cache is rewritten.
  static Future<Set<String>> readCachedMailIds() async{
    final prefs = await SharedPreferences.getInstance();
    await _safeReload(prefs);
    final userSeenKey = _userHistoryKey('seen');
    final userNotifiedKey = _userHistoryKey('notified');
    final seen = <String>{
      ...(prefs.getStringList(_historyKey('seen')) ?? const <String>[]),
      if (userSeenKey != null) ...(prefs.getStringList(userSeenKey) ?? const <String>[]),
      ...(prefs.getStringList(_historyKey('notified')) ?? const <String>[]),
      if (userNotifiedKey != null) ...(prefs.getStringList(userNotifiedKey) ?? const <String>[]),
    };
    final len = prefs.getInt('CachedMailsLength') ?? 0;
    for(int i = 0; i < len; i++){
      final raw = prefs.getString('CachedMails_$i');
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
    final seenList = seen.toList();
    final prefs = await SharedPreferences.getInstance();
    // Write CachedMails_* as valid JSON first and remove stale slots so any
    // legacy \u0000 (&#0;) entries in FlutterSharedPreferences.xml are purged
    // before any future prefs.reload().
    for(int i = 0; i < mails.length; i++){
      await prefs.setString('CachedMails_$i', mails[i].toString());
    }
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith('CachedMails_')) continue;
      final index = int.tryParse(key.substring('CachedMails_'.length));
      if (index != null && index >= mails.length) {
        await prefs.remove(key);
      }
    }
    await prefs.setInt('CachedMailsLength', mails.length);
    await prefs.setStringList(_historyKey('seen'), seenList);
    final userSeenKey = _userHistoryKey('seen');
    if (userSeenKey != null) {
      await prefs.setStringList(userSeenKey, seenList);
    }
    await prefs.setInt('CachedMailsUnread', unread);
    await prefs.setInt('CachedMailsTotal', total);
    await prefs.setString('MailCacheTime', DateTime.now().toString());
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
    await _safeReload(prefs);
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
    await _safeReload(prefs);
    final key = _historyKey('notified');
    final userKey = _userHistoryKey('notified');
    final seenKey = _historyKey('seen');
    final userSeenKey = _userHistoryKey('seen');
    final notified = <String>{
      ...(prefs.getStringList(key) ?? const <String>[]),
      if (userKey != null) ...(prefs.getStringList(userKey) ?? const <String>[]),
    };
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

    notified.addAll(unique.keys);
    final notifiedList = notified.toList();
    await prefs.setStringList(key, notifiedList);
    if (userKey != null) {
      await prefs.setStringList(userKey, notifiedList);
    }
    final seen = <String>{
      ...(prefs.getStringList(seenKey) ?? const <String>[]),
      if (userSeenKey != null) ...(prefs.getStringList(userSeenKey) ?? const <String>[]),
      ...unique.keys,
    }.toList();
    await prefs.setStringList(seenKey, seen);
    if (userSeenKey != null) {
      await prefs.setStringList(userSeenKey, seen);
    }
  }
}

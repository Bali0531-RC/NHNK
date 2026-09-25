import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nhnk/platform_support.dart';

import 'API/api_coms.dart' as api;
import 'language.dart';
import 'mail_alerts.dart';
import 'storage.dart' as storage;

const String markMailReadAction = 'nhnk_mark_mail_read';

/// Compiled in rather than taken from a downloadable pack, like the other warnings.
String _markAsReadLabel() => AppStrings.getCurrentLangCode() == 'hu'
    ? 'Megjelölés olvasottként'
    : 'Mark as read';

/// Runs on a background isolate with none of the app's statics populated, so the
/// stored session has to be loaded before the request can be made.
@pragma('vm:entry-point')
void onNotificationBackgroundResponse(NotificationResponse response) {
  if (response.actionId != markMailReadAction) return;
  final id = response.payload;
  if (id == null || id.isEmpty) return;
  () async {
    try {
      await storage.DataCache.loadData();
      if(await api.MailRequest.setMailRead(id)){
        await MailAlerts.markCachedMailRead(id);
      }
    } catch (_) {}
  }();
}

class AppNotifications {
  static final FlutterLocalNotificationsPlugin _localnotifs =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static const String _scheduledPrefix = 'nhnk:scheduled:';

  static Future<void> initialize() async {
    await initializeHeadless();
    if (AppPlatform.isAndroid) {
      await _localnotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Asked for at the moment the user turns background checks on, where the trip to
  /// the system settings screen makes sense to them. Returns false if it was denied.
  static Future<bool> requestExactAlarms() async {
    if (!AppPlatform.isAndroid) return true;
    final android = _localnotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestExactAlarmsPermission() ?? false;
  }

  static Future<bool> exactAlarmsAllowed() async {
    if (!AppPlatform.isAndroid) return true;
    final android = _localnotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Same plugin setup minus the permission prompts: requestExactAlarmsPermission
  /// opens a settings screen, which must never happen from a background task.
  static Future<void> initializeHeadless() async {
    if (AppPlatform.isWeb) return;
    try {
      await (_initialization ??= _initializePlugin());
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initializePlugin() async {
    if (AppPlatform.isMobile) {
      tz.initializeTimeZones();
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    }
    await _localnotifs.initialize(
      settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Dismiss')),
      onDidReceiveBackgroundNotificationResponse:
          onNotificationBackgroundResponse,
    );
  }

  static Future<void> cancelScheduledNotifs() async {
    if (AppPlatform.isWeb) return;
    await initializeHeadless();
    await _localnotifs.cancelAll();
  }

  static Future<void> cancelScheduledNotifsId(int id,
      {Set<int> keep = const {}}) async {
    if (AppPlatform.isWeb) return;
    await initializeHeadless();
    final pending = await _localnotifs.pendingNotificationRequests();
    final legacyTitle = switch (id) {
      0 => 'Vizsga emlékeztető!',
      1 => 'Óra',
      2 => 'Befizetés',
      3 => 'Időszak',
      _ => null,
    };
    for (final item in pending) {
      final legacy = legacyTitle != null &&
          (item.payload?.isEmpty ?? true) &&
          item.title == legacyTitle;
      if ((item.payload == '$_scheduledPrefix$id' || legacy) &&
          !keep.contains(item.id)) {
        await _localnotifs.cancel(id: item.id);
      }
    }
  }

  static int _stableId(String value) {
    var result = 0;
    for (final unit in value.codeUnits) {
      result = (result * 31 + unit) & 0x3fffffff;
    }
    return result;
  }

  static Future<int?> scheduleNotification(
      String title, String content, DateTime time, int id) async {
    if (!AppPlatform.isMobile) return null;
    await initializeHeadless();
    final tzTime = tz.TZDateTime.from(time, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (!tzTime.isAfter(now)) {
      return null;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails('0', 'NHNK Időzített',
          channelDescription:
              'Olyan értesítések csatornája, amelyeket időzítetten, azaz a nap folyamán valamikor akar az applikáció megjeleníteni neked.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'NHNK Időzített Értesítés',
          styleInformation:
              BigTextStyleInformation(content, contentTitle: title)),
      linux: const LinuxNotificationDetails(
        defaultActionName: 'Dismiss',
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    final notificationId =
        _stableId('$id|${time.millisecondsSinceEpoch}|$title|$content');
    final canScheduleExactly = await exactAlarmsAllowed();

    Future<void> schedule(AndroidScheduleMode mode) async {
      await _localnotifs.zonedSchedule(
        id: notificationId,
        title: title,
        body: content,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: '$_scheduledPrefix$id',
      );
    }

    try {
      await schedule(canScheduleExactly
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
    } on PlatformException catch (error) {
      if (error.code != 'exact_alarms_not_permitted') rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
    return notificationId;
  }

  /// Same as [showNotification] but carries a mark-as-read action for a single mail.
  static Future<void> showMailNotification(
      String title, String desc, String? mailId, {String? batchKey}) async {
    if (AppPlatform.isWeb) return;
    await initializeHeadless();
    final actions = mailId == null || mailId.isEmpty
        ? const <AndroidNotificationAction>[]
        : <AndroidNotificationAction>[
            AndroidNotificationAction(
              markMailReadAction,
              _markAsReadLabel(),
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ];

    final details = NotificationDetails(
      android: AndroidNotificationDetails('1', 'NHNK Azonnali',
          channelDescription:
              'Olyan értesítések csatornája, amelyeket azonnal akar az applikáció megjeleníteni neked.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'NHNK Azonnali Értesítés',
          actions: actions,
          onlyAlertOnce: true,
          styleInformation: BigTextStyleInformation(desc, contentTitle: title)),
      linux: const LinuxNotificationDetails(
        defaultActionName: 'Dismiss',
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    await _localnotifs.show(
      id: 0x40000000 | _stableId('mail|${batchKey ?? mailId ?? '$title|$desc'}'),
      title: title,
      body: desc,
      notificationDetails: details,
      payload: mailId,
    );
  }

  static Future<void> showNotification(String title, String desc) async {
    if (AppPlatform.isWeb) return;
    await initializeHeadless();
    final details = NotificationDetails(
      android: AndroidNotificationDetails('1', 'NHNK Azonnali',
          channelDescription:
              'Olyan értesítések csatornája, amelyeket azonnal akar az applikáció megjeleníteni neked.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'NHNK Azonnali Értesítés',
          styleInformation: BigTextStyleInformation(desc, contentTitle: title)),
      linux: const LinuxNotificationDetails(
        defaultActionName: 'Dismiss',
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    await _localnotifs.show(
      id: 0x40000000 | _stableId('alert|$title|$desc'),
      title: title,
      body: desc,
      notificationDetails: details,
    );
  }
}

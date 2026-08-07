import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nhnk/platform_support.dart';

class AppNotifications{
  static final FlutterLocalNotificationsPlugin _localnotifs = FlutterLocalNotificationsPlugin();
  static Future<void> initialize()async{
    Counter();
    if(AppPlatform.isMobile){
      tz.initializeTimeZones();
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      final String timeZone = timeZoneName.identifier;
      tz.setLocalLocation(tz.getLocation(timeZone));

      AndroidFlutterLocalNotificationsPlugin().requestExactAlarmsPermission();
      _localnotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    await _localnotifs.initialize(settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        linux: LinuxInitializationSettings(
            defaultActionName: 'Dismiss'
        )
    ));
  }

  /// Same plugin setup minus the permission prompts: requestExactAlarmsPermission
  /// opens a settings screen, which must never happen from a background task.
  static Future<void> initializeHeadless() async{
    if(AppPlatform.isMobile){
      tz.initializeTimeZones();
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
    }
    await _localnotifs.initialize(settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        linux: LinuxInitializationSettings(defaultActionName: 'Dismiss')
    ));
  }

  static final List<NotificationLink> _scheduledNotifLinks = <NotificationLink>[].toList();
  static Future<void> cancelScheduledNotifs()async{
    //log('cancle');
    await _localnotifs.cancelAll();
    _scheduledNotifLinks.clear();
    Counter.reset();
  }

  static Future<void> cancelScheduledNotifsId(int id)async{
    final matches = _scheduledNotifLinks.where((item) => item.id == id).toList();
    for (var item in matches){
      await _localnotifs.cancel(id: item.counter);
    }
    _scheduledNotifLinks.removeWhere((item) => item.id == id);
  }

  static tz.TZDateTime _convert(int year, int month, int day, int hour, int minute){
    return tz.TZDateTime(
      tz.local,
      year,
      month,
      day,
      hour,
      minute,
    );
  }

  static Future<void> scheduleNotification(String title, String content, DateTime time, int id) async{
    final tzTime = _convert(time.year, time.month, time.day, time.hour, time.minute);
    final now = tz.TZDateTime.now(tz.local);

    if (tzTime.isBefore(now)) {
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
          '0',
          'NHNK Időzített',
          channelDescription: 'Olyan értesítések csatornája, amelyeket időzítetten, azaz a nap folyamán valamikor akar az applikáció megjeleníteni neked.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'NHNK Időzített Értesítés',
          styleInformation: BigTextStyleInformation(content, contentTitle: title)
      ),
      linux: const LinuxNotificationDetails(
        defaultActionName: 'Dismiss',
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    final counter = Counter.getCount();
    _scheduledNotifLinks.add(NotificationLink(id, counter));
    if(AppPlatform.isMobile){
      await _localnotifs.zonedSchedule(
        id: counter,
        title: title,
        body: content,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> showNotification(String title, String desc) async{
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
          '1',
          'NHNK Azonnali',
          channelDescription: 'Olyan értesítések csatornája, amelyeket azonnal akar az applikáció megjeleníteni neked.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'NHNK Azonnali Értesítés',
          styleInformation: BigTextStyleInformation(desc, contentTitle: title)
      ),
      linux: const LinuxNotificationDetails(
        defaultActionName: 'Dismiss',
        urgency: LinuxNotificationUrgency.normal,
      ),
    );
    _localnotifs.show(
      id: Counter.getCount(),
      title: title,
      body: desc,
      notificationDetails: details,
    );
  }
}

class Counter{ // using "static int counter" did not want to increment :(
  static Counter? _instance;
  Counter(){
    _instance = this;
  }

  int _counter = 0;
  static int getCount(){
    //log('${_instance!._counter + 1}');
    return ++_instance!._counter;
  }

  static void reset(){
    _instance!._counter = 0;
  }
}

class NotificationLink{
  final int id;
  final int counter;
  NotificationLink(this.id, this.counter);
}
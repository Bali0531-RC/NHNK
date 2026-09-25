import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/language.dart';
import 'package:nhnk/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  var exactAllowed = true;
  var rejectExact = false;
  var pending = <Map<String, Object?>>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    AppStrings.initialize();
    calls.clear();
    pending = [];
    exactAllowed = true;
    rejectExact = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        timezone, (_) async => 'Europe/Budapest');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'initialize') return true;
      if (call.method == 'canScheduleExactNotifications') return exactAllowed;
      if (call.method == 'pendingNotificationRequests') return pending;
      if (call.method == 'zonedSchedule' &&
          rejectExact &&
          call.arguments['platformSpecifics']['scheduleMode'] ==
              'exactAllowWhileIdle') {
        throw PlatformException(code: 'exact_alarms_not_permitted');
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  test(
      'background alerts work without foreground initialization or permission prompts',
      () async {
    await AppNotifications.showNotification('New grade', 'A result arrived');
    await AppNotifications.showMailNotification(
        'New message', 'Inbox', 'message-123');

    expect(calls.where((call) => call.method == 'show'), hasLength(2));
    expect(calls.where((call) => call.method.startsWith('request')), isEmpty);
    expect(
        calls
            .where((call) => call.method == 'show')
            .map((call) => call.arguments['id']),
        everyElement(greaterThanOrEqualTo(0x40000000)));
  });

  test('scheduling the same reminder reuses its ID and persists its category',
      () async {
    final time = DateTime.now().add(const Duration(days: 1));
    final first =
        await AppNotifications.scheduleNotification('Class', 'Room A', time, 1);
    final second =
        await AppNotifications.scheduleNotification('Class', 'Room A', time, 1);
    final other =
        await AppNotifications.scheduleNotification('Class', 'Room A', time, 0);

    expect(first, second);
    expect(other, isNot(first));
    expect(first, lessThan(0x40000000));
    final schedules =
        calls.where((call) => call.method == 'zonedSchedule').toList();
    expect(schedules.first.arguments['payload'], 'nhnk:scheduled:1');
    expect(schedules.first.arguments['platformSpecifics']['scheduleMode'],
        'exactAllowWhileIdle');
  });

  test('denied exact alarms still schedule an idle-capable reminder', () async {
    exactAllowed = false;
    await AppNotifications.scheduleNotification(
        'Class', 'Room A', DateTime.now().add(const Duration(hours: 1)), 1);
    final schedule =
        calls.singleWhere((call) => call.method == 'zonedSchedule');
    expect(schedule.arguments['platformSpecifics']['scheduleMode'],
        'inexactAllowWhileIdle');
  });

  test(
      'permission revoked during scheduling falls back without losing the reminder',
      () async {
    rejectExact = true;
    await AppNotifications.scheduleNotification(
        'Class', 'Room A', DateTime.now().add(const Duration(hours: 1)), 1);
    final schedules =
        calls.where((call) => call.method == 'zonedSchedule').toList();
    expect(schedules, hasLength(2));
    expect(schedules.first.arguments['id'], schedules.last.arguments['id']);
    expect(schedules.last.arguments['platformSpecifics']['scheduleMode'],
        'inexactAllowWhileIdle');
  });

  test(
      'category cancellation uses persisted requests, not a foreground-only list',
      () async {
    pending = [
      {'id': 101, 'payload': 'nhnk:scheduled:1'},
      {'id': 102, 'payload': 'nhnk:scheduled:2'},
      {'id': 103, 'payload': 'nhnk:scheduled:1'},
    ];
    await AppNotifications.cancelScheduledNotifsId(1, keep: {103});
    final cancelled = calls.where((call) => call.method == 'cancel').toList();
    expect(cancelled, hasLength(1));
    expect(cancelled.single.arguments['id'], 101);
  });

  test('past reminders are not delivered late when the app opens', () async {
    final result = await AppNotifications.scheduleNotification('Class',
        'Room A', DateTime.now().subtract(const Duration(minutes: 1)), 1);
    expect(result, isNull);
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
  });

  test(
      'upgrading cancels legacy class reminders without removing other categories',
      () async {
    pending = [
      {'id': 10, 'title': 'Óra', 'payload': ''},
      {'id': 11, 'title': 'Befizetés', 'payload': null},
      {'id': 12, 'title': 'Class', 'payload': 'nhnk:scheduled:1'},
    ];
    await AppNotifications.cancelScheduledNotifsId(1, keep: {12});
    final cancelled = calls.where((call) => call.method == 'cancel').toList();
    expect(cancelled, hasLength(1));
    expect(cancelled.single.arguments['id'], 10);
  });
}

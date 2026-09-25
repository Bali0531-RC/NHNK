import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/background_worker.dart';
import 'package:nhnk/language.dart';
import 'package:nhnk/storage.dart' as storage;
import 'package:nhnk/timetable_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const widgetChannel = MethodChannel('home_widget');
  const notificationChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const timezoneChannel = MethodChannel('flutter_timezone');
  final calls = <MethodCall>[];
  var installedWidgets = <Map<String, Object?>>[];
  late RecordingWorkmanager worker;
  final previousWorkmanager = WorkmanagerPlatform.instance;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    AppStrings.initialize();
    SharedPreferences.setMockInitialValues({});
    Workmanager();
    worker = RecordingWorkmanager();
    WorkmanagerPlatform.instance = worker;
    installedWidgets = [];
    await storage.DataCache.setHasLogin(1);
    await storage.DataCache.setUsername('TEST');
    await storage.DataCache.setNeedClassNotifications(1);
    await storage.DataCache.setNeedGradeNotifications(0);
    await storage.DataCache.setNeedMailNotifications(0);
    await storage.DataCache.setBackgroundGradeCheckMinutes(60);
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        timezoneChannel, (_) async => 'Europe/Budapest');
    messenger.setMockMethodCallHandler(widgetChannel, (call) async {
      calls.add(call);
      if (call.method == 'getInstalledWidgets') return installedWidgets;
      return true;
    });
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      calls.add(call);
      if (call.method == 'pendingNotificationRequests')
        return <Map<String, Object?>>[];
      if (call.method == 'initialize' ||
          call.method == 'canScheduleExactNotifications') return true;
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    WorkmanagerPlatform.instance = previousWorkmanager;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      widgetChannel,
      notificationChannel,
      timezoneChannel
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  api.CalendarEntry lesson(DateTime start) => api.CalendarEntry.fromModern(
        startEpoch: start.millisecondsSinceEpoch,
        endEpoch: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        location: 'Room A',
        title: 'Test class',
        eventType: 0,
        subjectCode: 'TEST',
        teacher: 'Test teacher',
        classInstanceId: '',
        taskId: '',
      );

  test('current-week cache is complete before the widget update', () async {
    final entry = lesson(DateTime.now().add(const Duration(hours: 2)));
    await TimetableSync.writeCurrentWeek([entry]);
    expect(await storage.getInt('CachedCalendarLength'), 1);
    expect(await storage.getString('CachedCalendar_0'), entry.toString());
    expect(await storage.getInt('CalendarCacheWrittenAt'), greaterThan(0));
    final save = calls.singleWhere((call) => call.method == 'saveWidgetData');
    final snapshot = jsonDecode(save.arguments['data'] as String) as Map;
    expect(snapshot['entries'], [entry.toString()]);
    expect(calls.last.method, 'updateWidget');
    expect(
        calls.last.arguments['qualifiedAndroidName'], TimetableSync.provider);
  });

  test('a failed week does not replace existing cached classes', () async {
    await storage.saveInt('CachedCalendarLength', 1);
    await storage.saveInt('CalendarCacheWrittenAt', 123);
    final success = await TimetableSync.refresh(fetchWeek: (_) async => null);
    expect(success, isFalse);
    expect(await storage.getInt('CachedCalendarLength'), 1);
    expect(await storage.getInt('CalendarCacheWrittenAt'), 123);
    expect(calls, isEmpty);
  });

  test('a successful empty timetable clears cancelled classes', () async {
    await storage.saveInt('CachedCalendarLength', 1);
    expect(await TimetableSync.refresh(fetchWeek: (_) async => []), isTrue);
    expect(await storage.getInt('CachedCalendarLength'), 0);
    final save = calls.singleWhere((call) => call.method == 'saveWidgetData');
    expect(jsonDecode(save.arguments['data'] as String)['entries'], isEmpty);
  });

  test('a failed next week keeps the old cache and reminder schedule',
      () async {
    await storage.saveInt('CalendarCacheWrittenAt', 123);
    final entry = lesson(DateTime.now().add(const Duration(hours: 2)));
    expect(
        await TimetableSync.refresh(
            fetchWeek: (week) async => week == 1 ? [entry] : null),
        isFalse);
    expect(await storage.getInt('CalendarCacheWrittenAt'), 123);
    expect(calls, isEmpty);
  });

  test(
      'signing out during a refresh prevents old account data from being published',
      () async {
    await storage.saveInt('HasLogin', 1);
    final result = await TimetableSync.refresh(fetchWeek: (week) async {
      if (week == 2) await storage.saveInt('HasLogin', 0);
      return [];
    });
    expect(result, isFalse);
    expect(await storage.getInt('CalendarCacheWrittenAt'), isNull);
    expect(calls, isEmpty);
  });

  test('disabling class alerts cancels them without scheduling new ones',
      () async {
    await storage.DataCache.setNeedClassNotifications(0);
    await TimetableSync.scheduleClasses(
        [lesson(DateTime.now().add(const Duration(hours: 2)))]);
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
    expect(calls.where((call) => call.method == 'pendingNotificationRequests'),
        hasLength(1));
  });

  test('next-week classes receive reminders without opening that week',
      () async {
    final next = lesson(
        api.CalendarRequest.weekStartFor(2).add(const Duration(hours: 9)));
    expect(
        await TimetableSync.refresh(
            fetchWeek: (week) async => week == 2 ? [next] : []),
        isTrue);
    expect(calls.where((call) => call.method == 'zonedSchedule'), hasLength(3));
    expect(await storage.getInt('CachedCalendarLength'), 0);
    final saved = await storage.getStringList('BackgroundCalendarEntries');
    expect(saved, [next.toString()]);
  });

  test(
      'class reminders refresh on their own when mail and grade alerts are off',
      () async {
    await BackgroundWorker.sync();
    expect(worker.periodic['nhnk-timetable-sync']?.frequency,
        const Duration(minutes: 15));
    expect(worker.periodic.containsKey('nhnk-grade-check'), isFalse);
  });

  test('installed widgets refresh even when every notification switch is off',
      () async {
    await storage.DataCache.setNeedClassNotifications(0);
    installedWidgets = [
      {'androidClassName': TimetableSync.provider, 'androidWidgetId': 1}
    ];
    await BackgroundWorker.sync();
    expect(worker.periodic['nhnk-timetable-sync']?.frequency,
        const Duration(minutes: 15));
  });

  test('no widget and no requested alerts cancel periodic work', () async {
    await storage.DataCache.setNeedClassNotifications(0);
    await BackgroundWorker.sync();
    expect(worker.periodic, isEmpty);
    expect(worker.cancelled,
        containsAll(['nhnk-grade-check', 'nhnk-timetable-sync']));
  });

  test('mail polling has no low-battery constraint or initial waiting period',
      () async {
    await storage.DataCache.setNeedMailNotifications(1);
    await BackgroundWorker.sync();
    final alert = worker.periodic['nhnk-grade-check']!;
    expect(alert.frequency, const Duration(minutes: 60));
    expect(alert.initialDelay, isNull);
    expect(alert.constraints?.requiresBatteryNotLow, isFalse);
    expect(alert.constraints?.networkType, NetworkType.connected);
  });

  test('manual widget refresh is deduplicated and queued for connectivity',
      () async {
    await BackgroundWorker.refreshTimetable();
    expect(worker.manualPolicy, ExistingWorkPolicy.keep);
    expect(worker.manualConstraints?.networkType, NetworkType.connected);
  });
}

class RecordingWorkmanager extends WorkmanagerPlatform {
  final periodic = <String,
      ({
    Duration? frequency,
    Duration? initialDelay,
    Constraints? constraints
  })>{};
  final cancelled = <String>[];
  ExistingWorkPolicy? manualPolicy;
  Constraints? manualConstraints;

  @override
  Future<void> initialize(Function callbackDispatcher,
      {bool isInDebugMode = false}) async {}

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    cancelled.add(uniqueName);
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    periodic[uniqueName] = (
      frequency: frequency,
      initialDelay: initialDelay,
      constraints: constraints
    );
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    manualPolicy = existingWorkPolicy;
    manualConstraints = constraints;
  }
}

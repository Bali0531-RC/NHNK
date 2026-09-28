import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/grade_alerts.dart';
import 'package:nhnk/language.dart';
import 'package:nhnk/storage.dart' as storage;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final shown = <MethodCall>[];

  // The modern API gives every subject id 0.
  api.Subject subject(String name, int grade) => api.Subject(grade > 0, 3, name, 0, grade, 0);

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    AppStrings.initialize();
    SharedPreferences.setMockInitialValues({});
    await storage.DataCache.setUsername('TEST');
    await storage.DataCache.setInstituteUrl('https://example.invalid/hallgato');
    await storage.DataCache.setIsDemoAccount(0);
    await storage.DataCache.setNeedGradeNotifications(1);
    await storage.DataCache.setHasCachedMarkbook(0);
    shown.clear();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Europe/Budapest');
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'show') shown.add(call);
      return call.method == 'initialize' ? true : null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  test('subjects sharing id 0 are compared by name, not against each other', () async {
    final before = [subject('Analysis', 4), subject('Physics', 3), subject('Algebra', 0)];
    await GradeAlerts.writeCache(before);
    final previous = await GradeAlerts.readCachedGrades();

    expect(GradeAlerts.findNewGrades(previous, before), isEmpty);

    final after = [subject('Analysis', 4), subject('Physics', 3), subject('Algebra', 5)];
    final changed = GradeAlerts.findNewGrades(previous, after);
    expect(changed.map((s) => s.name), ['Algebra']);
  });

  test('each new grade gets its own notification with subject and grade', () async {
    await GradeAlerts.notify([subject('Algebra', 5), subject('Physics', 3)]);
    expect(shown, hasLength(2));
    final bodies = shown.map((c) => c.arguments['body']).toList();
    expect(bodies.any((b) => b.toString().contains('Algebra') && b.toString().contains('5')), isTrue);
    expect(bodies.any((b) => b.toString().contains('Physics') && b.toString().contains('3')), isTrue);
    expect(shown.first.arguments['id'], isNot(shown.last.arguments['id']));
  });

  test('a grade already announced is never announced again', () async {
    await GradeAlerts.notify([subject('Algebra', 5)]);
    await GradeAlerts.notify([subject('Algebra', 5)]);
    expect(shown, hasLength(1));
  });

  test('concurrent refreshes announce a grade once', () async {
    await Future.wait([
      GradeAlerts.notify([subject('Algebra', 5)]),
      GradeAlerts.notify([subject('Algebra', 5)]),
    ]);
    expect(shown, hasLength(1));
  });

  test('a changed grade for the same subject is announced', () async {
    await GradeAlerts.notify([subject('Algebra', 3)]);
    await GradeAlerts.notify([subject('Algebra', 4)]);
    expect(shown, hasLength(2));
  });

  test('a first sync announces nothing', () async {
    final previous = await GradeAlerts.readCachedGrades();
    expect(GradeAlerts.findNewGrades(previous, [subject('Algebra', 5)]), isEmpty);
  });

  test('disabled grade notifications stay silent', () async {
    await storage.DataCache.setNeedGradeNotifications(0);
    await GradeAlerts.notify([subject('Algebra', 5)]);
    expect(shown, isEmpty);
  });
}

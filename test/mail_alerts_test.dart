import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/language.dart';
import 'package:nhnk/mail_alerts.dart';
import 'package:nhnk/storage.dart' as storage;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final shown = <MethodCall>[];

  api.MailEntry mail(String id) => api.MailEntry('Subject', 'Body', 'Sender', 1000, false, id);

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    AppStrings.initialize();
    SharedPreferences.setMockInitialValues({});
    await storage.DataCache.setUsername('TEST');
    await storage.DataCache.setInstituteUrl('https://example.invalid/hallgato');
    await storage.DataCache.setIsDemoAccount(0);
    await storage.DataCache.setNeedMailNotifications(1);
    await storage.DataCache.setHasCachedMail(0);
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

  test('the same unread batch does not notify on every fetch', () async {
    final fresh = [for (var index = 0; index < 12; index++) mail('message-$index')];
    await MailAlerts.notify(fresh);
    await MailAlerts.notify(fresh);
    expect(shown, hasLength(1));
    expect(shown.single.arguments['platformSpecifics']['onlyAlertOnce'], isTrue);
  });

  test('different batches with the same count still get distinct notification IDs', () async {
    await MailAlerts.notify([mail('first-a'), mail('first-b')]);
    await MailAlerts.notify([mail('next-a'), mail('next-b')]);
    expect(shown, hasLength(2));
    expect(shown.first.arguments['id'], isNot(shown.last.arguments['id']));
  });

  test('invalidating display cache does not forget already seen mail IDs', () async {
    await MailAlerts.writeCache([mail('known')], 1, 1);
    await storage.DataCache.setHasCachedMail(0);
    expect(await MailAlerts.readCachedMailIds(), contains('known'));
  });

  test('replacing the display cache does not make older messages new again', () async {
    await MailAlerts.writeCache([mail('known'), mail('older')], 2, 30);
    await MailAlerts.writeCache([mail('latest')], 3, 31);
    final seen = await MailAlerts.readCachedMailIds();
    expect(seen, containsAll(['known', 'older', 'latest']));
    expect(MailAlerts.findNewMails(seen, [mail('known'), mail('older')]), isEmpty);
  });

  test('concurrent retries announce one batch only once', () async {
    await Future.wait([
      MailAlerts.notify([mail('same')]),
      MailAlerts.notify([mail('same')]),
    ]);
    expect(shown, hasLength(1));
  });

  test('only genuinely new IDs in a later batch are announced', () async {
    await MailAlerts.notify([mail('known')]);
    await MailAlerts.notify([mail('known'), mail('new'), mail('new')]);
    expect(shown, hasLength(2));
    expect(shown.last.arguments['payload'], 'new');
  });

  test('notification history belongs to the account', () async {
    await MailAlerts.notify([mail('same-id')]);
    await storage.DataCache.setUsername('OTHER');
    await MailAlerts.notify([mail('same-id')]);
    expect(shown, hasLength(2));
  });

  test('confirmed read updates only that message and decrements once', () async {
    await MailAlerts.writeCache([mail('opened'), mail('other')], 2, 2);
    await MailAlerts.markCachedMailRead('opened');
    await MailAlerts.markCachedMailRead('opened');
    final opened = api.MailEntry('', '', '', 0, false, '')
        .fillWithExisting((await storage.getString('CachedMails_0'))!);
    final other = api.MailEntry('', '', '', 0, false, '')
        .fillWithExisting((await storage.getString('CachedMails_1'))!);
    expect(opened.isRead, isTrue);
    expect(other.isRead, isFalse);
    expect(await storage.getInt('CachedMailsUnread'), 1);
    expect(storage.DataCache.getHasCachedMail(), isTrue);
    expect(await MailAlerts.readCachedMailIds(), containsAll(['opened', 'other']));
  });

  test('an uncached or already read message does not reduce the cached count', () async {
    final read = mail('read')..isRead = true;
    await MailAlerts.writeCache([read], 0, 1);
    await MailAlerts.markCachedMailRead('missing');
    await MailAlerts.markCachedMailRead('read');
    expect(await storage.getInt('CachedMailsUnread'), 0);
  });

  test('first sync and already-read messages never announce the whole inbox', () async {
    expect(MailAlerts.findNewMails({}, [mail('initial')]), isEmpty);
    final read = mail('read')..isRead = true;
    await MailAlerts.notify([read]);
    expect(shown, isEmpty);
  });

  test('a failed notification remains eligible for a later successful retry', () async {
    var fail = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'show') {
        if (fail) throw PlatformException(code: 'test_failure');
        shown.add(call);
      }
      return call.method == 'initialize' ? true : null;
    });
    await expectLater(MailAlerts.notify([mail('retry')]), throwsA(isA<PlatformException>()));
    fail = false;
    await MailAlerts.notify([mail('retry')]);
    expect(shown, hasLength(1));
  });
}
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/language.dart';
import 'package:nhnk/storage.dart' as storage;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final requests = <http.Request>[];
  late List<Map<String, Object?>> posts;
  var postStatus = 200;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async => call.method == 'readAll' ? <String, String>{} : null);
    AppStrings.initialize();
    await storage.DataCache.setIsModernApi(true);
    await storage.DataCache.setIsDemoAccount(0);
    await storage.DataCache.setInstituteUrl('https://example.invalid/hallgato');
    await storage.DataCache.setAccessToken('synthetic-token');
    requests.clear();
    postStatus = 200;
    posts = [
      {'postId': 'post-new', 'isRead': false, 'htmlText': '<p>New content</p>'},
      {'postId': 'post-old', 'isRead': true, 'htmlText': '<p>Older content</p>'},
    ];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(secure, null);
  });

  http.Client client() => MockClient((request) async {
    requests.add(request);
    if (request.method == 'GET') {
      return http.Response(jsonEncode({'data': {'posts': posts}, 'notification': []}), 200);
    }
    return http.Response(jsonEncode({'data': null, 'notification': []}), postStatus);
  });

  test('opening a message marks only its unread posts using the official endpoint', () async {
    final result = await http.runWithClient(() => api.MailRequest.openMail('message-1', 'Preview'), client);
    expect(result.markedRead, isTrue);
    expect(result.text, contains('New content'));
    expect(result.text, contains('Older content'));
    expect(requests, hasLength(2));
    expect(requests.first.url.path, '/hallgato/api/Messages/message-1/Posts');
    final markRead = requests.last;
    expect(markRead.method, 'POST');
    expect(markRead.url.path, '/hallgato/api/Messages/message-1/Posts/Processed');
    expect(jsonDecode(markRead.body), {'postIds': ['post-new']});
    expect(markRead.headers['Authorization'], 'Bearer synthetic-token');
  });

  test('rejected read update keeps the content available without claiming success', () async {
    postStatus = 403;
    final result = await http.runWithClient(() => api.MailRequest.openMail('message-1', 'Preview'), client);
    expect(result.markedRead, isFalse);
    expect(result.text, contains('New content'));
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
  });

  test('already-read posts do not generate another write', () async {
    posts = [{'postId': 'post-old', 'isRead': true, 'htmlText': 'Read content'}];
    final result = await http.runWithClient(() => api.MailRequest.openMail('message-1', 'Preview'), client);
    expect(result.markedRead, isTrue);
    expect(requests, hasLength(1));
  });

  test('notification mark-read action fetches and processes the specified message', () async {
    expect(await http.runWithClient(() => api.MailRequest.setMailRead('message-2'), client), isTrue);
    expect(requests.last.url.path, '/hallgato/api/Messages/message-2/Posts/Processed');
  });

  test('missing post IDs are not guessed and do not produce a write', () async {
    posts = [{'isRead': false, 'htmlText': 'Content without ID'}];
    final result = await http.runWithClient(() => api.MailRequest.openMail('message-1', 'Preview'), client);
    expect(result.markedRead, isFalse);
    expect(requests, hasLength(1));
  });

  test('an empty response cannot mark a message as read', () async {
    posts = [];
    expect(await http.runWithClient(() => api.MailRequest.setMailRead('message-1'), client), isFalse);
    expect(requests, hasLength(1));
  });

  test('failed content download never sends a mark-read request', () async {
    final unavailable = MockClient((request) async {
      requests.add(request);
      return http.Response('{"data":null}', 503);
    });
    await expectLater(
      http.runWithClient(() => api.MailRequest.openMail('message-1', 'Preview'), () => unavailable),
      throwsStateError,
    );
    expect(requests.every((request) => request.method == 'GET'), isTrue);
  });

  test('server-declared failure is not treated as a confirmed read', () async {
    final refused = MockClient((request) async {
      requests.add(request);
      return request.method == 'GET'
          ? http.Response(jsonEncode({'data': {'posts': posts}}), 200)
          : http.Response('{"data":{"isSuccessful":false}}', 200);
    });
    expect(await http.runWithClient(() => api.MailRequest.setMailRead('message-1'), () => refused), isFalse);
  });
}
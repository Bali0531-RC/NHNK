import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/startup_trace.dart';

void main() {
  setUp(NetTrace.clear);

  // The whole point of NetTrace.record taking a Uri is that callers cannot leak
  // the parts of it that carry credentials.
  test('a query string never reaches the log', () {
    NetTrace.record(
      Uri.parse('https://neptun.example.hu/hallgato/api/Calendar?token=SECRET123&id=42'),
      120,
    );

    final entry = NetTrace.entries.single;
    expect(entry.host, 'neptun.example.hu');
    expect(entry.path, '/hallgato/api/Calendar');
    expect(entry.toString(), isNot(contains('SECRET123')));
    expect('${entry.host}${entry.path}', isNot(contains('token')));
  });

  test('credentials in userInfo do not survive either', () {
    NetTrace.record(
      Uri.parse('https://neptunuser:hunter2@neptun.example.hu/hallgato/api/Terms'),
      80,
    );

    final entry = NetTrace.entries.single;
    expect(entry.host, 'neptun.example.hu');
    expect(entry.host, isNot(contains('hunter2')));
    expect(entry.path, isNot(contains('neptunuser')));
  });

  // The calendar export link authenticates on its own, so even the host is withheld.
  test('a self authenticating link is withheld entirely', () {
    NetTrace.record(
      Uri.parse('https://neptun.example.hu/export/cal.ics?key=PERMANENT'),
      200,
      redactUrl: true,
    );

    final entry = NetTrace.entries.single;
    expect(entry.path, '(redacted)');
    expect(entry.host, isNot(contains('neptun.example.hu')));
    expect(entry.host, isNot(contains('PERMANENT')));
  });

  test('the buffer stays bounded so a long session cannot grow forever', () {
    for (var i = 0; i < 260; i++) {
      NetTrace.record(Uri.parse('https://host.example/api/$i'), 1);
    }
    expect(NetTrace.entries.length, 200);
    // oldest dropped, newest kept
    expect(NetTrace.entries.last.path, '/api/259');
    expect(NetTrace.entries.first.path, '/api/60');
  });

  test('signing out drops the history', () {
    NetTrace.record(Uri.parse('https://host.example/api/x'), 5);
    expect(NetTrace.entries, isNotEmpty);
    NetTrace.clear();
    expect(NetTrace.entries, isEmpty);
    expect(NetTrace.count, 0);
  });
}

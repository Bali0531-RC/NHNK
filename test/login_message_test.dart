import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;

/// A failed login used to look the same whatever the cause, so the obvious move was
/// to try again, and enough retries suspend a Neptun account. These pin the parsing
/// that lets the login screen say what actually happened.
void main() {
  String? message(dynamic decoded) => api.InstitutesRequest.serverMessageFrom(decoded);

  test('reads a notification carried as objects', () {
    expect(
      message({
        'data': null,
        'notification': [
          {'message': 'A felhasználó felfüggesztve.'}
        ]
      }),
      'A felhasználó felfüggesztve.',
    );
  });

  test('reads a notification carried as plain strings', () {
    expect(
      message({
        'notification': ['Hibás jelszó.']
      }),
      'Hibás jelszó.',
    );
  });

  test('joins several notifications rather than dropping all but one', () {
    expect(
      message({
        'notification': [
          {'message': 'Első.'},
          {'message': 'Második.'}
        ]
      }),
      'Első. Második.',
    );
  });

  test('accepts the other key spellings seen in the wild', () {
    expect(message({'notification': [{'Message': 'Nagy M.'}]}), 'Nagy M.');
    expect(message({'notification': [{'text': 'kis text'}]}), 'kis text');
  });

  test('a successful login carries nothing to show', () {
    expect(message({'data': {'accessToken': 'x'}, 'notification': []}), isNull);
  });

  test('malformed input never throws', () {
    expect(message(null), isNull);
    expect(message('not a map'), isNull);
    expect(message({'notification': 'not a list'}), isNull);
    expect(message({'notification': [42]}), isNull);
    expect(message({'notification': [{'unexpected': 'key'}]}), isNull);
    expect(message({'notification': [{'message': '   '}]}), isNull);
  });
}

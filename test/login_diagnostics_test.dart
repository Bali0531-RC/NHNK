import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nhnk/API/login_diagnostics.dart';

void main() {
  setUp(LoginDiagnostics.clear);

  test('recognizes the modern two-factor envelope without exporting secrets', () {
    final report = LoginDiagnostics.summarize(http.Response(jsonEncode({
      'data': {
        'isTwoFactorRequired': true,
        'accessToken': 'PRIVATE_TOKEN',
        'captchaIdentifier': 'PRIVATE_CAPTCHA',
        'userName': 'PRIVATE_USER',
        'password': 'PRIVATE_PASSWORD',
        'unexpected_PRIVATE_KEY': 'PRIVATE_VALUE',
      },
      'notification': [{'message': 'PRIVATE_SERVER_MESSAGE'}],
    }), 202, headers: {'set-cookie': 'PRIVATE_COOKIE'}));
    expect(report, contains('HTTP 202'));
    expect(report, contains('isTwoFactorRequired=true'));
    expect(report, contains('accessToken=string'));
    expect(report, contains('notification=list; count=1'));
    expect(report, contains('setCookie=true'));
    expect(report, isNot(contains('PRIVATE')));
  });

  test('malformed flags and error messages cannot leak values', () {
    final report = LoginDiagnostics.summarize(http.Response(jsonEncode({
      'data': {
        'isTwoFactorRequired': 'PRIVATE',
        'requiresCaptcha': true,
        'ErrorMessage': 'PRIVATE',
        'statusCode': 'PRIVATE',
      },
      'error': {'PRIVATE': 'PRIVATE'},
    }), 401));
    expect(report, contains('isTwoFactorRequired=string'));
    expect(report, contains('requiresCaptcha=true'));
    expect(report, contains('HTTP 401'));
    expect(report, isNot(contains('PRIVATE')));
  });

  test('HTML, redirects and unexpected JSON shapes are safe', () {
    for (final body in ['<html>PRIVATE</html>', 'PRIVATE', '["PRIVATE"]', 'null', '42']) {
      final report = LoginDiagnostics.summarize(http.Response(body, 302, headers: {
        'location': 'https://example.test/PRIVATE',
        'set-cookie': 'PRIVATE',
      }));
      expect(report, contains('redirect=true'));
      expect(report, isNot(contains('PRIVATE')));
    }
  });

  test('events are opt-in and never expose URLs or exception details', () {
    LoginDiagnostics.begin('https://example.test/PRIVATE?token=PRIVATE', legacy: false);
    LoginDiagnostics.failure(LoginStage.deviceCookie,
        PlatformException(code: 'PRIVATE', message: 'PRIVATE', details: 'PRIVATE'));
    final report = LoginDiagnostics.report();
    expect(report, isNot(contains('PRIVATE')));
    if (LoginDiagnostics.enabled) {
      expect(report, contains('other (URL withheld)'));
      expect(report, contains('Failure at deviceCookie: platform/secure storage'));
    } else {
      expect(report, contains('No login events recorded'));
    }
  });

  test('bounded history can be cleared before sharing', () {
    for (var i = 0; i < 100; i++) {
      LoginDiagnostics.stage(LoginStage.request);
    }
    expect(RegExp('Stage: request').allMatches(LoginDiagnostics.report()).length,
        LoginDiagnostics.enabled ? 80 : 0);
    LoginDiagnostics.clear();
    expect(LoginDiagnostics.report(), contains('No login events recorded'));
  });
}

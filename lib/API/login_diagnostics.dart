import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

enum LoginStage { start, deviceCookie, request, response, saveSession, totpSecret, twoFactor, success, rejected }

/// Opt-in diagnostics contain only fixed labels, types, counts and booleans.
/// Never retain bodies, headers, credentials, exception messages or arbitrary keys.
class LoginDiagnostics {
  static const enabled = kDebugMode && bool.fromEnvironment('NHNK_AUTH_DIAGNOSTICS');
  static const build = String.fromEnvironment('NHNK_DIAGNOSTIC_BUILD', defaultValue: 'local');
  static final List<String> _lines = [];

  static void clear() => _lines.clear();

  static void _add(String line) {
    if (!enabled) return;
    _lines.add(line);
    if (_lines.length > 80) _lines.removeAt(0);
  }

  static void begin(String baseUrl, {required bool legacy}) {
    if (!enabled) return;
    final host = Uri.tryParse(baseUrl)?.host;
    final server = switch (host) {
      'neptun-ws01.uni-pannon.hu' => 'Pannon ws01',
      'neptun-ws03.uni-pannon.hu' => 'Pannon ws03',
      _ => 'other (URL withheld)',
    };
    _add('Login: $server; API=${legacy ? "legacy" : "modern"}');
  }

  static void stage(LoginStage stage) => _add('Stage: ${stage.name}');

  static void failure(LoginStage stage, Object error) {
    final category = switch (error) {
      SocketException() => 'network',
      HandshakeException() => 'TLS',
      TimeoutException() => 'timeout',
      FormatException() => 'invalid JSON/URI',
      PlatformException() => 'platform/secure storage',
      http.ClientException() => 'HTTP transport',
      TypeError() => 'unexpected response type',
      _ => 'other (details withheld)',
    };
    _add('Failure at ${stage.name}: $category');
  }

  static void response(http.Response response) {
    if (enabled) _add(summarize(response));
  }

  static String _type(Object? value) => switch (value) {
    null => 'null',
    bool() => 'bool',
    num() => 'number',
    String() => 'string',
    List() => 'list',
    Map() => 'object',
    _ => 'other',
  };

  /// Only known protocol flags may expose their boolean value; other values
  /// (including strings where booleans were expected) expose their type only.
  static String _fields(Map value) {
    final out = <String>[];
    for (final key in [
      'isTwoFactorRequired', 'requiresTwoFactor',
      'isCaptchaRequired', 'requiresCaptcha',
    ]) {
      if (value.containsKey(key)) {
        final flag = value[key];
        out.add('$key=${flag is bool ? flag : _type(flag)}');
      }
    }
    for (final key in [
      'accessToken', 'error', 'ErrorMessage', 'message', 'statusCode',
      'captcha', 'captchaIdentifier',
    ]) {
      if (value.containsKey(key)) out.add('$key=${_type(value[key])}');
    }
    return out.join(', ');
  }

  static String summarize(http.Response response) {
    final out = <String>[
      'HTTP ${response.statusCode}; bytes=${response.bodyBytes.length}; '
          'setCookie=${response.headers.containsKey("set-cookie")}; '
          'redirect=${response.statusCode >= 300 && response.statusCode < 400}',
    ];
    try {
      final decoded = jsonDecode(response.body);
      out.add('JSON=${_type(decoded)}');
      if (decoded is Map) {
        out.add('root: ${_fields(decoded)}');
        final data = decoded['data'];
        out.add('data=${_type(data)}');
        if (data is Map) out.add('data flags: ${_fields(data)}');
        final notification = decoded['notification'];
        out.add('notification=${_type(notification)}'
            '${notification is List ? "; count=${notification.length}" : ""}');
      }
    } catch (_) {
      out.add('body=${response.body.trimLeft().startsWith("<") ? "HTML/XML" : "non-JSON"} (withheld)');
    }
    return out.join('\n');
  }

  static String report() => [
    'NHNK login diagnostics v1; build=$build',
    'No credentials, tokens, cookies, raw URLs or response text included.',
    if (_lines.isEmpty) 'No login events recorded. Try signing in first.',
    ..._lines,
  ].join('\n');
}

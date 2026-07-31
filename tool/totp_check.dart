// Cross-checks the TOTP implementation against known timestamps.
// Usage: dart run tool/totp_check.dart <base32secret> <unixSeconds...>
import 'dart:io';

import 'package:nhnk/API/totp.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/totp_check.dart <secret> <unixSeconds...>');
    exit(2);
  }
  final secret = args.first;
  for (final raw in args.skip(1)) {
    final at = DateTime.fromMillisecondsSinceEpoch(int.parse(raw) * 1000, isUtc: true);
    stdout.writeln('${raw}:${Totp.generate(secret, at: at)}');
  }
}

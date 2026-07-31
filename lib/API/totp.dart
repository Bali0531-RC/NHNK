import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 6238 TOTP, so a stored authenticator secret can answer Neptun's 2FA prompt
/// without the user retyping a code on every re-login.
class Totp {
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Returns null when [secret] is not valid base32.
  static Uint8List? decodeBase32(String secret) {
    final cleaned = secret.replaceAll(RegExp(r'[\s-]'), '').replaceAll('=', '').toUpperCase();
    if (cleaned.isEmpty) return null;

    int buffer = 0;
    int bitsLeft = 0;
    final out = <int>[];

    for (final char in cleaned.codeUnits) {
      final value = _base32Alphabet.indexOf(String.fromCharCode(char));
      if (value < 0) return null;
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        out.add((buffer >> bitsLeft) & 0xff);
      }
    }
    return out.isEmpty ? null : Uint8List.fromList(out);
  }

  static bool isValidSecret(String secret) => decodeBase32(secret) != null;

  /// Returns null when the secret cannot be decoded.
  static String? generate(String secret, {DateTime? at, int period = 30, int digits = 6}) {
    final key = decodeBase32(secret);
    if (key == null) return null;

    final seconds = (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    var counter = seconds ~/ period;

    final counterBytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = counter & 0xff;
      counter >>= 8;
    }

    final digest = Hmac(sha1, key).convert(counterBytes).bytes;
    final offset = digest[digest.length - 1] & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);

    final mod = binary % _pow10(digits);
    return mod.toString().padLeft(digits, '0');
  }

  static int _pow10(int n) {
    var r = 1;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  /// Accepts the raw base32 secret or a full otpauth:// URI copied from Neptun.
  static String? extractSecret(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.toLowerCase().startsWith('otpauth://')) {
      final uri = Uri.tryParse(trimmed);
      final secret = uri?.queryParameters['secret'];
      if (secret == null) return null;
      return isValidSecret(secret) ? secret.replaceAll(RegExp(r'[\s-]'), '').toUpperCase() : null;
    }

    final cleaned = trimmed.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return isValidSecret(cleaned) ? cleaned : null;
  }
}

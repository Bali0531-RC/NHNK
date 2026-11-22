// RFC 6238 TOTP ported from totp.dart

import { hmac } from '@noble/hashes/hmac.js';
import { sha1 } from '@noble/hashes/legacy.js';

const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function decodeBase32(secret: string): Uint8Array | null {
  const cleaned = secret.replace(/[\s-]/g, '').replace(/=/g, '').toUpperCase();
  if (cleaned.length === 0) return null;

  let buffer = 0;
  let bitsLeft = 0;
  const out: number[] = [];

  for (const char of cleaned) {
    const value = BASE32.indexOf(char);
    if (value < 0) return null;
    buffer = (buffer << 5) | value;
    bitsLeft += 5;
    if (bitsLeft >= 8) {
      bitsLeft -= 8;
      out.push((buffer >> bitsLeft) & 0xff);
      // mask so long secrets dont overflow 32 bits
      buffer &= (1 << bitsLeft) - 1;
    }
  }
  return out.length === 0 ? null : Uint8Array.from(out);
}

export function isValidSecret(secret: string): boolean {
  return decodeBase32(secret) != null;
}

export function generateTotp(secret: string, atMs?: number, period = 30, digits = 6): string | null {
  const key = decodeBase32(secret);
  if (!key) return null;

  const seconds = Math.floor((atMs ?? Date.now()) / 1000);
  let counter = Math.floor(seconds / period);

  const counterBytes = new Uint8Array(8);
  for (let i = 7; i >= 0; i--) {
    counterBytes[i] = counter & 0xff;
    counter = Math.floor(counter / 256);
  }

  const digest = hmac(sha1, key, counterBytes);
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);

  const mod = binary % 10 ** digits;
  return String(mod).padStart(digits, '0');
}

// Accepts a raw base32 secret or a full otpauth:// URI pasted from Neptun.
export function extractTotpSecret(input: string): string | null {
  const trimmed = input.trim();
  if (!trimmed) return null;

  if (trimmed.toLowerCase().startsWith('otpauth://')) {
    try {
      const secret = new URL(trimmed).searchParams.get('secret');
      if (!secret) return null;
      return isValidSecret(secret) ? secret.replace(/[\s-]/g, '').toUpperCase() : null;
    } catch {
      return null;
    }
  }

  const cleaned = trimmed.replace(/[\s-]/g, '').toUpperCase();
  return isValidSecret(cleaned) ? cleaned : null;
}
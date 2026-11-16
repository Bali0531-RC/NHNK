// Low-level HTTP helpers shared by the Neptun client. Kept dependency-free so it runs
// unchanged in Expo Go.

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

// Neptun codes are ASCII, so a byte-for-byte base64 is enough and avoids depending on a
// global btoa that is not guaranteed on every engine.
export function base64Ascii(input: string): string {
  let out = '';
  for (let i = 0; i < input.length; i += 3) {
    const a = input.charCodeAt(i);
    const b = i + 1 < input.length ? input.charCodeAt(i + 1) : NaN;
    const c = i + 2 < input.length ? input.charCodeAt(i + 2) : NaN;
    const o1 = a >> 2;
    const o2 = ((a & 3) << 4) | (isNaN(b) ? 0 : b >> 4);
    const o3 = isNaN(b) ? 64 : ((b & 15) << 2) | (isNaN(c) ? 0 : c >> 6);
    const o4 = isNaN(c) ? 64 : c & 63;
    out += B64[o1] + B64[o2] + B64[o3] + B64[o4];
  }
  return out;
}

export async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  timeoutMs = 15000,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

export type SetCookies = { deviceCookie: string | null; sessionCookie: string | null; refreshToken: string | null };

// iOS NSURLSession usually hides Set-Cookie from fetch, so every field here is allowed to
// come back null. When it does, the native cookie store still replays the cookies to the
// same host, so the refresh path can survive without us ever seeing the values.
export function parseSetCookie(header: string | null): SetCookies {
  const empty: SetCookies = { deviceCookie: null, sessionCookie: null, refreshToken: null };
  if (!header) return empty;

  const device = header.match(/devicecookie-[a-zA-Z0-9+/=]+=([a-zA-Z0-9+/=]+)/);
  const session = header.match(/([^=;\s,]+)=(eyJ[a-zA-Z0-9\-_.]+)/);
  return {
    deviceCookie: device ? device[1] : null,
    sessionCookie: session ? session[0] : null,
    refreshToken: session ? session[2] : null,
  };
}

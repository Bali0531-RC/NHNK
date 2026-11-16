// Neptun auth client, ported from api_coms.dart (InstitutesRequest + _APIRequest).
// Modern API only for now: Account/Authenticate and Account/GetNewTokens. Legacy
// (.aspx / MobileService.svc) institutions are detected and reported, not yet driven.

import { base64Ascii, fetchWithTimeout, parseSetCookie } from './http';
import { Store } from './storage';
import { generateTotp } from './totp';
import type { Institute, LoginOutcome } from './types';

const LCID = 1038; // Hungarian. The web client sends this and Neptun echoes locale from it.

// Strips the bits of a stored institution URL that are not the API origin: a trailing
// slash, a /login(.aspx) page, a /MobileService.svc suffix. Returns whether the URL named
// a legacy (.aspx) endpoint, which routes to a different API.
export function normalizeInstituteUrl(rawUrl: string): { baseUrl: string; isAspx: boolean } {
  let url = rawUrl.trim();
  if (url.endsWith('/')) url = url.slice(0, -1);
  const isAspx = url.toLowerCase().includes('.aspx');
  const baseUrl = url
    .replace(/\/login(\.aspx)?$/i, '')
    .replace(/\/MobileService\.svc$/i, '');
  return { baseUrl, isAspx };
}

function deviceCookieHeader(username: string, value: string): string {
  return `devicecookie-${base64Ascii(username.toUpperCase())}=${value}`;
}

// Pulls Neptun's own explanation out of the `notification` envelope, which separates a
// locked account or an expired password from a plain wrong password.
function serverMessageFrom(decoded: unknown): string | null {
  if (typeof decoded !== 'object' || decoded === null) return null;
  const notifications = (decoded as Record<string, unknown>).notification;
  if (!Array.isArray(notifications) || notifications.length === 0) return null;

  const messages: string[] = [];
  for (const item of notifications) {
    if (typeof item === 'string' && item.trim()) {
      messages.push(item.trim());
    } else if (item && typeof item === 'object') {
      for (const key of ['message', 'Message', 'text', 'Text', 'description']) {
        const value = (item as Record<string, unknown>)[key];
        if (typeof value === 'string' && value.trim()) {
          messages.push(value.trim());
          break;
        }
      }
    }
  }
  return messages.length === 0 ? null : messages.join(' ');
}

// Best-effort cookie capture. On iOS these are usually invisible to fetch and the native
// store replays them for us, so a miss here is not a failure.
async function captureCookies(response: Response, username: string): Promise<void> {
  const parsed = parseSetCookie(response.headers.get('set-cookie'));
  if (parsed.deviceCookie) await Store.setDeviceCookie(username, parsed.deviceCookie);
  if (parsed.sessionCookie) await Store.setSessionCookie(parsed.sessionCookie);
}

async function postAuthenticate(
  baseUrl: string,
  username: string,
  password: string,
  token: string,
): Promise<Response> {
  const body = JSON.stringify({
    userName: username,
    password,
    captcha: '',
    captchaIdentifier: '',
    token,
    LCID,
  });

  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const savedCookie = await Store.getDeviceCookie(username);
  if (savedCookie) headers.Cookie = deviceCookieHeader(username, savedCookie);

  return fetchWithTimeout(`${baseUrl}/api/Account/Authenticate`, { method: 'POST', headers, body });
}

async function persistSuccess(baseUrl: string, username: string, password: string): Promise<void> {
  await Store.setInstituteUrl(baseUrl);
  await Store.setUsername(username);
  await Store.setPassword(password);
  await Store.setIsModernApi(true);
  await Store.setIsDemo(false);
}

async function authenticateModern(
  baseUrl: string,
  username: string,
  password: string,
): Promise<LoginOutcome> {
  try {
    const raw = await postAuthenticate(baseUrl, username, password, '');
    const json: any = await raw.json().catch(() => null);
    const message = serverMessageFrom(json);
    await captureCookies(raw, username);

    const data = json?.data;
    const is2fa = data != null && (data.isTwoFactorRequired === true || data.requiresTwoFactor === true);

    // A refused request must never open the code prompt: asking for codes against
    // credentials the server already rejected is what burns attempts and locks accounts.
    if (is2fa && raw.status < 400) {
      await Store.setInstituteUrl(baseUrl);

      const secret = await Store.getTotpSecret();
      if (secret) {
        const code = generateTotp(secret);
        if (code && (await submitTwoFactorCode(username, password, code))) {
          await persistSuccess(baseUrl, username, password);
          return { kind: 'ok' };
        }
      }
      return { kind: 'twoFactor' };
    }

    if (data?.accessToken) {
      await Store.setAccessToken(data.accessToken);
      await persistSuccess(baseUrl, username, password);
      return { kind: 'ok' };
    }

    return { kind: 'failed', message };
  } catch {
    // Never reached the server, or an unparseable answer. Not the same as wrong password.
    return { kind: 'network' };
  }
}

// Second leg of 2FA: the same Authenticate endpoint with the code in `token`.
export async function submitTwoFactorCode(
  username: string,
  password: string,
  code: string,
): Promise<boolean> {
  try {
    const baseUrl = await Store.getInstituteUrl();
    if (!baseUrl) return false;

    const raw = await postAuthenticate(baseUrl, username, password, code);
    const json: any = await raw.json().catch(() => null);
    await captureCookies(raw, username);

    if (json?.data?.accessToken) {
      await Store.setAccessToken(json.data.accessToken);
      await persistSuccess(baseUrl, username, password);
      return true;
    }
  } catch {
    // fall through to false
  }
  return false;
}

// Renews the access token without 2FA, using the access token plus the session cookie.
// Either one alone is rejected. New token sits at the root here, not under `data`.
export async function getNewTokens(): Promise<boolean> {
  try {
    const accessToken = await Store.getAccessToken();
    const sessionCookie = await Store.getSessionCookie();
    const baseUrl = await Store.getInstituteUrl();
    if (!accessToken || !baseUrl) return false;

    let cookieHeader = sessionCookie ?? '';
    const username = await Store.getUsername();
    if (username) {
      const deviceCookie = await Store.getDeviceCookie(username);
      if (deviceCookie) {
        const dc = deviceCookieHeader(username, deviceCookie);
        cookieHeader = cookieHeader ? `${cookieHeader}; ${dc}` : dc;
      }
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${accessToken}`,
    };
    if (cookieHeader) headers.Cookie = cookieHeader;

    const raw = await fetchWithTimeout(`${baseUrl}/api/Account/GetNewTokens`, {
      method: 'POST',
      headers,
      body: '{}',
    });
    if (raw.status !== 200) return false;

    const json: any = await raw.json().catch(() => null);
    const newToken = json?.accessToken ?? json?.data?.accessToken;
    if (newToken) {
      await Store.setAccessToken(newToken);
      if (username) await captureCookies(raw, username);
      return true;
    }
  } catch {
    // fall through to false
  }
  return false;
}

// Entry point used by the login screen. Handles the DEMO account, records the failover
// pool, normalizes the URL and routes modern vs legacy.
export async function login(
  institute: Institute,
  username: string,
  password: string,
): Promise<LoginOutcome> {
  if (username === 'DEMO' && password === 'DEMO') {
    await Store.setIsDemo(true);
    await Store.setUsername('DEMO');
    return { kind: 'ok' };
  }

  await Store.setFallbacks(institute.fallbacks.length === 0 ? [] : [institute.url, ...institute.fallbacks]);

  const { baseUrl, isAspx } = normalizeInstituteUrl(institute.url);
  if (isAspx) {
    // Legacy MobileService.svc login is not ported yet. Reported plainly so a student at
    // one of these schools is not left staring at a generic failure.
    return { kind: 'failed', message: 'This institution still uses the legacy Neptun API, which is not supported yet.' };
  }

  return authenticateModern(baseUrl, username, password);
}

// Last-resort re-login with the stored password, used only after a token refresh has
// already failed. One attempt; the caller (renewSession) must never loop on the result,
// since each failure is a password attempt Neptun counts toward a lockout.
export async function reauthenticate(): Promise<boolean> {
  const username = await Store.getUsername();
  const password = await Store.getPassword();
  const baseUrl = await Store.getInstituteUrl();
  if (!username || !password || !baseUrl) return false;
  const outcome = await authenticateModern(baseUrl, username, password);
  return outcome.kind === 'ok';
}

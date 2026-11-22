// neptun auth, ported from api_coms.dart. legacy .aspx schools just get told no for now

import { base64Ascii, fetchWithTimeout, parseSetCookie } from './http';
import { log } from './log';
import { Store } from './storage';
import { neptunLcid } from './lang';
import { generateTotp } from './totp';
import type { Institute, LoginOutcome } from './types';


// cleans an institution url down to the api origin and flags legacy endpoints
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

// neptuns own reason, so a locked account isnt shown as a wrong password
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

// best effort, ios mostly hides cookies from fetch anyway
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
    LCID: await neptunLcid(),
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

    // never ask for a code after a rejected password, thats how accounts get locked
    if (is2fa && raw.status < 400) {
      log.info('login', 'server requires 2FA');
      await Store.setInstituteUrl(baseUrl);

      const secret = await Store.getTotpSecret();
      if (secret) {
        const code = generateTotp(secret);
        if (code && (await submitTwoFactorCode(username, password, code)).ok) {
          log.info('login', 'auto-2FA (stored TOTP) accepted');
          await persistSuccess(baseUrl, username, password);
          return { kind: 'ok' };
        }
        log.warn('login', 'auto-2FA with stored TOTP did not pass; asking for a code');
      }
      return { kind: 'twoFactor' };
    }

    if (data?.accessToken) {
      log.info('login', 'authenticated (modern, no 2FA)');
      await Store.setAccessToken(data.accessToken);
      await persistSuccess(baseUrl, username, password);
      return { kind: 'ok' };
    }

    log.warn('login', message ? `rejected: ${message}` : `rejected (HTTP ${raw.status}, no accessToken)`);
    return { kind: 'failed', message };
  } catch (err) {
    // Never reached the server, or an unparseable answer. Not the same as wrong password.
    log.error('login', 'network or parse failure during Authenticate', err);
    return { kind: 'network' };
  }
}

// Second leg of 2FA: the same Authenticate endpoint with the code in `token`.
export type TwoFactorResult = { ok: true } | { ok: false; reason: 'rejected' | 'network' | 'server'; message: string | null };

// neptun's own (localized) rejection text goes back to the screen, never into the log
export async function submitTwoFactorCode(username: string, password: string, code: string): Promise<TwoFactorResult> {
  const baseUrl = await Store.getInstituteUrl();
  if (!baseUrl) return { ok: false, reason: 'rejected', message: null };
  let raw: Response;
  try {
    raw = await postAuthenticate(baseUrl, username, password, code);
  } catch (err) {
    log.error('login', '2FA submit failed', err);
    return { ok: false, reason: 'network', message: null };
  }
  try {
    const json: any = await raw.json().catch(() => null);
    await captureCookies(raw, username);
    if (json?.data?.accessToken) {
      log.info('login', '2FA code accepted');
      await Store.setAccessToken(json.data.accessToken);
      await persistSuccess(baseUrl, username, password);
      return { ok: true };
    }
    log.warn('login', `2FA code rejected (${raw.status})`);
    if (raw.status >= 500) return { ok: false, reason: 'server', message: null };
    const msg = [json?.message, json?.errorMessage, json?.data?.message].find((m) => typeof m === 'string' && m.trim());
    return { ok: false, reason: 'rejected', message: msg ? String(msg).trim() : null };
  } catch (err) {
    log.error('login', '2FA answer unreadable', err);
    return { ok: false, reason: 'server', message: null };
  }
}

// renew without 2fa. needs token AND session cookie, either alone gets rejected
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
    if (raw.status !== 200) {
      log.warn('auth', `GetNewTokens HTTP ${raw.status}`);
      return false;
    }

    const json: any = await raw.json().catch(() => null);
    const newToken = json?.accessToken ?? json?.data?.accessToken;
    if (newToken) {
      await Store.setAccessToken(newToken);
      if (username) await captureCookies(raw, username);
      return true;
    }
    log.warn('auth', 'GetNewTokens: no token in response');
  } catch (err) {
    log.warn('auth', 'GetNewTokens request failed', err);
  }
  return false;
}

// login entry: demo, failover pool, url cleanup, modern vs legacy
export async function login(
  institute: Institute,
  username: string,
  password: string,
): Promise<LoginOutcome> {
  if (username === 'DEMO' && password === 'DEMO') {
    log.info('login', 'demo account');
    await Store.setIsDemo(true);
    await Store.setUsername('DEMO');
    return { kind: 'ok' };
  }

  await Store.setFallbacks(institute.fallbacks.length === 0 ? [] : [institute.url, ...institute.fallbacks]);

  const { baseUrl, isAspx } = normalizeInstituteUrl(institute.url);
  if (isAspx) {
    // legacy login not ported, at least say so instead of a generic error
    log.warn('login', 'legacy (.aspx / MobileService.svc) institution, not supported yet');
    return { kind: 'failed', message: null, legacy: true };
  }

  log.info('login', 'authenticating against modern /api');
  return authenticateModern(baseUrl, username, password);
}

// one shot password re-login after renewal failed. NEVER loop this, neptun counts every miss
export async function reauthenticate(): Promise<LoginOutcome['kind'] | 'noPassword'> {
  const username = await Store.getUsername();
  const password = await Store.getPassword();
  const baseUrl = await Store.getInstituteUrl();
  if (!username || !password || !baseUrl) return 'noPassword';
  const outcome = await authenticateModern(baseUrl, username, password);
  return outcome.kind;
}
// authed reads: renew, then one stored password try, never retry a rejected password

import { getNewTokens, reauthenticate } from './api';
import { fetchWithTimeout, parseSetCookie } from './http';
import { neptunLcid } from './lang';
import { log } from './log';
import { Store } from './storage';

const MAX_AUTH_FAILURES = 2;
// Refresh this long before the token's own expiry.
const REFRESH_AHEAD_MS = 3 * 60_000;

// offline = no connection, down = neptun is dead again
export type NeptunErrorKind = 'offline' | 'down' | 'auth' | 'server' | 'unsupported';

export class NeptunError extends Error {
  kind: NeptunErrorKind;
  constructor(kind: NeptunErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

// Why the last session ended, so the login screen can explain it.
export type ExpiryReason = 'twoFactor' | 'password' | 'expired';

let renewInFlight: Promise<boolean> | null = null;
let consecutiveAuthFailures = 0;
let generation = 0;
let onSessionExpired: ((reason: ExpiryReason) => void) | null = null;
let lastFailure: ExpiryReason = 'expired';
let deviceOnline = true;
let lastDown = 0;
const downListeners = new Set<(down: boolean) => void>();

export function setDeviceOnline(online: boolean): void {
  deviceOnline = online;
}

// True for a minute after Neptun last failed to answer while the phone was online.
export function neptunDown(): boolean {
  return Date.now() - lastDown < 60_000;
}

export function subscribeNeptunDown(fn: (down: boolean) => void): () => void {
  downListeners.add(fn);
  return () => downListeners.delete(fn);
}

function markDown(down: boolean): void {
  const was = neptunDown();
  lastDown = down ? Date.now() : 0;
  if (was !== down) downListeners.forEach((fn) => fn(down));
}

export function sessionGeneration(): number {
  return generation;
}

export function bumpSessionGeneration(): void {
  generation += 1;
}

export function setOnSessionExpired(cb: ((reason: ExpiryReason) => void) | null): void {
  onSessionExpired = cb;
}

export function resetAuthFailures(): void {
  consecutiveAuthFailures = 0;
}

function b64urlDecode(input: string): string {
  const b64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  let out = '';
  let buffer = 0;
  let bits = 0;
  for (const ch of b64) {
    const v = chars.indexOf(ch);
    if (v < 0) continue;
    buffer = (buffer << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out += String.fromCharCode((buffer >> bits) & 0xff);
    }
  }
  return out;
}

// Expiry of a JWT access token in ms, or null when it is not a readable JWT.
export function tokenExpiry(token: string): number | null {
  const part = token.split('.')[1];
  if (!part) return null;
  try {
    const payload = JSON.parse(b64urlDecode(part)) as { exp?: number };
    return typeof payload.exp === 'number' ? payload.exp * 1000 : null;
  } catch {
    return null;
  }
}

async function renewSession(allowPassword: boolean): Promise<boolean> {
  if (renewInFlight) return renewInFlight;
  if (consecutiveAuthFailures >= MAX_AUTH_FAILURES) return false;

  renewInFlight = (async () => {
    try {
      if (await getNewTokens()) {
        consecutiveAuthFailures = 0;
        bumpSessionGeneration();
        log.info('auth', 'renewed via GetNewTokens');
        return true;
      }
      if (!allowPassword) return false;
      log.info('auth', 'GetNewTokens refused; trying one stored-password re-login');
      const outcome = await reauthenticate();
      if (outcome === 'ok') {
        consecutiveAuthFailures = 0;
        bumpSessionGeneration();
        log.info('auth', 'renewed via stored-password re-login');
        return true;
      }
      lastFailure = outcome === 'twoFactor' ? 'twoFactor' : outcome === 'failed' ? 'password' : 'expired';
      consecutiveAuthFailures += 1;
      log.warn('auth', `renewal failed (${outcome}, ${consecutiveAuthFailures}/${MAX_AUTH_FAILURES})`);
      return false;
    } finally {
      renewInFlight = null;
    }
  })();
  return renewInFlight;
}

// keeps the token fresh while GetNewTokens still accepts it
export async function keepSessionFresh(): Promise<void> {
  const token = await Store.getAccessToken();
  if (!token) return;
  const exp = tokenExpiry(token);
  if (exp === null || exp - Date.now() > REFRESH_AHEAD_MS) return;
  if (exp < Date.now()) return; // already dead; the 401 path handles it
  log.info('auth', 'token close to expiry, refreshing ahead of time');
  await renewSession(false);
}

function shortPath(path: string): string {
  const q = path.indexOf('?');
  return q === -1 ? path : path.slice(0, q);
}

// neptun hides 401s inside 200s. only the top level counts, so a message quoting it cant log anyone out
function isAuthFailure(status: number, text: string): boolean {
  if (status === 401) return true;
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return false;
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) return false;
  const top = body as Record<string, unknown>;
  const code = Number(top.statusCode ?? top.StatusCode);
  if (code === 401 || code === 410) return true;
  const msg = top.Message ?? top.message;
  return typeof msg === 'string' && msg.startsWith('Authorization has been denied');
}

async function send(method: 'GET' | 'POST' | 'DELETE', path: string, body?: unknown): Promise<{ status: number; text: string }> {
  const token = await Store.getAccessToken();
  const baseUrl = await Store.getInstituteUrl();
  if (!token || !baseUrl) throw new NeptunError('auth', 'no session');
  let res: Response;
  try {
    res = await fetchWithTimeout(`${baseUrl}/api/${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (err) {
    log.warn('api', `${method} ${shortPath(path)} network failure`, err);
    if (deviceOnline) {
      markDown(true);
      throw new NeptunError('down', 'no answer');
    }
    throw new NeptunError('offline', 'network');
  }
  if (res.status >= 500) markDown(true);
  else markDown(false);
  const rotated = parseSetCookie(res.headers.get('set-cookie')).sessionCookie;
  if (rotated) await Store.setSessionCookie(rotated);
  return { status: res.status, text: await res.text() };
}

// SetLanguage once per launch and per language switch, before any read. 404 = old build, just move on
let appliedLcid: number | null = null;
let langInFlight: Promise<void> | null = null;

async function ensureLanguage(): Promise<void> {
  const lcid = await neptunLcid();
  if (appliedLcid === lcid) return;
  if (langInFlight) return langInFlight;
  langInFlight = (async () => {
    try {
      const res = await send('POST', 'SetLanguage', { lcid });
      if (!isAuthFailure(res.status, res.text)) appliedLcid = lcid;
      log.info('api', `SetLanguage ${lcid} -> ${res.status}`);
    } catch (err) {
      log.warn('api', 'SetLanguage failed', err);
    } finally {
      langInFlight = null;
    }
  })();
  return langInFlight;
}

async function request<T>(method: 'GET' | 'POST' | 'DELETE', path: string, body?: unknown): Promise<T> {
  if (!(await Store.getIsModernApi())) throw new NeptunError('unsupported', 'legacy API');
  await keepSessionFresh();
  await ensureLanguage();

  log.info('api', `${method} ${shortPath(path)}`);
  let res = await send(method, path, body);

  if (isAuthFailure(res.status, res.text)) {
    log.info('api', `auth failure (${res.status}) on ${shortPath(path)}; renewing`);
    const renewed = await renewSession(true);
    if (!renewed) {
      onSessionExpired?.(lastFailure);
      throw new NeptunError('auth', 'session expired');
    }
    res = await send(method, path, body);
    if (isAuthFailure(res.status, res.text)) {
      // The session was just renewed, so it is alive; this endpoint simply refuses us.
      log.warn('api', `still unauthorised after renewal on ${shortPath(path)}`);
      throw new NeptunError('unsupported', 'endpoint refused');
    }
  }

  if (res.status === 403) throw new NeptunError('unsupported', `403 on ${shortPath(path)}`);
  if (res.status === 404) throw new NeptunError('unsupported', `404 on ${shortPath(path)}`);
  if (res.status >= 500) throw new NeptunError('down', `HTTP ${res.status}`);
  if (res.status >= 400) {
    log.warn('api', `HTTP ${res.status} on ${shortPath(path)}`);
    throw new NeptunError('server', `HTTP ${res.status}`);
  }

  let decoded: unknown;
  try {
    decoded = res.text ? JSON.parse(res.text) : null;
  } catch {
    log.warn('api', `non-JSON answer on ${shortPath(path)}`);
    throw new NeptunError('server', 'non-JSON');
  }
  consecutiveAuthFailures = 0;
  const envelope = decoded as { data?: unknown } | null;
  return (envelope && typeof envelope === 'object' && 'data' in envelope ? envelope.data : decoded) as T;
}

export function apiGet<T>(path: string): Promise<T> {
  return request<T>('GET', path);
}

export function apiPost<T>(path: string, body: unknown): Promise<T> {
  return request<T>('POST', path, body);
}

export function apiDelete<T>(path: string): Promise<T> {
  return request<T>('DELETE', path);
}
// Authenticated reads against the modern Neptun API, with the session-renewal safety that
// keeps the app from ever hammering the login.
//
// The lockout risk is real: Neptun suspends an account after enough FAILED PASSWORD
// attempts. So the rules here are strict and deliberate:
//   1. A 401 renews the session, it does not re-ask the user.
//   2. Renewal prefers GetNewTokens, which uses the access token, not the password.
//   3. Only if that fails does it try ONE password re-login from the Keychain.
//   4. Renewal is single-flight: a burst of 401s shares one attempt, never many.
//   5. After MAX_AUTH_FAILURES it stops and forces a manual login, so a stale stored
//      password cannot stack up attempts.
// There is no code path here that retries a rejected password, by construction.

import { getNewTokens, reauthenticate } from './api';
import { fetchWithTimeout } from './http';
import { Store } from './storage';

const MAX_AUTH_FAILURES = 2;

let renewInFlight: Promise<boolean> | null = null;
let consecutiveAuthFailures = 0;
const unsupported = new Set<string>();

let onSessionExpired: (() => void) | null = null;

// The provider registers a forced sign-out here. Fired only when the session is genuinely
// dead (refresh and the one stored-password re-login both failed), never on a normal miss.
export function setOnSessionExpired(cb: (() => void) | null): void {
  onSessionExpired = cb;
}

export function resetAuthFailures(): void {
  consecutiveAuthFailures = 0;
}

async function renewSession(): Promise<boolean> {
  if (renewInFlight) return renewInFlight;
  if (consecutiveAuthFailures >= MAX_AUTH_FAILURES) return false;

  renewInFlight = (async () => {
    try {
      if (await getNewTokens()) {
        consecutiveAuthFailures = 0;
        return true;
      }
      if (await reauthenticate()) {
        consecutiveAuthFailures = 0;
        return true;
      }
      consecutiveAuthFailures += 1;
      return false;
    } finally {
      renewInFlight = null;
    }
  })();
  return renewInFlight;
}

async function get(path: string, token: string): Promise<Response> {
  const baseUrl = await Store.getInstituteUrl();
  return fetchWithTimeout(`${baseUrl}/api/${path}`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  });
}

// Returns the `data` object for a modern endpoint, or null. Null is the catch-all for demo
// mode, legacy API, no session, a transient failure, and an institution whose Neptun build
// predates the route, so every caller treats a miss as "keep the fallback".
export async function fetchModernData<T = unknown>(path: string): Promise<T | null> {
  if (await Store.getIsDemo()) return null;
  if (!(await Store.getIsModernApi())) return null;
  if (unsupported.has(path)) return null;

  const token = await Store.getAccessToken();
  const baseUrl = await Store.getInstituteUrl();
  if (!token || !baseUrl) {
    onSessionExpired?.();
    return null;
  }

  try {
    let res = await get(path, token);

    if (res.status === 401 || res.status === 403) {
      const renewed = await renewSession();
      if (!renewed) {
        onSessionExpired?.();
        return null;
      }
      const fresh = (await Store.getAccessToken()) ?? token;
      res = await get(path, fresh);
      if (res.status === 401 || res.status === 403) {
        onSessionExpired?.();
        return null;
      }
    }

    const text = await res.text();
    // Transport-level error envelope. Says nothing about whether the route exists, so it is
    // not remembered as a miss.
    if (text.includes('"ErrorMessage"')) return null;

    const decoded = JSON.parse(text);
    if (decoded && typeof decoded === 'object' && decoded.data != null) {
      consecutiveAuthFailures = 0;
      return decoded.data as T;
    }

    // A 200 with no data object, or an HTML page: this build does not serve the route.
    unsupported.add(path);
    return null;
  } catch {
    return null;
  }
}

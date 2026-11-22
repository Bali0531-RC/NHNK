// all auth stuff in the keychain, stored password + totp let us re-login silently

import * as SecureStore from 'expo-secure-store';

const K = {
  instituteUrl: 'nhnk.instituteUrl',
  username: 'nhnk.username',
  password: 'nhnk.password',
  accessToken: 'nhnk.accessToken',
  sessionCookie: 'nhnk.sessionCookie',
  totpSecret: 'nhnk.totpSecret',
  isModernApi: 'nhnk.isModernApi',
  isDemo: 'nhnk.isDemo',
  fallbacks: 'nhnk.fallbacks',
} as const;

// securestore keys are picky, strip the odd char
function deviceCookieKey(username: string): string {
  return 'nhnk.deviceCookie.' + username.toUpperCase().replace(/[^A-Za-z0-9]/g, '_');
}

async function get(key: string): Promise<string | null> {
  try {
    return await SecureStore.getItemAsync(key);
  } catch {
    return null;
  }
}

async function set(key: string, value: string | null): Promise<void> {
  try {
    if (value == null) await SecureStore.deleteItemAsync(key);
    else await SecureStore.setItemAsync(key, value);
  } catch {
    // failed keychain write shouldnt crash anything, caller just logs in again
  }
}

export const Store = {
  getInstituteUrl: () => get(K.instituteUrl),
  setInstituteUrl: (v: string | null) => set(K.instituteUrl, v),

  getUsername: () => get(K.username),
  setUsername: (v: string | null) => set(K.username, v),

  getPassword: () => get(K.password),
  setPassword: (v: string | null) => set(K.password, v),

  getAccessToken: () => get(K.accessToken),
  setAccessToken: (v: string | null) => set(K.accessToken, v),

  getSessionCookie: () => get(K.sessionCookie),
  setSessionCookie: (v: string | null) => set(K.sessionCookie, v),

  getTotpSecret: () => get(K.totpSecret),
  setTotpSecret: (v: string | null) => set(K.totpSecret, v),

  getDeviceCookie: (username: string) => get(deviceCookieKey(username)),
  setDeviceCookie: (username: string, v: string | null) => set(deviceCookieKey(username), v),

  async getIsModernApi(): Promise<boolean> {
    return (await get(K.isModernApi)) === '1';
  },
  setIsModernApi: (v: boolean) => set(K.isModernApi, v ? '1' : '0'),

  async getIsDemo(): Promise<boolean> {
    return (await get(K.isDemo)) === '1';
  },
  setIsDemo: (v: boolean) => set(K.isDemo, v ? '1' : '0'),

  async getFallbacks(): Promise<string[]> {
    const raw = await get(K.fallbacks);
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.filter((e) => typeof e === 'string') : [];
    } catch {
      return [];
    }
  },
  setFallbacks: (v: string[]) => set(K.fallbacks, JSON.stringify(v)),

  // Wipes everything on sign-out. Device cookie is keyed by username, so clear it first.
  async clear(): Promise<void> {
    const username = await get(K.username);
    const keys: string[] = Object.values(K);
    if (username) keys.push(deviceCookieKey(username));
    await Promise.all(keys.map((k) => set(k, null)));
  },
};
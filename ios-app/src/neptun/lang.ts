import * as SecureStore from 'expo-secure-store';

import type { Lang } from '@/i18n/strings';

// neptun localizes its own data (periods, requests, field values) by LCID, same as the web client
const LCID: Record<Lang, number> = { hu: 1038, en: 1033, de: 1031 };
const KEY = 'nhnk.pref.lang';

let current: Lang | null = null;
const listeners = new Set<(lang: Lang) => void>();

const valid = (v: unknown): v is Lang => v === 'hu' || v === 'en' || v === 'de';

// background launches never mounted the i18n provider, so read the saved pick ourselves
export async function neptunLang(): Promise<Lang> {
  if (current) return current;
  const saved = await SecureStore.getItemAsync(KEY).catch(() => null);
  current = valid(saved) ? saved : 'hu';
  return current;
}

export function neptunLangSync(): Lang {
  return current ?? 'hu';
}

export async function neptunLcid(): Promise<number> {
  return LCID[await neptunLang()];
}

export function setNeptunLang(lang: Lang): void {
  const changed = current !== null && current !== lang;
  current = lang;
  if (changed) listeners.forEach((fn) => fn(lang));
}

export function subscribeNeptunLang(fn: (lang: Lang) => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
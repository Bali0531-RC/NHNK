import * as SecureStore from 'expo-secure-store';
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { setNeptunLang } from '@/neptun/lang';
import { KEYCHAIN } from '@/neptun/storage';

import { appStrings, type AppStrings } from './app-strings';
import { strings, type Lang, type Strings } from './strings';
import { v2Strings, type V2Strings } from './v2-strings';

const KEY_LANG = 'nhnk.pref.lang';
const ORDER: Lang[] = ['hu', 'en', 'de'];

type I18nValue = {
  lang: Lang;
  t: Strings;
  tx: AppStrings & { v2: V2Strings };
  setLang: (lang: Lang) => void;
  toggle: () => void;
};

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  // Default Hungarian; a persisted choice (login / onboarding / settings) loads over it.
  const [lang, setLangState] = useState<Lang>('hu');

  useEffect(() => {
    let active = true;
    SecureStore.getItemAsync(KEY_LANG)
      .then((v) => {
        if (active && (v === 'hu' || v === 'en' || v === 'de')) {
          setNeptunLang(v);
          setLangState(v);
        }
      })
      .catch(() => {});
    return () => {
      active = false;
    };
  }, []);

  const setLang = useCallback((l: Lang) => {
    setNeptunLang(l);
    setLangState(l);
    SecureStore.setItemAsync(KEY_LANG, l, KEYCHAIN).catch(() => {});
  }, []);

  const toggle = useCallback(() => {
    setLangState((l) => {
      const next = ORDER[(ORDER.indexOf(l) + 1) % ORDER.length];
      queueMicrotask(() => setNeptunLang(next));
      SecureStore.setItemAsync(KEY_LANG, next, KEYCHAIN).catch(() => {});
      return next;
    });
  }, []);

  const value = useMemo<I18nValue>(
    () => ({ lang, t: strings[lang], tx: { ...appStrings[lang], v2: v2Strings[lang] }, setLang, toggle }),
    [lang, setLang, toggle],
  );

  return <I18nContext value={value}>{children}</I18nContext>;
}

export function useI18n(): I18nValue {
  const ctx = use(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside I18nProvider');
  return ctx;
}
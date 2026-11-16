import { createContext, use, useCallback, useMemo, useState, type ReactNode } from 'react';

import { strings, type Lang, type Strings } from './strings';

type I18nValue = {
  lang: Lang;
  t: Strings;
  setLang: (lang: Lang) => void;
  toggle: () => void;
};

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  // Default Hungarian. A device-locale default and a persisted override land once
  // expo-localization and SecureStore are wired for the real build.
  const [lang, setLang] = useState<Lang>('hu');

  const toggle = useCallback(() => setLang((l) => (l === 'hu' ? 'en' : 'hu')), []);

  const value = useMemo<I18nValue>(
    () => ({ lang, t: strings[lang], setLang, toggle }),
    [lang, toggle],
  );

  return <I18nContext value={value}>{children}</I18nContext>;
}

export function useI18n(): I18nValue {
  const ctx = use(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside I18nProvider');
  return ctx;
}

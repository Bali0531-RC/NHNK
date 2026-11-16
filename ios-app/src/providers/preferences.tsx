// UI preferences that are not secret and must outlive sign-out: the theme override and
// whether haptics fire. Kept in their own SecureStore keys so the auth Store.clear() on
// logout leaves them alone. Defaults match the old behaviour: follow the system, haptics on.

import * as SecureStore from 'expo-secure-store';
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { useColorScheme } from 'react-native';

export type ThemeMode = 'system' | 'light' | 'dark';

const KEY_THEME = 'nhnk.pref.themeMode';
const KEY_HAPTICS = 'nhnk.pref.haptics';

type PreferencesValue = {
  themeMode: ThemeMode;
  haptics: boolean;
  resolvedScheme: 'light' | 'dark';
  setThemeMode: (mode: ThemeMode) => void;
  setHaptics: (on: boolean) => void;
};

const PreferencesContext = createContext<PreferencesValue | null>(null);

async function readPref(key: string): Promise<string | null> {
  try {
    return await SecureStore.getItemAsync(key);
  } catch {
    return null;
  }
}

async function writePref(key: string, value: string): Promise<void> {
  try {
    await SecureStore.setItemAsync(key, value);
  } catch {
    // A failed write just means the choice does not survive a restart; not worth crashing.
  }
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const system = useColorScheme();
  const [themeMode, setThemeModeState] = useState<ThemeMode>('system');
  const [haptics, setHapticsState] = useState(true);

  useEffect(() => {
    let active = true;
    (async () => {
      const [tm, hp] = await Promise.all([readPref(KEY_THEME), readPref(KEY_HAPTICS)]);
      if (!active) return;
      if (tm === 'system' || tm === 'light' || tm === 'dark') setThemeModeState(tm);
      if (hp != null) setHapticsState(hp === '1');
    })();
    return () => {
      active = false;
    };
  }, []);

  const setThemeMode = useCallback((mode: ThemeMode) => {
    setThemeModeState(mode);
    void writePref(KEY_THEME, mode);
  }, []);

  const setHaptics = useCallback((on: boolean) => {
    setHapticsState(on);
    void writePref(KEY_HAPTICS, on ? '1' : '0');
  }, []);

  const resolvedScheme: 'light' | 'dark' =
    themeMode === 'system' ? (system === 'dark' ? 'dark' : 'light') : themeMode;

  const value = useMemo<PreferencesValue>(
    () => ({ themeMode, haptics, resolvedScheme, setThemeMode, setHaptics }),
    [themeMode, haptics, resolvedScheme, setThemeMode, setHaptics],
  );

  return <PreferencesContext value={value}>{children}</PreferencesContext>;
}

export function usePreferences(): PreferencesValue {
  const ctx = use(PreferencesContext);
  if (!ctx) throw new Error('usePreferences must be used inside PreferencesProvider');
  return ctx;
}

export function useResolvedScheme(): 'light' | 'dark' {
  return usePreferences().resolvedScheme;
}

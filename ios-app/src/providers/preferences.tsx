// non secret ui prefs, own key so logout leaves them alone

import * as SecureStore from 'expo-secure-store';
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { useColorScheme } from 'react-native';

import type { ThemeStyle } from '@/constants/theme';
import { KEYCHAIN } from '@/neptun/storage';

export type ThemeMode = 'system' | 'light' | 'dark';

export type Prefs = {
  themeMode: ThemeMode;
  themeStyle: ThemeStyle;
  haptics: boolean;
  biometricLock: boolean;
  onboardingSeen: boolean;
  notifyMessages: boolean;
  notifyClasses: boolean;
  classLeadMinutes: number;
  notifyExams: boolean;
  notifyPayments: boolean;
  notifyPeriods: boolean;
  backgroundSync: boolean;
  showOfficeHours: boolean;
  showPeriodsInCalendar: boolean;
  weekShift: number;
  smartPaymentColors: boolean;
};

const DEFAULTS: Prefs = {
  themeMode: 'system',
  themeStyle: 'native',
  haptics: true,
  biometricLock: false,
  onboardingSeen: false,
  notifyMessages: true,
  notifyClasses: true,
  classLeadMinutes: 10,
  notifyExams: true,
  notifyPayments: true,
  notifyPeriods: true,
  backgroundSync: true,
  showOfficeHours: true,
  showPeriodsInCalendar: true,
  weekShift: 0,
  smartPaymentColors: true,
};

const KEY = 'nhnk.prefs.v2';
// Pre-2.0 single keys, read once so an update keeps the user's choices.
const LEGACY = {
  themeMode: 'nhnk.pref.themeMode',
  haptics: 'nhnk.pref.haptics',
  biometricLock: 'nhnk.pref.biometricLock',
  onboardingSeen: 'nhnk.pref.onboardingSeen',
};

type PreferencesValue = Prefs & {
  loaded: boolean;
  resolvedScheme: 'light' | 'dark';
  set: <K extends keyof Prefs>(key: K, value: Prefs[K]) => void;
  setThemeMode: (mode: ThemeMode) => void;
  setHaptics: (on: boolean) => void;
  setBiometricLock: (on: boolean) => void;
  setOnboardingSeen: (on: boolean) => void;
};

const PreferencesContext = createContext<PreferencesValue | null>(null);

let snapshot: Prefs = DEFAULTS;

// For non-React code (background task, notification scheduler).
export function currentPrefs(): Prefs {
  return snapshot;
}

export async function loadPrefs(): Promise<Prefs> {
  try {
    const raw = await SecureStore.getItemAsync(KEY);
    if (raw) {
      snapshot = { ...DEFAULTS, ...(JSON.parse(raw) as Partial<Prefs>) };
      return snapshot;
    }
    const [tm, hp, bio, ob] = await Promise.all([
      SecureStore.getItemAsync(LEGACY.themeMode),
      SecureStore.getItemAsync(LEGACY.haptics),
      SecureStore.getItemAsync(LEGACY.biometricLock),
      SecureStore.getItemAsync(LEGACY.onboardingSeen),
    ]);
    const migrated: Prefs = { ...DEFAULTS };
    if (tm === 'system' || tm === 'light' || tm === 'dark') migrated.themeMode = tm;
    if (hp != null) migrated.haptics = hp === '1';
    if (bio != null) migrated.biometricLock = bio === '1';
    if (ob != null) migrated.onboardingSeen = ob === '1';
    snapshot = migrated;
  } catch {
    snapshot = DEFAULTS;
  }
  return snapshot;
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const system = useColorScheme();
  const [loaded, setLoaded] = useState(false);
  const [prefs, setPrefs] = useState<Prefs>(DEFAULTS);

  useEffect(() => {
    let active = true;
    void loadPrefs().then((p) => {
      if (!active) return;
      setPrefs(p);
      setLoaded(true);
    });
    return () => {
      active = false;
    };
  }, []);

  const set = useCallback(<K extends keyof Prefs>(key: K, value: Prefs[K]) => {
    setPrefs((p) => {
      const next = { ...p, [key]: value };
      snapshot = next;
      SecureStore.setItemAsync(KEY, JSON.stringify(next), KEYCHAIN).catch(() => {});
      return next;
    });
  }, []);

  const resolvedScheme: 'light' | 'dark' =
    prefs.themeMode === 'system' ? (system === 'dark' ? 'dark' : 'light') : prefs.themeMode;

  const value = useMemo<PreferencesValue>(
    () => ({
      ...prefs,
      loaded,
      resolvedScheme,
      set,
      setThemeMode: (m) => set('themeMode', m),
      setHaptics: (on) => set('haptics', on),
      setBiometricLock: (on) => set('biometricLock', on),
      setOnboardingSeen: (on) => set('onboardingSeen', on),
    }),
    [prefs, loaded, resolvedScheme, set],
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
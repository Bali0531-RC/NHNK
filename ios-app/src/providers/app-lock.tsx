import * as LocalAuthentication from 'expo-local-authentication';
import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { AppState } from 'react-native';

import { useI18n } from '@/i18n';
import { usePreferences } from '@/providers/preferences';

type AppLockValue = {
  locked: boolean;
  unlocking: boolean;
  unlock: () => Promise<boolean>;
  grant: () => void;
};

const AppLockContext = createContext<AppLockValue | null>(null);

const RELOCK_AFTER_MS = 15 * 60_000;

// only true with a real biometric enrolled so nobody locks themselves out
export async function biometricsAvailable(): Promise<boolean> {
  try {
    const [hw, enrolled] = await Promise.all([
      LocalAuthentication.hasHardwareAsync(),
      LocalAuthentication.isEnrolledAsync(),
    ]);
    return hw && enrolled;
  } catch {
    return false;
  }
}

export type BiometricCheck = 'ok' | 'denied' | 'unavailable' | 'cancel';

// one real face id round before turning the lock on. first call is what fires the ios permission prompt
export async function checkBiometric(prompt: string, cancelLabel: string): Promise<BiometricCheck> {
  if (!(await biometricsAvailable())) return 'unavailable';
  try {
    const res = await LocalAuthentication.authenticateAsync({ promptMessage: prompt, cancelLabel, disableDeviceFallback: false });
    if (res.success) return 'ok';
    if (res.error === 'not_available' || res.error === 'not_enrolled' || res.error === 'passcode_not_set') return 'denied';
    return 'cancel';
  } catch {
    return 'unavailable';
  }
}

export function AppLockProvider({ children }: { children: ReactNode }) {
  const { biometricLock } = usePreferences();
  const { t } = useI18n();
  const [unlocked, setUnlocked] = useState(false);
  const [unlocking, setUnlocking] = useState(false);

  // face id once per launch, only a long background stay relocks
  useEffect(() => {
    let backgroundAt = 0;
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'background') backgroundAt = Date.now();
      else if (state === 'active' && backgroundAt && Date.now() - backgroundAt > RELOCK_AFTER_MS) setUnlocked(false);
      if (state === 'active') backgroundAt = 0;
    });
    return () => sub.remove();
  }, []);

  const unlock = useCallback(async (): Promise<boolean> => {
    setUnlocking(true);
    try {
      const res = await LocalAuthentication.authenticateAsync({
        promptMessage: t.lock.prompt,
        cancelLabel: t.common.cancel,
        fallbackLabel: t.lock.fallback,
        disableDeviceFallback: false,
      });
      if (res.success) {
        setUnlocked(true);
        return true;
      }
      return false;
    } catch {
      return false;
    } finally {
      setUnlocking(false);
    }
  }, [t]);

  const locked = biometricLock && !unlocked;
  // face id was just passed while turning the lock on, dont make them do it twice
  const grant = useCallback(() => setUnlocked(true), []);

  const value = useMemo<AppLockValue>(() => ({ locked, unlocking, unlock, grant }), [locked, unlocking, unlock, grant]);
  return <AppLockContext value={value}>{children}</AppLockContext>;
}

export function useAppLock(): AppLockValue {
  const ctx = use(AppLockContext);
  if (!ctx) throw new Error('useAppLock must be used inside AppLockProvider');
  return ctx;
}
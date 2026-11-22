import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { clearExams } from '@/lib/exams';
import { login as neptunLogin, submitTwoFactorCode } from '@/neptun/api';
import { clearCache } from '@/neptun/cache';
import { bumpSessionGeneration, resetAuthFailures, setOnSessionExpired, type ExpiryReason } from '@/neptun/client';
import { invalidateTrainingId } from '@/neptun/data';
import { Store } from '@/neptun/storage';
import type { Institute, LoginOutcome } from '@/neptun/types';

type Status = 'restoring' | 'signedOut' | 'signedIn';

// password accepted, waiting for the 2fa code
type TwoFactorPending = { institute: Institute; username: string; password: string };

type AuthValue = {
  status: Status;
  isDemo: boolean;
  pendingTwoFactor: TwoFactorPending | null;
  reauth: boolean;
  expiry: { reason: ExpiryReason; username: string | null } | null;
  dismissExpiry: () => void;
  signInReal: (institute: Institute, username: string, password: string) => Promise<LoginOutcome>;
  submitTwoFactor: (code: string, onAccepted?: () => Promise<void>) => Promise<LoginOutcome>;
  cancelTwoFactor: () => void;
  signInDemo: () => void;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthValue | null>(null);

// new session never reuses the old training id or data, same account keeps it
function resetSessionData(wipe = true): void {
  invalidateTrainingId();
  bumpSessionGeneration();
  if (wipe) clearCache();
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>('restoring');
  const [isDemo, setIsDemo] = useState(false);
  const [pendingTwoFactor, setPendingTwoFactor] = useState<TwoFactorPending | null>(null);
  const [expiry, setExpiry] = useState<AuthValue['expiry']>(null);
  const [reauth, setReauth] = useState(false);

  // restore the stored session, stale tokens renew on first request
  useEffect(() => {
    let active = true;
    (async () => {
      const demo = await Store.getIsDemo();
      const username = await Store.getUsername();
      if (!active) return;
      if (demo && username === 'DEMO') {
        setIsDemo(true);
        setStatus('signedIn');
        return;
      }
      const token = await Store.getAccessToken();
      if (!active) return;
      setStatus(username && token ? 'signedIn' : 'signedOut');
    })();
    return () => {
      active = false;
    };
  }, []);

  // dead session goes to login, no retries. 2fa only? straight to the code prompt
  useEffect(() => {
    setOnSessionExpired((reason) => {
      void (async () => {
        const [username, password, url] = await Promise.all([
          Store.getUsername(),
          Store.getPassword(),
          Store.getInstituteUrl(),
        ]);
        await Store.setAccessToken(null);
        if (reason === 'password') await Store.setPassword(null);
        invalidateTrainingId();
        bumpSessionGeneration();
        setIsDemo(false);
        setExpiry({ reason, username });
        if (reason === 'twoFactor' && username && password && url) {
          // just a 2fa code away, keep the app and the cached shit on screen
          setPendingTwoFactor({ institute: { name: url, url, fallbacks: [] }, username, password });
          setReauth(true);
          return;
        }
        setPendingTwoFactor(null);
        setReauth(false);
        setStatus('signedOut');
      })();
    });
    return () => setOnSessionExpired(null);
  }, []);

  const dismissExpiry = useCallback(() => setExpiry(null), []);

  const signInReal = useCallback<AuthValue['signInReal']>(async (institute, username, password) => {
    const previous = await Store.getUsername();
    const outcome = await neptunLogin(institute, username, password);
    if (outcome.kind !== 'network' && previous && previous.toUpperCase() !== username.toUpperCase()) clearCache();
    if (outcome.kind === 'ok') {
      resetAuthFailures();
      resetSessionData(false);
      setExpiry(null);
      setIsDemo(username === 'DEMO');
      setPendingTwoFactor(null);
      setStatus('signedIn');
    } else if (outcome.kind === 'twoFactor') {
      setPendingTwoFactor({ institute, username, password });
    }
    return outcome;
  }, []);

  const submitTwoFactor = useCallback<AuthValue['submitTwoFactor']>(
    async (code, onAccepted) => {
      if (!pendingTwoFactor) return { kind: 'failed', message: null };
      const res = await submitTwoFactorCode(pendingTwoFactor.username, pendingTwoFactor.password, code);
      if (res.ok) {
        // Lets the code screen play its success state before the app swaps it out.
        await onAccepted?.();
        resetAuthFailures();
        resetSessionData(false);
        setExpiry(null);
        setPendingTwoFactor(null);
        setReauth(false);
        setIsDemo(false);
        setStatus('signedIn');
        return { kind: 'ok' };
      }
      if (res.reason === 'network') return { kind: 'network' };
      return { kind: 'failed', message: res.message, server: res.reason === 'server' };
    },
    [pendingTwoFactor],
  );

  const cancelTwoFactor = useCallback(() => {
    setPendingTwoFactor(null);
    if (reauth) setStatus('signedOut');
    setReauth(false);
  }, [reauth]);

  const signInDemo = useCallback(() => {
    resetSessionData();
    void Store.setIsDemo(true);
    void Store.setUsername('DEMO');
    setIsDemo(true);
    setPendingTwoFactor(null);
    setStatus('signedIn');
  }, []);

  const signOut = useCallback(async () => {
    await Store.clear();
    await clearExams();
    resetSessionData();
    setPendingTwoFactor(null);
    setReauth(false);
    setIsDemo(false);
    setStatus('signedOut');
  }, []);

  const value = useMemo<AuthValue>(
    () => ({
      status,
      isDemo,
      pendingTwoFactor,
      reauth,
      expiry,
      dismissExpiry,
      signInReal,
      submitTwoFactor,
      cancelTwoFactor,
      signInDemo,
      signOut,
    }),
    [status, isDemo, pendingTwoFactor, reauth, expiry, dismissExpiry, signInReal, submitTwoFactor, cancelTwoFactor, signInDemo, signOut],
  );

  return <AuthContext value={value}>{children}</AuthContext>;
}

export function useAuth(): AuthValue {
  const ctx = use(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
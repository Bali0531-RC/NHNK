import { createContext, use, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { login as neptunLogin, submitTwoFactorCode } from '@/neptun/api';
import { resetAuthFailures, setOnSessionExpired } from '@/neptun/client';
import { Store } from '@/neptun/storage';
import type { Institute, LoginOutcome } from '@/neptun/types';

type Status = 'restoring' | 'signedOut' | 'signedIn';

// Held while the server has accepted the password and is waiting for a 2FA code, so the
// code screen can finish the same attempt without asking for the password again.
type TwoFactorPending = { institute: Institute; username: string; password: string };

type AuthValue = {
  status: Status;
  isDemo: boolean;
  pendingTwoFactor: TwoFactorPending | null;
  signInReal: (institute: Institute, username: string, password: string) => Promise<LoginOutcome>;
  submitTwoFactor: (code: string) => Promise<LoginOutcome>;
  cancelTwoFactor: () => void;
  signInDemo: () => void;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>('restoring');
  const [isDemo, setIsDemo] = useState(false);
  const [pendingTwoFactor, setPendingTwoFactor] = useState<TwoFactorPending | null>(null);

  // Restore a stored session on launch. A real session only needs a username and a token;
  // a stale token renews itself on the first authenticated request via GetNewTokens.
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

  // A dead session (both renewal paths failed inside the client) routes to login rather
  // than retrying, the last line of defence against stacking up failed password attempts.
  useEffect(() => {
    setOnSessionExpired(() => {
      void Store.clear();
      setPendingTwoFactor(null);
      setIsDemo(false);
      setStatus('signedOut');
    });
    return () => setOnSessionExpired(null);
  }, []);

  const signInReal = useCallback<AuthValue['signInReal']>(async (institute, username, password) => {
    const outcome = await neptunLogin(institute, username, password);
    if (outcome.kind === 'ok') {
      resetAuthFailures();
      setIsDemo(username === 'DEMO');
      setPendingTwoFactor(null);
      setStatus('signedIn');
    } else if (outcome.kind === 'twoFactor') {
      setPendingTwoFactor({ institute, username, password });
    }
    return outcome;
  }, []);

  const submitTwoFactor = useCallback<AuthValue['submitTwoFactor']>(
    async (code) => {
      if (!pendingTwoFactor) return { kind: 'failed', message: null };
      const ok = await submitTwoFactorCode(pendingTwoFactor.username, pendingTwoFactor.password, code);
      if (ok) {
        setPendingTwoFactor(null);
        setIsDemo(false);
        setStatus('signedIn');
        return { kind: 'ok' };
      }
      return { kind: 'failed', message: null };
    },
    [pendingTwoFactor],
  );

  const cancelTwoFactor = useCallback(() => setPendingTwoFactor(null), []);

  const signInDemo = useCallback(() => {
    void Store.setIsDemo(true);
    void Store.setUsername('DEMO');
    setIsDemo(true);
    setPendingTwoFactor(null);
    setStatus('signedIn');
  }, []);

  const signOut = useCallback(async () => {
    await Store.clear();
    setPendingTwoFactor(null);
    setIsDemo(false);
    setStatus('signedOut');
  }, []);

  const value = useMemo<AuthValue>(
    () => ({
      status,
      isDemo,
      pendingTwoFactor,
      signInReal,
      submitTwoFactor,
      cancelTwoFactor,
      signInDemo,
      signOut,
    }),
    [status, isDemo, pendingTwoFactor, signInReal, submitTwoFactor, cancelTwoFactor, signInDemo, signOut],
  );

  return <AuthContext value={value}>{children}</AuthContext>;
}

export function useAuth(): AuthValue {
  const ctx = use(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}

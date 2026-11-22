import { useNetworkState } from 'expo-network';
import { useEffect, useEffectEvent, useState } from 'react';

import { markSynced, peekCache, readCache, subscribeCache, writeCache } from '@/neptun/cache';
import { NeptunError, neptunDown, setDeviceOnline, subscribeNeptunDown, type NeptunErrorKind } from '@/neptun/client';
import { subscribeNeptunLang } from '@/neptun/lang';
import { log } from '@/neptun/log';

// Reads stay fresh this long before a screen focus triggers another request.
const FRESH_MS = 90_000;

const inflight = new Map<string, Promise<unknown>>();
const fetchedAt = new Map<string, number>();
// cache isn't per language, so a switch makes every key stale, not just the ones on screen
subscribeNeptunLang(() => fetchedAt.clear());

export type QueryError = NeptunErrorKind | 'unknown';

export type Query<T> = {
  data: T | null;
  savedAt: number | null;
  loading: boolean; // nothing to show yet
  refreshing: boolean; // a request is running with data already on screen
  error: QueryError | null; // last request failed (data may still be cached)
  offline: boolean;
  down: boolean; // online, but Neptun is not answering
  refresh: () => Promise<void>;
};

type State<T> = {
  key: string | null;
  data: T | null;
  savedAt: number | null;
  loading: boolean;
  refreshing: boolean;
  error: QueryError | null;
};

function initial<T>(key: string | null): State<T> {
  const hit = key ? peekCache<T>(key) : null;
  return {
    key,
    data: hit?.data ?? null,
    savedAt: hit?.savedAt ?? null,
    loading: !!key && !hit,
    refreshing: false,
    error: null,
  };
}

// stale while revalidate over the disk cache. null key = stay idle
export function useNeptunQuery<T>(key: string | null, fetcher: () => Promise<T>): Query<T> {
  const net = useNetworkState();
  const offline = net.isConnected === false || net.isInternetReachable === false;
  setDeviceOnline(!offline);
  const [state, setState] = useState<State<T>>(() => initial<T>(key));
  const [down, setDown] = useState(neptunDown);
  useEffect(() => subscribeNeptunDown(setDown), []);

  // Switching keys (another week, another term) starts from that key's cached copy.
  let current = state;
  if (state.key !== key) {
    current = initial<T>(key);
    setState(current);
  }

  const patch = (k: string, p: Partial<State<T>>) => setState((s) => (s.key === k ? { ...s, ...p } : s));

  const load = async (force: boolean) => {
    if (!key) return;
    const k = key;
    const cached = await readCache<T>(k);
    if (cached) patch(k, { data: cached.data, savedAt: cached.savedAt, loading: false });

    const last = fetchedAt.get(k) ?? 0;
    if (!force && cached && Date.now() - last < FRESH_MS) return;

    patch(k, { refreshing: true, error: null });
    try {
      let p = inflight.get(k) as Promise<T> | undefined;
      if (!p) {
        p = fetcher();
        inflight.set(k, p);
      }
      const data = await p;
      const saved = await writeCache(k, data);
      fetchedAt.set(k, Date.now());
      markSynced();
      patch(k, { data, savedAt: saved.savedAt, loading: false, refreshing: false, error: null });
    } catch (err) {
      const kind: QueryError = err instanceof NeptunError ? err.kind : 'unknown';
      if (kind === 'unknown') log.error('query', `${k} failed`, err);
      patch(k, { loading: false, refreshing: false, error: kind });
    } finally {
      inflight.delete(k);
    }
  };

  useEffect(() => {
    if (!key) return;
    return subscribeCache(key, (entry) =>
      setState((s) => (s.key === key ? { ...s, data: entry.data as T, savedAt: entry.savedAt, loading: false } : s)),
    );
  }, [key]);

  const onKey = useEffectEvent(() => {
    void load(false);
  });
  useEffect(() => {
    if (!key) return;
    const id = setTimeout(onKey, 0);
    return () => clearTimeout(id);
  }, [key]);

  // language switch = neptun answers in another language now, refetch everything on screen
  const onLang = useEffectEvent(() => {
    void load(true);
  });
  useEffect(() => {
    if (!key) return;
    return subscribeNeptunLang(() => onLang());
  }, [key]);

  // Coming back online retries straight away instead of waiting for a pull.
  const onReconnect = useEffectEvent(() => {
    if (state.error) void load(true);
  });
  useEffect(() => {
    if (offline) return;
    const id = setTimeout(onReconnect, 0);
    return () => clearTimeout(id);
  }, [offline]);

  return {
    data: current.data,
    savedAt: current.savedAt,
    loading: current.loading,
    refreshing: current.refreshing,
    error: current.error,
    offline,
    down: !offline && (down || current.error === 'down'),
    refresh: () => load(true),
  };
}
import { useCallback, useEffect, useState } from 'react';

import { peekCache, readCache, subscribeCache, writeCache } from '@/neptun/cache';

// state that survives restarts, lives in the cache so sign out wipes it
export function usePersistentState<T>(key: string, initial: T): [T, (next: T | ((prev: T) => T)) => void, boolean] {
  const [value, setValue] = useState<T>(() => peekCache<T>(`ui.${key}`)?.data ?? initial);
  const [ready, setReady] = useState(() => peekCache<T>(`ui.${key}`) !== null);

  useEffect(() => {
    let active = true;
    void readCache<T>(`ui.${key}`).then((hit) => {
      if (!active) return;
      if (hit) setValue(hit.data);
      setReady(true);
    });
    const unsub = subscribeCache(`ui.${key}`, (entry) => setValue(entry.data as T));
    return () => {
      active = false;
      unsub();
    };
  }, [key]);

  const set = useCallback(
    (next: T | ((prev: T) => T)) => {
      setValue((prev) => {
        const resolved = typeof next === 'function' ? (next as (p: T) => T)(prev) : next;
        queueMicrotask(() => void writeCache(`ui.${key}`, resolved));
        return resolved;
      });
    },
    [key],
  );

  return [value, set, ready];
}
import { useSyncExternalStore } from 'react';

import { getLastSync, subscribeLastSync } from '@/neptun/cache';

export function useLastSync(): number | null {
  return useSyncExternalStore(subscribeLastSync, getLastSync);
}
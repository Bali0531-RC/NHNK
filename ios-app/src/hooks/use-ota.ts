import * as SecureStore from 'expo-secure-store';
import * as Updates from 'expo-updates';
import { useEffect, useRef } from 'react';
import { AppState } from 'react-native';

import { log } from '@/neptun/log';

const TRIED = 'nhnk_ota_tried';
const GAP_MS = 5 * 60 * 1000;
const QUICK_MS = 4000;

let lastCheck = 0;
let busy = false;
let ready: string | null = null;

export const otaEnabled = !__DEV__ && Updates.isEnabled;

// check + download. new update id, or null when we already run the latest
export async function pullUpdate(): Promise<string | null> {
  if (ready) return ready;
  const res = await Updates.checkForUpdateAsync();
  if (!res.isAvailable) return null;
  const got = await Updates.fetchUpdateAsync();
  if (!got.isNew) return null;
  ready = res.manifest?.id ?? 'unknown';
  return ready;
}

export async function applyUpdate(id: string): Promise<void> {
  await SecureStore.setItemAsync(TRIED, id).catch(() => {});
  await Updates.reloadAsync();
}

// ios almost never cold starts, so check on open and every foreground
export function useOta(canReload: boolean): void {
  const ok = useRef(canReload);
  useEffect(() => {
    ok.current = canReload;
  }, [canReload]);

  useEffect(() => {
    if (!otaEnabled) return;
    const run = async () => {
      if (busy || (!ready && Date.now() - lastCheck < GAP_MS)) return;
      busy = true;
      lastCheck = Date.now();
      const t0 = Date.now();
      try {
        const id = await pullUpdate();
        if (!id) return;
        // tried it already and still not running it = it crashed and got rolled back, dont reload loop
        if ((await SecureStore.getItemAsync(TRIED).catch(() => null)) === id) return;
        // slow download, dont yank the screen mid-use. next foreground swaps instantly
        if (ok.current && Date.now() - t0 < QUICK_MS) await applyUpdate(id);
      } catch (e) {
        log.warn('ota', 'update check failed', e);
      } finally {
        busy = false;
      }
    };
    void run();
    const sub = AppState.addEventListener('change', (s) => {
      if (s === 'active') void run();
    });
    return () => sub.remove();
  }, []);
}
// last good copy of every read on disk. never tokens or raw responses

import { Directory, File, Paths } from 'expo-file-system';

import { log } from './log';

export type Cached<T> = { data: T; savedAt: number };

const memory = new Map<string, Cached<unknown>>();

// One app-wide "last synced with Neptun" moment, so every offline banner shows the same time.
const SYNC_KEY = 'meta.lastSync';
let lastSync: number | null = null;
let syncLoaded = false;
const syncListeners = new Set<() => void>();

export function getLastSync(): number | null {
  return lastSync;
}

export function subscribeLastSync(fn: () => void): () => void {
  syncListeners.add(fn);
  if (!syncLoaded) {
    syncLoaded = true;
    void readCache<number>(SYNC_KEY).then((hit) => {
      if (hit && (lastSync == null || hit.data > lastSync)) {
        lastSync = hit.data;
        syncListeners.forEach((f) => f());
      }
    });
  }
  return () => syncListeners.delete(fn);
}

export function markSynced(): void {
  lastSync = Date.now();
  syncListeners.forEach((f) => f());
  void writeCache(SYNC_KEY, lastSync);
}
const listeners = new Map<string, Set<(entry: Cached<unknown>) => void>>();

// Lets every screen showing a key pick up a write made elsewhere (a message marked read).
export function subscribeCache(key: string, fn: (entry: Cached<unknown>) => void): () => void {
  let set = listeners.get(key);
  if (!set) {
    set = new Set();
    listeners.set(key, set);
  }
  set.add(fn);
  return () => set.delete(fn);
}

function dir(): Directory {
  return new Directory(Paths.document, 'nhnk-cache');
}

function fileFor(key: string): File {
  return new File(dir(), `${key.replace(/[^A-Za-z0-9._-]/g, '_')}.json`);
}

export function peekCache<T>(key: string): Cached<T> | null {
  return (memory.get(key) as Cached<T> | undefined) ?? null;
}

export async function readCache<T>(key: string): Promise<Cached<T> | null> {
  const hit = memory.get(key);
  if (hit) return hit as Cached<T>;
  try {
    const f = fileFor(key);
    if (!f.exists) return null;
    const parsed = JSON.parse(await f.text()) as Cached<T>;
    if (parsed && typeof parsed.savedAt === 'number') {
      memory.set(key, parsed);
      return parsed;
    }
  } catch (err) {
    log.warn('cache', `unreadable cache entry ${key}`, err);
  }
  return null;
}

export async function writeCache<T>(key: string, data: T): Promise<Cached<T>> {
  const entry: Cached<T> = { data, savedAt: Date.now() };
  memory.set(key, entry);
  listeners.get(key)?.forEach((fn) => fn(entry));
  try {
    const d = dir();
    if (!d.exists) d.create({ intermediates: true, idempotent: true });
    await fileFor(key).write(JSON.stringify(entry));
  } catch (err) {
    log.warn('cache', `could not persist ${key}`, err);
  }
  return entry;
}

// Called on sign-out so the next account never sees the previous one's data.
export function clearCache(): void {
  memory.clear();
  lastSync = null;
  syncListeners.forEach((f) => f());
  try {
    const d = dir();
    if (d.exists) d.delete();
  } catch (err) {
    log.warn('cache', 'could not clear cache directory', err);
  }
}

// clear cache keeps what the student set up
export function clearDataCache(): void {
  for (const key of [...memory.keys()]) if (!key.startsWith('ui.')) memory.delete(key);
  try {
    const d = dir();
    if (!d.exists) return;
    for (const item of d.list()) {
      if (item instanceof File && !item.name.startsWith('ui.')) item.delete();
    }
  } catch (err) {
    log.warn('cache', 'could not clear data cache', err);
  }
}
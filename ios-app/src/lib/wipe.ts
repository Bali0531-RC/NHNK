import { reloadAppAsync } from 'expo';
import { Directory, File, Paths } from 'expo-file-system';
import * as Notifications from 'expo-notifications';
import * as SecureStore from 'expo-secure-store';

import { clearExams } from '@/lib/exams';
import { clearCache } from '@/neptun/cache';
import { log } from '@/neptun/log';
import { Store } from '@/neptun/storage';

// ui prefs, language, ota guard. the auth keys go through Store.clear
const EXTRA_KEYS = [
  'nhnk.prefs.v2',
  'nhnk.pref.themeMode',
  'nhnk.pref.haptics',
  'nhnk.pref.biometricLock',
  'nhnk.pref.onboardingSeen',
  'nhnk.pref.lang',
  'nhnk_ota_tried',
];
const MARKER = '.nhnk-installed';

const marker = () => new File(Paths.document, MARKER);

async function wipeKeychain(): Promise<void> {
  await Store.clear();
  await Promise.all(EXTRA_KEYS.map((k) => SecureStore.deleteItemAsync(k).catch(() => {})));
}

// keychain survives an uninstall, documents dont. no marker and no cache folder = fresh install
export const needsInstallWipe: boolean = (() => {
  try {
    if (marker().exists) return false;
    return !['nhnk-cache', 'exams'].some((n) => new Directory(Paths.document, n).exists);
  } catch {
    return false;
  }
})();

export async function prepareInstall(): Promise<void> {
  try {
    if (needsInstallWipe) await wipeKeychain();
    const m = marker();
    if (!m.exists) m.create();
  } catch (err) {
    log.warn('wipe', 'install check failed', err);
  }
}

// settings > reset app. like a fresh install, onboarding included
export async function eraseEverything(): Promise<void> {
  await wipeKeychain();
  clearCache();
  await clearExams();
  try {
    for (const item of Paths.document.list()) if (item.name !== MARKER) item.delete();
  } catch (err) {
    log.warn('wipe', 'documents wipe failed', err);
  }
  await Notifications.cancelAllScheduledNotificationsAsync().catch(() => {});
  await Notifications.setBadgeCountAsync(0).catch(() => {});
  await reloadAppAsync('reset');
}
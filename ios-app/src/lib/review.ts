import { useEffect } from 'react';
import { AppState } from 'react-native';

import { readCache, writeCache } from '@/neptun/cache';
import { mondayOf, type ClassEntry } from '@/neptun/data';
import { log } from '@/neptun/log';

type ReviewState = { firstSeen: number; asked: boolean };

const KEY = 'ui.review';
const WAIT_MS = 7 * 24 * 60 * 60 * 1000;
const THURSDAY = 4;

// thursdays only, after the weeks last class is over. apple caps it at 3 a year anyway
async function lastClassEnd(): Promise<number> {
  const d = mondayOf(0);
  const week = (await readCache<ClassEntry[]>(`week.${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`))?.data ?? [];
  return Math.max(0, ...week.filter((e) => e.kind === 'class').map((e) => e.endMs));
}

async function onOpen(): Promise<void> {
  const now = Date.now();
  const prev = (await readCache<ReviewState>(KEY))?.data;
  const state: ReviewState = prev ? { firstSeen: prev.firstSeen, asked: prev.asked } : { firstSeen: now, asked: false };
  if (!prev) await writeCache(KEY, state);
  if (state.asked || now - state.firstSeen < WAIT_MS || new Date(now).getDay() !== THURSDAY) return;
  if (now < (await lastClassEnd())) return;
  try {
    const StoreReview = await import('expo-store-review');
    if ((await StoreReview.isAvailableAsync()) && (await StoreReview.hasAction())) {
      await StoreReview.requestReview();
      await writeCache(KEY, { ...state, asked: true });
    }
  } catch (err) {
    log.warn('review', 'store review unavailable', err);
  }
}

export function useReviewPrompt(signedIn: boolean): void {
  useEffect(() => {
    if (!signedIn) return;
    const timer = setTimeout(() => void onOpen(), 4000);
    const sub = AppState.addEventListener('change', (s) => {
      if (s === 'active') void onOpen();
    });
    return () => {
      clearTimeout(timer);
      sub.remove();
    };
  }, [signedIn]);
}
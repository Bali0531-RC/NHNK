import type { V2Strings } from '@/i18n/v2-strings';

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

// last half hour of a class. random per class, but it doesnt flicker every tick
export function pickCheer(s: V2Strings['cheer'], id: string, leftMs: number): string | null {
  const min = leftMs / 60_000;
  if (min > 30 || min <= 0) return null;
  const last = min <= 10;
  const pool = last ? s.last : s.soon;
  return pool[hash(`${id}${last}`) % pool.length];
}
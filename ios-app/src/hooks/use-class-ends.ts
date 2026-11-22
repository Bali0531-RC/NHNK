import { useCallback } from 'react';

import { usePersistentState } from '@/hooks/use-persistent-state';
import type { ClassEntry } from '@/neptun/data';

// neptun says 12:00, the lecturer lets you go at 11:45. per subject, only the minute, the hour comes from neptun
type ClassEnd = { minute: number; code: string };

export const subjectKey = (name: string) => name.trim().toLowerCase().replace(/\s+/g, ' ');

// last moment at or before the neptun end that lands on that minute. never before the start
export function realEnd(startMs: number, endMs: number, minute: number): number {
  const d = new Date(endMs);
  d.setMinutes(minute, 0, 0);
  const t = d.getTime() > endMs ? d.getTime() - 3_600_000 : d.getTime();
  return t > startMs ? t : endMs;
}

export function useClassEnds() {
  const [map, setMap] = usePersistentState<Record<string, ClassEnd>>('class-ends', {});

  const setMinute = useCallback(
    (s: { name: string; code: string }, minute: number | null) =>
      setMap((prev) => {
        const next = { ...prev };
        if (minute === null) delete next[subjectKey(s.name)];
        else next[subjectKey(s.name)] = { minute, code: s.code };
        return next;
      }),
    [setMap],
  );

  const minuteOf = (name: string): number | null => map[subjectKey(name)]?.minute ?? null;

  // title first like everywhere else, course code as the fallback when neptun names it differently in the calendar
  const endFor = (e: ClassEntry): number => {
    if (e.kind !== 'class') return e.endMs;
    const hit =
      map[subjectKey(e.title)] ??
      Object.values(map).find((x) => x.code && (e.code === x.code || e.code.startsWith(`${x.code}-`) || e.code.startsWith(`${x.code}_`)));
    return hit ? realEnd(e.startMs, e.endMs, hit.minute) : e.endMs;
  };

  return { minuteOf, setMinute, endFor };
}
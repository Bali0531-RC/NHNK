import { useCallback } from 'react';

import { usePersistentState } from '@/hooks/use-persistent-state';
import type { ClassEntry } from '@/neptun/data';

export type CourseKind = 'all' | 'theory' | 'practice' | 'lab';
export const COURSE_KINDS: CourseKind[] = ['all', 'theory', 'practice', 'lab'];

// neptun says 12:00, the lecturer lets you go at 11:45. per subject and course type, only the minute, the hour comes from neptun
type ClassEnd = { minute?: number; code: string; byKind?: Partial<Record<Exclude<CourseKind, 'all'>, number>> };

export const subjectKey = (name: string) => name.trim().toLowerCase().replace(/\s+/g, ' ');

// neptun names the course type in whatever language it feels like
export function courseKind(type: string): Exclude<CourseKind, 'all'> | null {
  const t = type.toLowerCase();
  if (/lab/.test(t)) return 'lab';
  if (/elm[eé]l|el[oő]ad|theor|lect|vorles/.test(t)) return 'theory';
  if (/gyak|prac|übung|ubung|szemin|semin/.test(t)) return 'practice';
  return null;
}

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
    (s: { name: string; code: string }, minute: number | null, kind: CourseKind = 'all') =>
      setMap((prev) => {
        const key = subjectKey(s.name);
        const cur: ClassEnd = { ...prev[key], code: s.code, byKind: { ...prev[key]?.byKind } };
        if (kind === 'all') cur.minute = minute ?? undefined;
        else if (minute === null) delete cur.byKind![kind];
        else cur.byKind![kind] = minute;
        const next = { ...prev };
        if (cur.minute === undefined && !Object.keys(cur.byKind!).length) delete next[key];
        else next[key] = cur;
        return next;
      }),
    [setMap],
  );

  const minuteOf = (name: string, kind: CourseKind = 'all'): number | null => {
    const hit = map[subjectKey(name)];
    return (kind === 'all' ? hit?.minute : hit?.byKind?.[kind]) ?? null;
  };

  // every minute set for the subject, for the list badge
  const minutesOf = (name: string): { kind: CourseKind; minute: number }[] => {
    const hit = map[subjectKey(name)];
    if (!hit) return [];
    const out: { kind: CourseKind; minute: number }[] = hit.minute === undefined ? [] : [{ kind: 'all', minute: hit.minute }];
    for (const k of COURSE_KINDS) if (k !== 'all' && hit.byKind?.[k] !== undefined) out.push({ kind: k, minute: hit.byKind[k]! });
    return out;
  };

  // title first like everywhere else, course code as the fallback when neptun names it differently in the calendar
  const endFor = (e: ClassEntry): number => {
    if (e.kind !== 'class') return e.endMs;
    const hit =
      map[subjectKey(e.title)] ??
      Object.values(map).find((x) => x.code && (e.code === x.code || e.code.startsWith(`${x.code}-`) || e.code.startsWith(`${x.code}_`)));
    if (!hit) return e.endMs;
    const kind = courseKind(e.courseType);
    const minute = (kind && hit.byKind?.[kind]) ?? hit.minute;
    return minute === undefined ? e.endMs : realEnd(e.startMs, e.endMs, minute);
  };

  return { minuteOf, minutesOf, setMinute, endFor };
}
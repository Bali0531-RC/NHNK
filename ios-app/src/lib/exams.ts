import { Directory, File, Paths } from 'expo-file-system';
import { useEffect, useSyncExternalStore } from 'react';

import { sameDay } from '@/lib/format';
import { log } from '@/neptun/log';

// zh / quiz the user adds by hand. lives only on this phone, photos copied into our own folder
export type ManualExam = {
  id: string;
  title: string;
  notes: string;
  atMs: number;
  photos: string[]; // file names inside the exams folder
  remindEvening: boolean;
  remindHour: boolean;
  // the lesson it hangs on. instance id first, normalized title + start as fallback when neptun reshuffles ids
  lesson: { title: string; startMs: number; endMs: number; instance: string };
};

const norm = (t: string) => t.trim().toLowerCase().replace(/\s+/g, ' ');

const dir = () => new Directory(Paths.document, 'exams');
const indexFile = () => new File(dir(), 'exams.json');

let exams: ManualExam[] = [];
let loaded = false;
let loading: Promise<void> | null = null;
const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((fn) => fn());
}

export async function loadExams(): Promise<ManualExam[]> {
  if (loaded) return exams;
  loading ??= (async () => {
    try {
      const f = indexFile();
      if (f.exists) {
        const parsed = JSON.parse(await f.text()) as unknown;
        if (Array.isArray(parsed)) exams = parsed as ManualExam[];
      }
    } catch (err) {
      log.warn('exams', 'load failed', err);
    }
    loaded = true;
    emit();
  })();
  await loading;
  return exams;
}

async function persist() {
  try {
    const d = dir();
    if (!d.exists) d.create({ intermediates: true });
    const f = indexFile();
    if (!f.exists) f.create();
    await f.write(JSON.stringify(exams));
  } catch (err) {
    log.warn('exams', 'save failed', err);
  }
}

export function photoUri(name: string): string {
  return new File(dir(), name).uri;
}

// copies a picked image in so it survives the picker's temp cleanup
export async function importPhoto(uri: string): Promise<string | null> {
  try {
    const d = dir();
    if (!d.exists) d.create({ intermediates: true });
    const ext = (uri.split('?')[0].split('.').pop() || 'jpg').toLowerCase().slice(0, 5);
    const name = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
    await new File(uri).copy(new File(d, name));
    return name;
  } catch (err) {
    log.warn('exams', 'photo import failed', err);
    return null;
  }
}

export function deletePhotoFile(name: string) {
  try {
    const f = new File(dir(), name);
    if (f.exists) f.delete();
  } catch (err) {
    log.warn('exams', 'photo delete failed', err);
  }
}

export async function saveExam(exam: ManualExam): Promise<void> {
  await loadExams();
  const prev = exams.find((x) => x.id === exam.id);
  prev?.photos.filter((p) => !exam.photos.includes(p)).forEach(deletePhotoFile);
  exams = [...exams.filter((x) => x.id !== exam.id), exam].sort((a, b) => a.atMs - b.atMs);
  emit();
  await persist();
}

export async function removeExam(id: string): Promise<void> {
  await loadExams();
  exams.find((x) => x.id === id)?.photos.forEach(deletePhotoFile);
  exams = exams.filter((x) => x.id !== id);
  emit();
  await persist();
}

// sign out wipes it, notes can be personal
export async function clearExams(): Promise<void> {
  exams = [];
  loaded = true;
  emit();
  try {
    const d = dir();
    if (d.exists) d.delete();
  } catch (err) {
    log.warn('exams', 'clear failed', err);
  }
}

export function examsFor(list: ManualExam[], lesson: { title: string; startMs: number; instance?: string }): ManualExam[] {
  return list.filter(
    (x) =>
      (!!lesson.instance && x.lesson.instance === lesson.instance && Math.abs(x.lesson.startMs - lesson.startMs) < 3 * 86_400_000) ||
      (norm(x.lesson.title) === norm(lesson.title) && x.lesson.startMs === lesson.startMs),
  );
}

export function useExams(): ManualExam[] {
  useEffect(() => {
    void loadExams();
  }, []);
  return useSyncExternalStore(
    (fn) => {
      listeners.add(fn);
      return () => listeners.delete(fn);
    },
    () => exams,
  );
}

// added from the + button, no lesson behind it. lives on its own day in the calendar
export const isLoose = (x: ManualExam) => !x.lesson.title && !x.lesson.instance;

// evenings are when the zh-s actually happen. if 18:00 already passed, next full hour
export function defaultExamTime(dayMs: number, now = Date.now()): number {
  const d = new Date(dayMs);
  const evening = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 18, 0).getTime();
  if (evening > now) return evening;
  const next = new Date(now);
  next.setMinutes(0, 0, 0);
  return next.getTime() + 3_600_000;
}

export function newExamId(): string {
  return `ex-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

export const DEMO_EXAM_ID = 'demo-zh';

// demo only: today's evening zh. moves to today, follows the language, anything the user changed by hand stays
export async function syncDemoExam(atMs: number, titles: readonly string[], title: string): Promise<void> {
  await loadExams();
  const prev = exams.find((x) => x.id === DEMO_EXAM_ID);
  const next: ManualExam = prev
    ? { ...prev, atMs: sameDay(prev.atMs, atMs) ? prev.atMs : atMs, title: titles.includes(prev.title) ? title : prev.title }
    : {
        id: DEMO_EXAM_ID,
        title,
        notes: '',
        atMs,
        photos: [],
        remindEvening: false,
        remindHour: false,
        lesson: { title: '', startMs: 0, endMs: 0, instance: '' },
      };
  if (prev && prev.atMs === next.atMs && prev.title === next.title) return;
  await saveExam(next);
}
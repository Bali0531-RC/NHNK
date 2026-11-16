// Self-contained fixtures so the demo runs with no network and no Neptun account.
// Shapes mirror what the real API returns (see API-DOCS in the repo root) so these
// screens can later swap fixtures for live data without a rewrite.

import type { Lang } from '@/i18n/strings';

export type ClassType = 'lecture' | 'practice' | 'exam';

export type TimetableEntry = {
  id: string;
  day: number; // 0 = Monday ... 4 = Friday
  start: string; // HH:MM
  end: string;
  titleHu: string;
  titleEn: string;
  code: string;
  room: string;
  teacher: string;
  type: ClassType;
};

export type Grade = {
  id: string;
  subjectHu: string;
  subjectEn: string;
  code: string;
  credits: number;
  grade: number; // 1..5
  type: 'exam' | 'midterm';
};

export type Exam = {
  id: string;
  subjectHu: string;
  subjectEn: string;
  date: string; // ISO
  room: string;
  type: 'written' | 'oral';
};

export const student = {
  nameHu: 'Teszt Hallgató',
  nameEn: 'Demo Student',
  neptun: 'DEMO01',
  institutionHu: 'Demó Egyetem',
  institutionEn: 'Demo University',
};

export const creditProgress = { completed: 118, required: 180 };

export const timetable: TimetableEntry[] = [
  { id: 't1', day: 0, start: '08:00', end: '09:30', titleHu: 'Analízis I.', titleEn: 'Calculus I', code: 'MAT101', room: 'B-204', teacher: 'Dr. Kovács Anna', type: 'lecture' },
  { id: 't2', day: 0, start: '10:00', end: '11:30', titleHu: 'Programozás I.', titleEn: 'Programming I', code: 'INF110', room: 'Lab-3', teacher: 'Nagy Péter', type: 'practice' },
  { id: 't3', day: 1, start: '09:00', end: '10:30', titleHu: 'Lineáris algebra', titleEn: 'Linear Algebra', code: 'MAT120', room: 'A-101', teacher: 'Dr. Szabó Gábor', type: 'lecture' },
  { id: 't4', day: 1, start: '12:00', end: '13:30', titleHu: 'Fizika', titleEn: 'Physics', code: 'FIZ100', room: 'C-012', teacher: 'Dr. Tóth Éva', type: 'lecture' },
  { id: 't5', day: 2, start: '08:00', end: '09:30', titleHu: 'Programozás I.', titleEn: 'Programming I', code: 'INF110', room: 'Lab-3', teacher: 'Nagy Péter', type: 'lecture' },
  { id: 't6', day: 2, start: '14:00', end: '15:30', titleHu: 'Diszkrét matematika', titleEn: 'Discrete Mathematics', code: 'MAT130', room: 'B-204', teacher: 'Dr. Kiss László', type: 'practice' },
  { id: 't7', day: 3, start: '10:00', end: '11:30', titleHu: 'Analízis I.', titleEn: 'Calculus I', code: 'MAT101', room: 'B-110', teacher: 'Dr. Kovács Anna', type: 'practice' },
  { id: 't8', day: 4, start: '09:00', end: '10:30', titleHu: 'Számítógép architektúrák', titleEn: 'Computer Architecture', code: 'INF140', room: 'A-205', teacher: 'Dr. Farkas Zoltán', type: 'lecture' },
];

export const grades: Grade[] = [
  { id: 'g1', subjectHu: 'Bevezetés a programozásba', subjectEn: 'Intro to Programming', code: 'INF100', credits: 6, grade: 5, type: 'exam' },
  { id: 'g2', subjectHu: 'Kalkulus', subjectEn: 'Calculus', code: 'MAT100', credits: 6, grade: 4, type: 'exam' },
  { id: 'g3', subjectHu: 'Digitális technika', subjectEn: 'Digital Design', code: 'INF105', credits: 5, grade: 5, type: 'exam' },
  { id: 'g4', subjectHu: 'Angol szaknyelv', subjectEn: 'Technical English', code: 'LAN200', credits: 2, grade: 4, type: 'midterm' },
  { id: 'g5', subjectHu: 'Statisztika', subjectEn: 'Statistics', code: 'MAT150', credits: 4, grade: 3, type: 'exam' },
  { id: 'g6', subjectHu: 'Operációs rendszerek', subjectEn: 'Operating Systems', code: 'INF160', credits: 5, grade: 5, type: 'exam' },
];

export const exams: Exam[] = [
  { id: 'e1', subjectHu: 'Analízis I.', subjectEn: 'Calculus I', date: isoInDays(5, '10:00'), room: 'B-204', type: 'written' },
  { id: 'e2', subjectHu: 'Programozás I.', subjectEn: 'Programming I', date: isoInDays(12, '14:00'), room: 'Lab-3', type: 'oral' },
  { id: 'e3', subjectHu: 'Lineáris algebra', subjectEn: 'Linear Algebra', date: isoInDays(19, '09:00'), room: 'A-101', type: 'written' },
];

export function weightedAverage(list: Grade[]): number {
  const totalCredits = list.reduce((sum, g) => sum + g.credits, 0);
  if (totalCredits === 0) return 0;
  const weighted = list.reduce((sum, g) => sum + g.grade * g.credits, 0);
  return weighted / totalCredits;
}

export function totalCredits(list: Grade[]): number {
  return list.reduce((sum, g) => sum + g.credits, 0);
}

// Next class after the current moment, searching from today across the demo week.
export function nextClass(now = new Date()): TimetableEntry | null {
  const todayIdx = (now.getDay() + 6) % 7; // JS Sunday=0 to Monday=0
  const minutesNow = now.getHours() * 60 + now.getMinutes();
  for (let offset = 0; offset < 7; offset++) {
    const day = (todayIdx + offset) % 7;
    if (day > 4) continue;
    const onDay = timetable
      .filter((c) => c.day === day)
      .sort((a, b) => toMinutes(a.start) - toMinutes(b.start));
    for (const c of onDay) {
      if (offset > 0 || toMinutes(c.start) >= minutesNow) return c;
    }
  }
  return timetable[0] ?? null;
}

export function pickTitle(entry: TimetableEntry, lang: Lang): string {
  return lang === 'hu' ? entry.titleHu : entry.titleEn;
}

function toMinutes(hhmm: string): number {
  const [h, m] = hhmm.split(':').map(Number);
  return h * 60 + m;
}

function isoInDays(days: number, hhmm: string): string {
  const d = new Date();
  d.setDate(d.getDate() + days);
  const [h, m] = hhmm.split(':').map(Number);
  d.setHours(h, m, 0, 0);
  return d.toISOString();
}

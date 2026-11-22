import type { SubjectEntry } from '@/neptun/data';

// what-if changes on a subject, missing field = whatever neptun says
export type Override = { grade?: number; completed?: boolean };
export type OverrideMap = Record<string, Override>;

export type Effective = { grade: number; completed: boolean; altered: boolean };

export function effective(s: SubjectEntry, o: Override | undefined): Effective {
  if (!o) return { grade: s.grade, completed: s.completed, altered: false };
  const grade = o.grade ?? s.grade;
  // A planned grade implies the matching outcome unless completion was set explicitly.
  const completed = o.completed ?? (o.grade !== undefined ? o.grade >= 2 : s.completed);
  return { grade, completed, altered: grade !== s.grade || completed !== s.completed };
}

export type TermStats = {
  taken: number;
  completed: number;
  arithmetic: number;
  weighted: number;
  gradedCredits: number;
  creditIndex: number;
  correctedIndex: number;
  altered: boolean;
};

// credit index = sum(grade * passed credit) / 30, corrected scales by done/taken. pass/fail never counts in averages
export function termStats(subjects: SubjectEntry[], overrides: OverrideMap = {}): TermStats {
  let taken = 0;
  let completed = 0;
  let gradeSum = 0;
  let gradeCount = 0;
  let weightedSum = 0;
  let weightedCredits = 0;
  let passedWeighted = 0;
  let altered = false;

  for (const s of subjects) {
    taken += s.credit;
    const e = effective(s, overrides[s.id]);
    altered ||= e.altered;
    if (e.completed) completed += s.credit;
    if (s.passFail && !overrides[s.id]?.grade) continue;
    if (e.grade >= 1) {
      gradeSum += e.grade;
      gradeCount += 1;
      weightedSum += e.grade * s.credit;
      weightedCredits += s.credit;
      if (e.grade >= 2) passedWeighted += e.grade * s.credit;
    }
  }

  const creditIndex = passedWeighted / 30;
  return {
    taken,
    completed,
    arithmetic: gradeCount ? gradeSum / gradeCount : 0,
    weighted: weightedCredits ? weightedSum / weightedCredits : 0,
    gradedCredits: weightedCredits,
    creditIndex,
    correctedIndex: taken ? creditIndex * (completed / taken) : 0,
    altered,
  };
}
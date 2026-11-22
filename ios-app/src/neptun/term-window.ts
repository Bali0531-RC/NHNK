export type TermWindow = { fromMs: number; toMs: number };
export type AcademicTerm = { year: number; sem: 1 | 2 };

// hungarian academic year: fall is aug to jan, spring is feb to jul. neptun has no term on payments so this buckets them
export function academicTermAt(ms: number): AcademicTerm {
  const d = new Date(ms);
  const m = d.getMonth();
  if (m >= 7) return { year: d.getFullYear(), sem: 1 };
  return m >= 1 ? { year: d.getFullYear() - 1, sem: 2 } : { year: d.getFullYear() - 1, sem: 1 };
}

export function windowOf({ year, sem }: AcademicTerm): TermWindow {
  return sem === 1
    ? { fromMs: new Date(year, 7, 1).getTime(), toMs: new Date(year + 1, 1, 1).getTime() }
    : { fromMs: new Date(year + 1, 1, 1).getTime(), toMs: new Date(year + 1, 7, 1).getTime() };
}

export function termLabel({ year, sem }: AcademicTerm): string {
  return `${year}/${String((year + 1) % 100).padStart(2, '0')}/${sem}`;
}

export function previousTerm({ year, sem }: AcademicTerm): AcademicTerm {
  return sem === 2 ? { year, sem: 1 } : { year: year - 1, sem: 2 };
}

// "2025/26/1", "2025/2026/2", "2025/26 ősz" and friends. null when the uni names it something we cant read
export function parseTermName(name: string): AcademicTerm | null {
  const y = /(20\d{2})\s*\/\s*(?:20)?\d{2}/.exec(name);
  if (!y) return null;
  const tail = name.slice(y.index + y[0].length);
  const sem = /^\s*\/\s*1\b/.test(tail) || /ősz|osz|fall|autumn|winter/i.test(name)
    ? 1
    : /^\s*\/\s*2\b/.test(tail) || /tavasz|spring|sommer|summer/i.test(name)
      ? 2
      : null;
  return sem ? { year: Number(y[1]), sem } : null;
}
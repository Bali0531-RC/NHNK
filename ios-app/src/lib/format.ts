export const DAY_MS = 86400000;

export function localeOf(lang: string): string {
  return lang === 'hu' ? 'hu-HU' : lang === 'de' ? 'de-DE' : 'en-US';
}

export function fmtDate(ms: number, lang: string, withYear = false): string {
  if (!ms) return '';
  return new Intl.DateTimeFormat(localeOf(lang), {
    year: withYear ? 'numeric' : undefined,
    month: 'short',
    day: 'numeric',
  }).format(new Date(ms));
}

export function fmtLongDate(ms: number, lang: string): string {
  return new Intl.DateTimeFormat(localeOf(lang), { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' }).format(
    new Date(ms),
  );
}

export function hhmm(ms: number): string {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

// "Ft" only reads right in hungarian, english writes the code up front, german after
export function fmtMoney(amount: number, lang: string): string {
  const n = new Intl.NumberFormat(localeOf(lang), { maximumFractionDigits: 0 }).format(Math.abs(amount));
  const sign = amount < 0 ? '-' : '';
  if (lang === 'en') return `${sign}HUF ${n}`;
  return `${sign}${n} ${lang === 'hu' ? 'Ft' : 'HUF'}`;
}

// Whole calendar days from today to the given moment (negative in the past).
export function daysFromToday(ms: number, now = Date.now()): number {
  const a = new Date(now);
  a.setHours(0, 0, 0, 0);
  const b = new Date(ms);
  b.setHours(0, 0, 0, 0);
  return Math.round((b.getTime() - a.getTime()) / DAY_MS);
}

export function sameDay(a: number, b: number): boolean {
  return new Date(a).toDateString() === new Date(b).toDateString();
}

// "1:05" for durations, hours and minutes, rounded up so a running class never shows 0:00.
export function fmtDuration(ms: number): string {
  const totalMin = Math.max(0, Math.ceil(ms / 60000));
  return `${Math.floor(totalMin / 60)}:${String(totalMin % 60).padStart(2, '0')}`;
}

export function fmtAvg(v: number): string {
  return v > 0 ? v.toFixed(2) : '-';
}

// Same reaction scale as the Android app.
export function avgEmoji(v: number): string {
  if (v >= 5) return '💀';
  if (v >= 4.25) return '🤓';
  if (v >= 3.75) return '😌';
  if (v >= 2.75) return '😐';
  if (v >= 2) return '😬';
  if (v > 0) return '🤡';
  return '🤗';
}

export function nowMs(): number {
  return Date.now();
}
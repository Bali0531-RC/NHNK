import type { V2Strings } from '@/i18n/v2-strings';
import type { DetailRow } from '@/neptun/data';

export type Who = 'm' | 'f' | null;

// js \b doesnt know accented letters, so the word edges are spelled out
const word = (w: string) => new RegExp(`(^|[^a-zà-ÿőű])(${w})($|[^a-zà-ÿőű])`);
const FEMALE = word('nő|női|female|woman|weiblich|frau');
const MALE = word('férfi|ferfi|male|man|männlich|mann');

// neptun hands over gender in the personal data. anything we cant read gets the neutral one
export function genderOf(rows: DetailRow[] | undefined): Who {
  const row = rows?.find((r) => /(^|\.)(gender|sex)\w*$/i.test(r.key ?? ''));
  const v = row?.value.trim().toLowerCase() ?? '';
  if (FEMALE.test(v)) return 'f';
  if (MALE.test(v)) return 'm';
  return null;
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

// last half hour of a class. random per class, but it doesnt flicker every tick
export function pickCheer(s: V2Strings['cheer'], who: Who, id: string, leftMs: number): string | null {
  const min = leftMs / 60_000;
  if (min > 30 || min <= 0) return null;
  const last = min <= 10;
  const pool = last ? s.last : s.soon;
  const title = who === 'f' ? s.queen : who === 'm' ? s.king : s.champ;
  return `${who ? '👑' : '💪'} ${pool[hash(`${id}${last}`) % pool.length](title)}`;
}
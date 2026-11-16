// The institution list is not bundled; it is a JSON file in the NHNK repo so new schools
// can be added without an app release. Same source the Flutter app reads.

import { fetchWithTimeout } from './http';
import type { Institute } from './types';

const INSTITUTES_URL =
  'https://raw.githubusercontent.com/Bali0531-RC/NHNK/refs/heads/main/universityNameUrlPairs.json';

export async function fetchInstitutes(): Promise<Institute[]> {
  const res = await fetchWithTimeout(INSTITUTES_URL, {}, 8000);
  if (!res.ok) return [];

  const json = (await res.json()) as { Institutes?: unknown };
  const list = json?.Institutes;
  if (!Array.isArray(list)) return [];

  const out: Institute[] = [];
  for (const item of list) {
    const name: unknown = item?.Name;
    const url: unknown = item?.Url ?? 'NULL';
    const rawFallbacks: unknown = item?.Fallbacks;
    const fallbacks = Array.isArray(rawFallbacks)
      ? rawFallbacks.filter((e): e is string => typeof e === 'string' && e.trim() !== '')
      : [];
    // Drop the DEMO sentinel and the dead "NULL" rows, matching getDataFromInstitutesJSON.
    if (typeof name === 'string' && typeof url === 'string' && url !== 'NULL' && name !== 'DEMO') {
      out.push({ name, url, fallbacks });
    }
  }
  return out;
}

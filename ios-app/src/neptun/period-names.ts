import type { Lang } from '@/i18n/strings';

type Row = [hu: RegExp, en: string, de: string];

// longest first so "vizsgajelentkezési időszak" wins over "vizsgaidőszak"
const ROWS: Row[] = [
  [/végleges tárgyjelentkezés(i időszak)?/giu, 'Final course registration', 'Endgültige Fachanmeldung'],
  [/előzetes tárgyjelentkezés(i időszak)?/giu, 'Preliminary course registration', 'Vorläufige Fachanmeldung'],
  [/tárgyjelentkezési időszak|tárgyfelvételi időszak|tárgyjelentkezés|tárgyfelvétel/giu, 'Course registration', 'Fachanmeldung'],
  [/kurzusjelentkezési időszak|kurzusjelentkezés/giu, 'Course enrolment', 'Kursanmeldung'],
  [/vizsgajelentkezési időszak|vizsgajelentkezés/giu, 'Exam registration period', 'Prüfungsanmeldezeitraum'],
  [/záróvizsga[- ]?időszak/giu, 'Final exam period', 'Abschlussprüfungszeit'],
  [/vizsgaidőszak/giu, 'Exam period', 'Prüfungszeit'],
  [/szorgalmi időszak|oktatási időszak|tanítási időszak/giu, 'Study period', 'Vorlesungszeit'],
  [/bejelentkezési időszak/giu, 'Registration period', 'Anmeldezeitraum'],
  [/regisztrációs időszak/giu, 'Registration period', 'Registrierungszeitraum'],
  [/regisztrációs hét/giu, 'Registration week', 'Registrierungswoche'],
  [/pótlási hét/giu, 'Make-up week', 'Nachholwoche'],
  [/pótlási időszak/giu, 'Make-up period', 'Nachholzeitraum'],
  [/kérvényleadási időszak/giu, 'Request period', 'Antragszeitraum'],
  [/őszi szünet/giu, 'Autumn break', 'Herbstferien'],
  [/téli szünet/giu, 'Winter break', 'Winterferien'],
  [/tavaszi szünet/giu, 'Spring break', 'Frühlingsferien'],
  [/rektori szünet/giu, "Rector's day off", 'Rektorstag'],
  [/dékáni szünet/giu, "Dean's day off", 'Dekanstag'],
  [/oktatási szünet/giu, 'Teaching break', 'Vorlesungsfreie Zeit'],
];

// unis rarely fill english/german period names, so patch the usual hungarian ones
export function localizePeriodName(name: string, lang: Lang): string {
  if (lang === 'hu') return name;
  const i = lang === 'en' ? 1 : 2;
  let out = name;
  for (const row of ROWS) out = out.replace(row[0], row[i]);
  return out === name ? name : out.replace(/\s+/g, ' ').trim();
}
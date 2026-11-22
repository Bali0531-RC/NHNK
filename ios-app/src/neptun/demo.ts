// demo account only, real accounts never touch this. reviewer gets every screen filled, in their language
import type {
  ClassEntry,
  CollectiveAccount,
  CreditProgress,
  DetailRow,
  DocumentKind,
  ListItem,
  MessageEntry,
  PaymentEntry,
  PeriodEntry,
  Profile,
  SubjectEntry,
  Term,
} from './data';
import { neptunLangSync } from './lang';
import { academicTermAt, previousTerm, termLabel, windowOf, type AcademicTerm } from './term-window';

const DAY = 86400000;

type Tri = [hu: string, en: string, de: string];

function L([hu, en, de]: Tri): string {
  const lang = neptunLangSync();
  return lang === 'en' ? en : lang === 'de' ? de : hu;
}

function at(dayOffset: number, h: number, m = 0): number {
  const d = new Date();
  d.setDate(d.getDate() + dayOffset);
  d.setHours(h, m, 0, 0);
  return d.getTime();
}

function weekDay(weekOffset: number, weekday: number, h: number, m = 0): number {
  const d = new Date();
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7) + weekOffset * 7 + weekday);
  d.setHours(h, m, 0, 0);
  return d.getTime();
}

// names follow the calendar so the demo never goes stale: t3 is whatever runs today, t1 and t2 are behind it
function demoTerms(): { id: string; term: AcademicTerm }[] {
  const t3 = academicTermAt(Date.now());
  const t2 = previousTerm(t3);
  return [
    { id: 'demo-t1', term: previousTerm(t2) },
    { id: 'demo-t2', term: t2 },
    { id: 'demo-t3', term: t3 },
  ];
}

function termStart(id: string): number {
  const hit = demoTerms().find((x) => x.id === id) ?? demoTerms()[2];
  return windowOf(hit.term).fromMs;
}

// current ones are relative to today, pin them inside the running term so they never leak into the last one
function inCurrent(ms: number): number {
  const w = windowOf(academicTermAt(Date.now()));
  return Math.min(Math.max(ms, w.fromMs + DAY), w.toMs - DAY);
}

const N = {
  analysis: ['Analízis I.', 'Calculus I', 'Analysis I'] as Tri,
  prog: ['Programozás I.', 'Programming I', 'Programmierung I'] as Tri,
  linalg: ['Lineáris algebra', 'Linear Algebra', 'Lineare Algebra'] as Tri,
  physics: ['Fizika', 'Physics', 'Physik'] as Tri,
  discrete: ['Diszkrét matematika', 'Discrete Mathematics', 'Diskrete Mathematik'] as Tri,
  arch: ['Számítógép architektúrák', 'Computer Architecture', 'Rechnerarchitektur'] as Tri,
  lecture: ['Előadás', 'Lecture', 'Vorlesung'] as Tri,
  practice: ['Gyakorlat', 'Practice', 'Übung'] as Tri,
  office: ['Fogadóóra: Dr. Kovács Anna', 'Office hours: Dr. Anna Kovács', 'Sprechstunde: Dr. Anna Kovács'] as Tri,
  studyOffice: ['Tanulmányi Osztály', 'Registrar’s Office', 'Studienbüro'] as Tri,
  committee: ['Tanulmányi Bizottság', 'Academic Committee', 'Studienausschuss'] as Tri,
  enrollmentCert: ['Hallgatói jogviszony igazolás', 'Certificate of enrollment', 'Immatrikulationsbescheinigung'] as Tri,
  equity: ['Méltányossági kérelem', 'Request for special consideration', 'Härtefallantrag'] as Tri,
  accepted: ['Elfogadva', 'Accepted', 'Angenommen'] as Tri,
};

type Slot = [day: number, start: number, end: number, title: Tri, room: string, teacher: string, code: string, type: Tri | null, kind?: 'other'];

const WEEK: Slot[] = [
  [0, 8, 10, N.analysis, 'B-204', 'Dr. Kovács Anna', 'MAT101', N.lecture],
  [0, 10, 12, N.prog, 'Lab-3', 'Nagy Péter', 'INF110', N.practice],
  [1, 9, 11, N.linalg, 'A-101', 'Dr. Szabó Gábor', 'MAT120', N.lecture],
  [1, 12, 14, N.physics, 'C-012', 'Dr. Tóth Éva', 'FIZ100', N.lecture],
  [2, 8, 10, N.prog, 'Lab-3', 'Nagy Péter', 'INF110', N.lecture],
  [2, 10, 12, N.discrete, 'B-110', 'Dr. Kiss László', 'MAT130', N.practice],
  [2, 14, 16, N.discrete, 'B-204', 'Dr. Kiss László', 'MAT130', N.lecture],
  [2, 16, 18, N.analysis, 'B-110', 'Dr. Kovács Anna', 'MAT101', N.practice],
  [3, 10, 12, N.analysis, 'B-110', 'Dr. Kovács Anna', 'MAT101', N.practice],
  [3, 13, 14, N.office, 'B-302', 'Dr. Kovács Anna', '', null, 'other'],
  [4, 9, 11, N.arch, 'A-205', 'Dr. Farkas Zoltán', 'INF140', N.lecture],
];

const COMMENTS: Record<number, Tri> = {
  0: [
    'Az első két héten a B-204 helyett az A-001-es előadóban tartjuk az órát.',
    'For the first two weeks the class is in lecture hall A-001 instead of B-204.',
    'In den ersten zwei Wochen findet die Vorlesung im Hörsaal A-001 statt in B-204 statt.',
  ],
  1: ['Hozz laptopot, ZH a 10. héten.', 'Bring a laptop, midterm in week 10.', 'Laptop mitbringen, Zwischentest in Woche 10.'],
  6: ['A terem a 2. emeleten van, a lift mellett.', 'The room is on the 2nd floor next to the elevator.', 'Der Raum ist im 2. Stock neben dem Aufzug.'],
  9: ['Előzetes e-mailes egyeztetés alapján.', 'By appointment, email me first.', 'Nach vorheriger Absprache per E-Mail.'],
};

const SUBJECT_NOTES: Record<string, Tri> = {
  c1: [
    'A zárthelyi dolgozatok időpontjai a tárgy Moodle-oldalán találhatók.',
    'Midterm dates are on the course Moodle page.',
    'Die Termine der Zwischentests stehen auf der Moodle-Seite des Fachs.',
  ],
};

const item = (id: string, title: string, subtitle: string, dateMs: number, status: string, rows: DetailRow[] = []): ListItem => ({
  id,
  title,
  subtitle,
  dateMs,
  status,
  rows,
});

const SCHEDULE_TABLE: Tri = [
  `<p>Kedves Hallgató!</p>
<p>Az alábbi kurzusok órarendje <b>megváltozott</b>:</p>
<table>
<tr><th>Tárgy</th><th>Kurzus</th><th>Régi időpont</th><th>Új időpont</th><th>Terem</th></tr>
<tr><td>Programozás I.</td><td>INF110-GY01</td><td>Hétfő 10:00-12:00</td><td>Hétfő 12:00-14:00</td><td>Lab-3</td></tr>
<tr><td>Fizika</td><td>FIZ100-EA</td><td>Kedd 12:00-14:00</td><td>Kedd 14:00-16:00</td><td>C-012</td></tr>
</table>
<p><i>Ez automatikus üzenet, kérjük ne válaszolj rá.</i></p>`,
  `<p>Dear Student,</p>
<p>The schedule of the following courses has <b>changed</b>:</p>
<table>
<tr><th>Subject</th><th>Course</th><th>Old time</th><th>New time</th><th>Room</th></tr>
<tr><td>Programming I</td><td>INF110-GY01</td><td>Mon 10:00-12:00</td><td>Mon 12:00-14:00</td><td>Lab-3</td></tr>
<tr><td>Physics</td><td>FIZ100-EA</td><td>Tue 12:00-14:00</td><td>Tue 14:00-16:00</td><td>C-012</td></tr>
</table>
<p><i>This is an automatic message, please do not reply.</i></p>`,
  `<p>Liebe Studierende,</p>
<p>der Stundenplan folgender Kurse hat sich <b>geändert</b>:</p>
<table>
<tr><th>Fach</th><th>Kurs</th><th>Alte Zeit</th><th>Neue Zeit</th><th>Raum</th></tr>
<tr><td>Programmierung I</td><td>INF110-GY01</td><td>Mo 10:00-12:00</td><td>Mo 12:00-14:00</td><td>Lab-3</td></tr>
<tr><td>Physik</td><td>FIZ100-EA</td><td>Di 12:00-14:00</td><td>Di 14:00-16:00</td><td>C-012</td></tr>
</table>
<p><i>Dies ist eine automatische Nachricht, bitte nicht antworten.</i></p>`,
];

const EXAMS: Tri = [
  `<p>Kedves Hallgatók!</p>
<p>A vizsgaidőpontok <b>felkerültek</b> a Neptunba. Jelentkezni a <u>vizsgajelentkezési időszakban</u> lehet.</p>
<ul><li>1. vizsga: január 8.</li><li>2. vizsga: január 15.</li><li>Utóvizsga: január 29.</li></ul>
<p>Részletek a tanszéki oldalon: <a href="https://example.com">example.com</a></p>
<p>Üdvözlettel,<br><i>Dr. Kiss László</i></p>`,
  `<p>Dear Students,</p>
<p>The exam dates are <b>now in Neptun</b>. You can sign up during the <u>exam registration period</u>.</p>
<ul><li>1st exam: January 8</li><li>2nd exam: January 15</li><li>Retake: January 29</li></ul>
<p>Details on the department page: <a href="https://example.com">example.com</a></p>
<p>Best regards,<br><i>Dr. László Kiss</i></p>`,
  `<p>Liebe Studierende,</p>
<p>die Prüfungstermine <b>stehen jetzt im Neptun</b>. Die Anmeldung ist im <u>Prüfungsanmeldezeitraum</u> möglich.</p>
<ul><li>1. Prüfung: 8. Januar</li><li>2. Prüfung: 15. Januar</li><li>Wiederholung: 29. Januar</li></ul>
<p>Details auf der Seite des Lehrstuhls: <a href="https://example.com">example.com</a></p>
<p>Viele Grüße,<br><i>Dr. László Kiss</i></p>`,
];

function fromSlot([, , , title, room, teacher, code, type, kind]: Slot, i: number, startMs: number, endMs: number, id: string): ClassEntry {
  return {
    id,
    startMs,
    endMs,
    title: L(title),
    location: room,
    teacher,
    code,
    kind: kind ?? 'class',
    courseType: type ? L(type) : '',
    classInstanceId: kind ? '' : `demo-ci-${i}`,
    note: COMMENTS[i] ? L(COMMENTS[i]) : '',
  };
}

// today always tells the whole story on the real clock: one class done, one running, a zh in the evening. nights stay quiet
function hero(): { first: number; live: number; examMs: number } | null {
  const h = new Date().getHours();
  if (h < 8 || h >= 20) return null;
  const live = Math.max(10, h - 1);
  return { first: live - 2, live, examMs: at(0, Math.max(18, live + 3)) };
}

const subject = (id: string, name: Tri, code: string, credit: number, grade: number, completed: boolean, passFail = false): SubjectEntry => ({
  id,
  name: L(name),
  code,
  credit,
  grade,
  completed,
  passFail,
  requirement: '',
  resultText: '',
  details: SUBJECT_NOTES[id] ? [{ label: '', key: 'comment', value: L(SUBJECT_NOTES[id]) }] : [],
});

export const demo = {
  week(weekOffset: number): ClassEntry[] {
    const all = WEEK.map((slot, i) => fromSlot(slot, i, weekDay(weekOffset, slot[0], slot[1]), weekDay(weekOffset, slot[0], slot[2]), `demo-${weekOffset}-${i}`));
    const h = weekOffset === 0 ? hero() : null;
    if (!h) return all;
    const from = at(0, 0);
    const to = at(1, 0);
    const today = [
      fromSlot(WEEK[4], 4, at(0, h.first), at(0, h.first + 2), 'demo-hero-4'),
      fromSlot(WEEK[5], 5, at(0, h.live), at(0, h.live + 2), 'demo-hero-5'),
    ];
    return [...all.filter((e) => e.startMs < from || e.startMs >= to), ...today].sort((a, b) => a.startMs - b.startMs);
  },
  hero,
  examTitles(): Tri {
    return ['Analízis ZH', 'Calculus midterm', 'Analysis-Zwischentest'];
  },
  upcoming(): ClassEntry[] {
    const exam = (t: Tri): Tri => [`${t[0]} vizsga`, `${t[1]} exam`, `Prüfung ${t[2]}`];
    return [
      { id: 'demo-u1', startMs: at(2, 23, 59), endMs: at(2, 23, 59), title: L(['Beadandó: Programozás I.', 'Assignment: Programming I', 'Abgabe: Programmierung I']), location: '', teacher: 'Nagy Péter', code: 'INF110', kind: 'task', courseType: '', classInstanceId: '', note: '' },
      { id: 'demo-u2', startMs: at(10, 10), endMs: at(10, 12), title: L(exam(N.discrete)), location: 'A-105', teacher: '', code: 'MAT130', kind: 'exam', courseType: '', classInstanceId: '', note: '' },
      { id: 'demo-u3', startMs: at(25, 14), endMs: at(25, 16), title: L(exam(N.arch)), location: 'A-201', teacher: '', code: 'INF140', kind: 'exam', courseType: '', classInstanceId: '', note: '' },
    ];
  },
  terms(): Term[] {
    return demoTerms().map(({ id, term }) => ({ id, name: termLabel(term) }));
  },
  subjects(termId: string): SubjectEntry[] {
    if (termId === 'demo-t1') {
      return [
        subject('a1', ['Bevezetés a programozásba', 'Introduction to Programming', 'Einführung in die Programmierung'], 'INF100', 6, 4, true),
        subject('a2', ['Kalkulus', 'Calculus', 'Infinitesimalrechnung'], 'MAT100', 6, 3, true),
        subject('a3', ['Digitális technika', 'Digital Electronics', 'Digitaltechnik'], 'INF105', 5, 4, true),
      ];
    }
    if (termId === 'demo-t2') {
      return [
        subject('b1', ['Operációs rendszerek', 'Operating Systems', 'Betriebssysteme'], 'INF160', 5, 5, true),
        subject('b2', ['Statisztika', 'Statistics', 'Statistik'], 'MAT150', 4, 4, true),
        subject('b3', ['Testnevelés', 'Physical Education', 'Sport'], 'TES100', 0, 0, true, true),
      ];
    }
    return [
      subject('c1', N.analysis, 'MAT101', 6, 0, false),
      subject('c2', N.prog, 'INF110', 5, 0, false),
      subject('c3', N.discrete, 'MAT130', 4, 0, false),
      subject('c4', N.arch, 'INF140', 4, 3, true),
      subject('c6', N.physics, 'FIZ100', 4, 5, true),
      subject('c5', ['Szakmai angol', 'Technical English', 'Fachenglisch'], 'LAN200', 2, 0, true, true),
    ];
  },
  creditProgress(): CreditProgress {
    return { completed: 36, required: 180 };
  },
  payments(): PaymentEntry[] {
    const paid = L(['Teljesített', 'Completed', 'Erledigt']);
    const out = L(['Kiutalva', 'Paid out', 'Ausgezahlt']);
    const t1 = termStart('demo-t1');
    const t2 = termStart('demo-t2');
    return [
      { id: 'p1', amount: 10000, dateMs: at(30, 12), title: L(['DEMO befizetés', 'DEMO payment', 'DEMO-Zahlung']), status: L(['Aktív', 'Active', 'Aktiv']), done: false, kind: '' },
      { id: 'p2', amount: -30000, dateMs: inCurrent(at(-12, 12)), title: L(['Ösztöndíj kifizetés', 'Scholarship payout', 'Stipendiumsauszahlung']), status: out, done: true, kind: '' },
      { id: 'p3', amount: 70, dateMs: inCurrent(at(-40, 12)), title: L(['Igazolás díja', 'Certificate fee', 'Bescheinigungsgebühr']), status: paid, done: true, kind: '' },
      { id: 'p4', amount: -38000, dateMs: t2 + 60 * DAY, title: L(['Tanulmányi ösztöndíj', 'Merit scholarship', 'Leistungsstipendium']), status: out, done: true, kind: '' },
      { id: 'p5', amount: 2500, dateMs: t2 + 20 * DAY, title: L(['Késedelmi díj', 'Late fee', 'Verspätungsgebühr']), status: paid, done: true, kind: '' },
      { id: 'p6', amount: -42000, dateMs: t1 + 70 * DAY, title: L(['Tanulmányi ösztöndíj', 'Merit scholarship', 'Leistungsstipendium']), status: out, done: true, kind: '' },
      { id: 'p7', amount: 15000, dateMs: t1 + 45 * DAY, title: L(['Kollégiumi díj', 'Dormitory fee', 'Wohnheimgebühr']), status: paid, done: true, kind: '' },
    ];
  },
  periods(): PeriodEntry[] {
    return [
      { name: L(['Végleges tárgyjelentkezés', 'Final course registration', 'Endgültige Fachanmeldung']), fromMs: Date.now() - 80 * DAY, toMs: Date.now() - 70 * DAY },
      { name: L(['Vizsgajelentkezési időszak', 'Exam registration period', 'Prüfungsanmeldezeitraum']), fromMs: Date.now() - 2 * DAY, toMs: Date.now() + 8 * DAY },
      { name: L(['Vizsgaidőszak', 'Exam period', 'Prüfungszeit']), fromMs: Date.now() + 30 * DAY, toMs: Date.now() + 70 * DAY },
    ];
  },
  // past terms get a full, finished calendar so the grayed out list has something to show
  termPeriods(termId: string): PeriodEntry[] {
    if (termId === 'demo-t3' || !demoTerms().some((x) => x.id === termId)) return demo.periods();
    const fall = demoTerms().find((x) => x.id === termId)?.term.sem === 1;
    const start = termStart(termId) + (fall ? 31 : 8) * DAY;
    const span = (a: number, b: number) => ({ fromMs: start + a * DAY, toMs: start + b * DAY });
    return [
      { name: L(['Bejelentkezési időszak', 'Registration period', 'Anmeldezeitraum']), ...span(-14, 6) },
      { name: L(['Végleges tárgyjelentkezés', 'Final course registration', 'Endgültige Fachanmeldung']), ...span(-7, 6) },
      { name: L(['Szorgalmi időszak', 'Study period', 'Vorlesungszeit']), ...span(0, 91) },
      { name: L(['Vizsgajelentkezési időszak', 'Exam registration period', 'Prüfungsanmeldezeitraum']), ...span(84, 133) },
      { name: L(['Vizsgaidőszak', 'Exam period', 'Prüfungszeit']), ...span(98, 140) },
    ];
  },
  messages(): MessageEntry[] {
    return [
      { id: 'dm4', subject: L(['Kurzus órarendi változás', 'Course schedule change', 'Änderung im Kursplan']), sender: '', dateMs: at(0, 7, 30), isRead: false, hasAttachment: false },
      { id: 'dm1', subject: L(['Kérvény státusza megváltozott', 'Your request status changed', 'Antragsstatus geändert']), sender: L(N.studyOffice), dateMs: at(-1, 9), isRead: false, hasAttachment: false },
      { id: 'dm2', subject: L(['Vizsgaidőpontok meghirdetve', 'Exam dates announced', 'Prüfungstermine veröffentlicht']), sender: 'Dr. Kiss László', dateMs: at(-3, 14), isRead: false, hasAttachment: true },
      { id: 'dm3', subject: L(['Órarendváltozás', 'Schedule change', 'Stundenplanänderung']), sender: 'Nagy Péter', dateMs: at(-8, 11), isRead: true, hasAttachment: false },
    ];
  },
  messageBody(id: string): string {
    if (id === 'dm4') return L(SCHEDULE_TABLE);
    if (id === 'dm2') return L(EXAMS);
    return L([
      'Ez egy demó üzenet. Demó módban semmi nem megy a Neptunba.',
      'This is a demo message. Nothing is sent to Neptun in demo mode.',
      'Dies ist eine Demo-Nachricht. Im Demo-Modus geht nichts an Neptun.',
    ]);
  },
  courseDetails(classInstanceId: string): DetailRow[] {
    const i = Number(classInstanceId.replace('demo-ci-', ''));
    const slot = WEEK[i];
    if (!slot) return [];
    const rows: DetailRow[] = [
      { label: '', key: 'subjectName', value: L(slot[3]) },
      { label: '', key: 'subjectCode', value: slot[6] },
      { label: '', key: 'courseTypeName', value: slot[7] ? L(slot[7]) : '' },
      { label: '', key: 'courseTutors', value: slot[5] },
      { label: '', key: 'classroom', value: slot[4] },
      { label: '', key: 'teachingMethod', value: L(['Jelenléti', 'In person', 'Präsenz']) },
      { label: '', key: 'headcount', value: '42' },
      { label: '', key: 'maxHeadcount', value: '60' },
      { label: '', key: 'onWaitingList', value: '✕' },
    ];
    const note = COMMENTS[i];
    if (note) rows.push({ label: '', key: 'comment', value: L(note) });
    return rows;
  },
  profile(): Profile {
    return {
      name: L(['Demo Hallgató', 'Demo Student', 'Demo Student']),
      code: 'DEMO01',
      avatar: null,
      rows: [
        { label: '', key: 'birthName', value: L(['Demo Hallgató', 'Demo Student', 'Demo Student']) },
        { label: '', key: 'birthDate', value: '2004. 05. 12.' },
        { label: '', key: 'birthPlace', value: 'Budapest' },
        { label: '', key: 'mothersName', value: 'Minta Mária' },
        { label: '', key: 'nationality', value: L(['Magyarország', 'Hungary', 'Ungarn']) },
        { label: '', key: 'email', value: 'demo@example.com' },
        { label: '', key: 'trainingName', value: L(['Programtervező informatikus BSc', 'Computer Science BSc', 'Informatik BSc']) },
        { label: '', key: 'financingForm', value: L(['Állami ösztöndíjas', 'State scholarship', 'Staatliches Stipendium']) },
      ],
      documents: [
        [
          { label: '', key: 'documentType', value: L(['Személyazonosító igazolvány', 'Identity card', 'Personalausweis']) },
          { label: '', key: 'documentNumber', value: '000000DE' },
          { label: '', key: 'validTo', value: '2031. 05. 12.' },
        ],
      ],
      bankAccount: '12345678-12345678-12345678',
    };
  },
  collectiveAccount(): CollectiveAccount {
    return { balance: 12500, currency: 'HUF', bankAccount: '12345678-87654321-00000000' };
  },
  requestTemplates(): ListItem[] {
    return [
      item('rt1', L(N.enrollmentCert), L(N.studyOffice), 0, ''),
      item('rt2', L(N.equity), L(N.committee), 0, ''),
      item('rt3', L(['Szociális ösztöndíj pályázat', 'Need-based scholarship application', 'Antrag auf Sozialstipendium']), L(['HÖK', 'Student Union', 'Studierendenvertretung']), at(14, 23, 59), ''),
    ];
  },
  submittedRequests(): ListItem[] {
    return [
      item('rs1', L(N.enrollmentCert), L(N.studyOffice), at(-6, 10), L(N.accepted), [
        { label: '', key: 'requestFormIdentifier', value: 'K-2026-0412' },
        { label: '', key: 'status', value: L(N.accepted) },
      ]),
      item('rs2', L(N.equity), L(N.committee), at(-2, 15), L(['Elbírálás alatt', 'Under review', 'In Bearbeitung'])),
    ];
  },
  documents(kind: DocumentKind): ListItem[] {
    if (kind === 'official') {
      return [
        item('do1', L(N.enrollmentCert), L(N.studyOffice), at(-6, 11), L(['Hitelesített', 'Certified', 'Beglaubigt']), [
          { label: '', key: 'documentationType', value: L(['Igazolás', 'Certificate', 'Bescheinigung']) },
          { label: '', key: 'registrationNumber', value: 'IG-2026-1187' },
        ]),
      ];
    }
    if (kind === 'uploaded') {
      return [
        item('du1', L(['Nyelvvizsga bizonyítvány', 'Language exam certificate', 'Sprachprüfungszeugnis']), L(['Saját feltöltés', 'Uploaded by you', 'Eigener Upload']), at(-30, 9), L(N.accepted), [
          { label: '', key: 'size', value: '1.2 MB' },
        ]),
      ];
    }
    return [item('dt1', L(['Félévzáró igazolás 2025/26/2', 'End of term certificate 2025/26/2', 'Semesterabschlussbescheinigung 2025/26/2']), L(['Tanulmányi Rendszer', 'Student records', 'Studienverwaltung']), at(-120, 9), L(['Kiállítva', 'Issued', 'Ausgestellt']))];
  },
  questionnaires(finished: boolean): ListItem[] {
    const omhv = (term: string): string =>
      L([`Oktatói munka hallgatói véleményezése ${term}`, `Student evaluation of teaching ${term}`, `Lehrevaluation ${term}`]);
    return finished
      ? [item('qf1', omhv('2025/26/2'), 'OMHV', at(-150, 12), L(['Kitöltve', 'Completed', 'Ausgefüllt']))]
      : [
          item('qo1', omhv('2026/27/1'), 'OMHV', at(20, 23, 59), L(['Kitölthető', 'Open', 'Offen'])),
          item('qo2', L(['Kollégiumi elégedettségi felmérés', 'Dorm satisfaction survey', 'Wohnheim-Zufriedenheitsumfrage']), L(['Kollégium', 'Dorm', 'Wohnheim']), at(9, 23, 59), L(['Kitölthető', 'Open', 'Offen'])),
        ];
  },
};
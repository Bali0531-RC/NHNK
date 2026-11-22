// typed neptun reads, throws NeptunError so the cache can step in. demo never hits the network

import { apiGet, apiPost, NeptunError, sessionGeneration } from './client';
import { demo } from './demo';
import { neptunLang } from './lang';
import { log } from './log';
import { localizePeriodName } from './period-names';
import { Store } from './storage';
import { academicTermAt, parseTermName, windowOf } from './term-window';

type Json = Record<string, unknown>;

export type EventKind = 'class' | 'exam' | 'task' | 'other';

export type ClassEntry = {
  id: string;
  startMs: number;
  endMs: number;
  title: string;
  location: string;
  teacher: string;
  code: string;
  kind: EventKind;
  courseType: string;
  classInstanceId: string;
  note: string; // prof's free text, sometimes the only place the real room is
};

export type Term = { id: string; name: string };

export type SubjectEntry = {
  id: string;
  name: string;
  code: string;
  credit: number;
  grade: number; // 0 = none yet, 1..5
  completed: boolean;
  passFail: boolean; // "megfelelt" style result, shown as a tick
  requirement: string; // "Vizsga", "Évközi jegy", ...
  resultText: string;
  details: DetailRow[]; // every readable field Neptun returned for this subject
};

export type DetailRow = { label: string; value: string; key?: string };

export type PaymentEntry = {
  id: string;
  kind: string;
  amount: number; // > 0 the student pays, < 0 a payout to the student
  dateMs: number;
  title: string;
  status: string;
  done: boolean;
};

export type PeriodEntry = { name: string; fromMs: number; toMs: number };

export type MessageEntry = {
  id: string;
  subject: string;
  sender: string;
  dateMs: number;
  isRead: boolean;
  hasAttachment: boolean;
};

export type CreditProgress = { completed: number; required: number };

// ---- helpers --------------------------------------------------------------------------

function str(v: unknown, fallback = ''): string {
  return typeof v === 'string' && v.trim().length > 0 ? v.trim() : fallback;
}

function num(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function parseIso(v: unknown): number {
  const ms = typeof v === 'string' ? Date.parse(v) : NaN;
  return Number.isNaN(ms) ? 0 : ms;
}

function list(v: unknown): Json[] {
  return Array.isArray(v) ? (v.filter((x) => x && typeof x === 'object') as Json[]) : [];
}

const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;

function humanize(key: string): string {
  const words = key
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/[_.]+/g, ' ')
    .trim()
    .toLowerCase();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function formatValue(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  if (typeof v === 'boolean') return v ? '✓' : '✕';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : null;
  if (typeof v !== 'string') return null;
  const t = v.trim();
  if (!t || GUID.test(t) || t === '-') return null;
  if (ISO_DATE.test(t)) {
    const ms = Date.parse(t);
    if (!Number.isNaN(ms) && new Date(ms).getFullYear() > 1900) {
      const d = new Date(ms);
      const hasTime = d.getHours() !== 0 || d.getMinutes() !== 0;
      return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}.${hasTime ? ` ${pad(d.getHours())}:${pad(d.getMinutes())}` : ''}`;
    }
  }
  return t.replace(/<[^>]+>/g, '').trim() || null;
}

// Every readable scalar in a Neptun object, nested objects one level deep, ids left out.
export function detailRows(obj: unknown, prefix = '', depth = 0, prefixKey = ''): DetailRow[] {
  if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return [];
  const rows: DetailRow[] = [];
  for (const [k, v] of Object.entries(obj as Json)) {
    if (/(^id$|Id$|Ids$|uiDisplayState|[Pp]ermission|Enabled$)/.test(k)) continue;
    const label = prefix ? `${prefix} · ${humanize(k)}` : humanize(k);
    const key = prefixKey ? `${prefixKey}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      if (depth < 1) rows.push(...detailRows(v, humanize(k), depth + 1, k));
      continue;
    }
    if (Array.isArray(v)) {
      const parts = v
        .map((x) => (x && typeof x === 'object' ? str((x as Json).name) || str((x as Json).text) : formatValue(x)))
        .filter(Boolean);
      if (parts.length) rows.push({ label, key, value: parts.join(', ') });
      continue;
    }
    const value = formatValue(v);
    if (value) rows.push({ label, key, value });
  }
  return rows;
}

function pad(n: number): string {
  return String(n).padStart(2, '0');
}

// Local wall-clock ISO with milliseconds and no zone, the format the Flutter client sends.
function localIso(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.000`;
}

export function mondayOf(weekOffset: number, now = new Date()): Date {
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7) + weekOffset * 7);
  monday.setHours(0, 0, 0, 0);
  return monday;
}

// grade words in all three neptun languages. last one wins, so "elégtelen, javítva: jó" reads 4
const GRADE_WORDS: [string, number][] = [
  ['elégtelen', 1], ['elégséges', 2], ['közepes', 3], ['jó', 4], ['jeles', 5], ['megfelelt', 5],
  ['unsatisfactory', 1], ['insufficient', 1], ['fail', 1], ['failed', 1], ['sufficient', 2], ['pass', 2],
  ['satisfactory', 3], ['average', 3], ['good', 4], ['very good', 5], ['excellent', 5], ['passed', 5],
  ['ungenügend', 1], ['nicht bestanden', 1], ['genügend', 2], ['ausreichend', 2], ['befriedigend', 3],
  ['gut', 4], ['sehr gut', 5], ['ausgezeichnet', 5], ['bestanden', 5],
];
const GRADE_MAP = new Map(GRADE_WORDS);
const GRADE_RE = new RegExp(
  `(?<!\\p{L})(${[...GRADE_MAP.keys()].sort((a, b) => b.length - a.length).join('|')})(?!\\p{L})`,
  'gu',
);
const PASS_FAIL = /megfelelt|passed|satisfied|bestanden|erfüllt/i;
const DONE_STATUS = /^(teljesített|completed|fulfilled|erfüllt|abgeschlossen)$/i;

export function parseTextGrade(text: string): number {
  let grade = 0;
  for (const m of text.toLowerCase().matchAll(GRADE_RE)) grade = GRADE_MAP.get(m[1]) ?? grade;
  return grade;
}

async function isDemo(): Promise<boolean> {
  return Store.getIsDemo();
}

// ---- training id (calendar dependency) ----------------------------------------------

let trainingId: { id: string; gen: number } | null = null;

export function invalidateTrainingId(): void {
  trainingId = null;
}

async function getStudentTrainingId(): Promise<string> {
  const gen = sessionGeneration();
  if (trainingId && trainingId.gen === gen) return trainingId.id;
  const data = list(await apiGet<unknown>('Calendar/GetStudentTrainings'));
  const pick = data.find((t) => t.actualStudentTraining === true) ?? data[0];
  const id = pick ? str(pick.studentTrainingId) : '';
  if (!id) throw new Error('no studentTrainingId');
  trainingId = { id, gen: sessionGeneration() };
  return id;
}

// ---- calendar -------------------------------------------------------------------------

// any field that smells like free text from the prof
export const COMMENT_KEY = /(comment|note|remark|descr|message|info|megjegyz|leiras|leírás|uzenet|üzenet)/i;

// event fields we already show elsewhere, everything else that reads like text counts as a comment
const KNOWN_EVENT_KEYS = new Set([
  'name', 'subjectName', 'title', 'rooms', 'room', 'location', 'courseTutor', 'teacher',
  'courseCode', 'subjectCode', 'courseTypeName', 'courseType', 'typeName', 'startDate', 'endDate',
]);

function isFreeText(v: string): boolean {
  const t = v.trim();
  return /^https?:\/\//i.test(t) || (t.length >= 20 && /\s/.test(t));
}

// comment rows from a detail list plus any loose notes, booleans and dupes out
export function commentsOf(rows: DetailRow[], ...extra: string[]): string[] {
  const picked = rows.filter((r) => r.key && COMMENT_KEY.test(r.key)).map((r) => r.value);
  return [...new Set([...extra, ...picked].map((x) => x.trim()).filter((x) => x && x !== '✓' && x !== '✕'))];
}

function normalizeEvent(e: Json, i: number): ClassEntry | null {
  const startMs = parseIso(e.startDate);
  const endMs = parseIso(e.endDate);
  if (!startMs || !endMs) return null;
  const type = num(e.eventTypeId);
  // type 6 = registration periods and office hours, only the short ones stay
  if (type === 6 && endMs - startMs >= 20 * 60 * 60 * 1000) return null;
  const classInstanceId = str(e.classInstanceId);
  const title = str(e.name) || str(e.subjectName) || str(e.title, '-');
  const location = str(e.rooms) || str(e.room) || str(e.location);
  const teacher = str(e.courseTutor) || str(e.teacher);
  // strings only, a hasComment=false must not turn into a comment
  const note = [
    ...new Set(
      Object.entries(e)
        .filter(([k, v]) => typeof v === 'string' && !KNOWN_EVENT_KEYS.has(k) && (COMMENT_KEY.test(k) || isFreeText(v)))
        .map(([, v]) => formatValue(v))
        .filter((v): v is string => !!v && v !== title && v !== location && v !== teacher && !(title.length > 3 && v.includes(title))),
    ),
  ].join('\n\n');
  return {
    id: `${classInstanceId || str(e.id) || str(e.taskId) || 'ev'}-${startMs}-${i}`,
    startMs,
    endMs,
    title,
    location,
    teacher,
    code: str(e.courseCode) || str(e.subjectCode),
    courseType: str(e.courseTypeName) || str(e.courseType) || str(e.typeName),
    classInstanceId,
    note,
    kind:
      type === 1
        ? 'exam'
        : str(e.taskId) || str(e.midTermTaskId)
          ? 'task'
          : (classInstanceId || type === 0) && type !== 6
            ? 'class'
            : 'other',
  };
}

// neptun renamed the visibility flags, old names 400. stale training id also 400s so retry once
async function calendarRange(start: Date, end: Date, classes: boolean): Promise<ClassEntry[]> {
  const query = (id: string | null) =>
    `startDate=${localIso(start)}&endDate=${localIso(end)}` +
    (id ? `&studentTrainingIds[0]=${encodeURIComponent(id)}` : '') +
    `&isClassesVisible=${classes}&isExamsVisible=true&isFinalExamsVisible=true` +
    `&isOnlineMeetingsVisible=true&isOtherEventsVisible=true&isPeriodsVisible=false&isTasksVisible=true`;
  const fetchOnce = async () => apiGet<unknown>(`Calendar/GetCalendarEvents?${query(await getStudentTrainingId())}`);
  const gen = sessionGeneration();
  let data: unknown;
  try {
    data = await fetchOnce();
    if (sessionGeneration() !== gen) data = await fetchOnce();
  } catch (err) {
    if (!(err instanceof NeptunError) || err.kind !== 'server') throw err;
    invalidateTrainingId();
    try {
      data = await fetchOnce();
    } catch (err2) {
      if (!(err2 instanceof NeptunError) || err2.kind !== 'server') throw err2;
      data = await apiGet<unknown>(`Calendar/GetCalendarEvents?${query(null)}`);
    }
  }
  const items = Array.isArray(data) ? data : data && typeof data === 'object' ? [data] : [];
  const seen = new Set<string>();
  return (items as Json[])
    .map((e, i) => normalizeEvent(e, i))
    .filter((x): x is ClassEntry => {
      if (!x) return false;
      const k = `${x.classInstanceId}|${x.startMs}|${x.endMs}|${x.title}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    })
    .sort((a, b) => a.startMs - b.startMs);
}

export async function getWeek(weekOffset: number): Promise<ClassEntry[]> {
  if (await isDemo()) return demo.week(weekOffset);
  const start = mondayOf(weekOffset);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  end.setHours(23, 59, 59, 999);
  const out = await calendarRange(start, end, true);
  log.info('calendar', `week ${weekOffset}: ${out.length} events`);
  return out;
}

// Exams and tasks over the next eight weeks, for the Upcoming screen.
export async function getUpcomingEvents(): Promise<ClassEntry[]> {
  if (await isDemo()) return demo.upcoming();
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 56);
  const out = (await calendarRange(start, end, false)).filter((e) => e.kind === 'exam' || e.kind === 'task');
  log.info('upcoming', `${out.length} exams/tasks`);
  return out;
}

// ---- subjects -------------------------------------------------------------------------

export async function getTerms(): Promise<Term[]> {
  if (await isDemo()) return demo.terms();
  const out = list(await apiGet<unknown>('TakenSubjects/Terms'))
    .map((t) => ({ id: String(t.value ?? ''), name: str(t.text) || String(t.value ?? '') }))
    .filter((t) => t.id);
  log.info('subjects', `${out.length} terms`);
  return out;
}

async function subjectGrade(item: Json, termId: string): Promise<SubjectEntry> {
  const subjectId = str(item.subjectId);
  const base: SubjectEntry = {
    id: subjectId || str(item.subjectCode) || str(item.subjectName),
    name: str(item.subjectName, '-'),
    code: str(item.subjectCode),
    credit: num(item.subjectCredit),
    grade: 0,
    completed: false,
    passFail: false,
    requirement: str(item.requirementType),
    resultText: '',
    details: detailRows(item),
  };
  if (!subjectId) return base;
  try {
    const d = await apiGet<Json | null>(
      `SubjectCourse/GetSubjectDetails?subjectId=${encodeURIComponent(subjectId)}&termId=${encodeURIComponent(termId)}`,
    );
    const merged = [...base.details];
    for (const row of detailRows(d)) if (!merged.some((m) => m.label === row.label)) merged.push(row);
    const withDetails = { ...base, details: merged, requirement: base.requirement || str(d?.requirementType) };
    const result = d?.subjectResult as Json | undefined;
    if (result) {
      const name = str(result.resultName);
      const numeric = typeof result.resultValue === 'number';
      const grade = numeric ? (result.resultValue as number) : parseTextGrade(name);
      return {
        ...withDetails,
        grade: grade >= 1 && grade <= 5 ? grade : 0,
        completed: result.passed === true,
        passFail: !numeric && PASS_FAIL.test(name) && !/nicht bestanden/i.test(name),
        resultText: name,
      };
    }
    const status = d?.subjectStatus as Json | undefined;
    if (status && DONE_STATUS.test(str(status.statusText))) {
      return { ...withDetails, completed: true, passFail: true, resultText: str(status.statusText) };
    }
    return withDetails;
  } catch (err) {
    // One subject's detail failing should not blank the whole list; it shows ungraded.
    log.warn('subjects', 'grade lookup failed for one subject', err);
  }
  return base;
}

export async function getSubjects(termId: string): Promise<SubjectEntry[]> {
  if (await isDemo()) return demo.subjects(termId);
  const items = list(
    await apiGet<unknown>(
      `TakenSubjects?request.termId=${encodeURIComponent(termId)}&sortAndPage.firstRow=0&sortAndPage.lastRow=50`,
    ),
  );
  const out: SubjectEntry[] = [];
  const BATCH = 6;
  for (let i = 0; i < items.length; i += BATCH) {
    out.push(...(await Promise.all(items.slice(i, i + BATCH).map((it) => subjectGrade(it, termId)))));
  }
  log.info('subjects', `${out.length} subjects in term`);
  return out;
}

export async function getCreditProgress(): Promise<CreditProgress> {
  if (await isDemo()) return demo.creditProgress();
  const d = await apiGet<Json | null>('dashboard/creditprogress');
  return { completed: num(d?.completedCredit), required: num(d?.requiredCredit) };
}

// ---- payments -------------------------------------------------------------------------

const DONE_STATUSES = [
  'teljesített', 'törölt', 'pénzügyileg igazolt', 'kifizetett', 'kiutalva', 'jóváhagyott',
  'completed', 'fulfilled', 'deleted', 'cancelled', 'canceled', 'financially certified', 'financially verified', 'paid', 'paid out', 'transferred', 'approved',
  'erfüllt', 'erledigt', 'gelöscht', 'storniert', 'finanziell bestätigt', 'bezahlt', 'ausgezahlt', 'überwiesen', 'genehmigt',
];

export async function getPayments(): Promise<PaymentEntry[]> {
  if (await isDemo()) return demo.payments();
  const data = list(
    await apiGet<unknown>(
      'Transactions/GetStudentPreviousTransactions?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.transferDate=desc',
    ),
  );
  const out = data.map((item, i) => {
    const raw = Math.round(num(item.transactionValue));
    const status = str(item.transactionStatus);
    return {
      id: `${str(item.transactionId) || 'tx'}-${i}`,
      kind: str(item.transactionTypeName) || str(item.transactionType),
      // Payouts to the student (scholarships) come with sign "-".
      amount: item.sign === '-' ? -raw : raw,
      dateMs: parseIso(item.transferDate),
      title: str(item.transactionPayingType, '-'),
      status,
      done: DONE_STATUSES.includes(status.toLowerCase()),
    };
  });
  log.info('payments', `${out.length} transactions`);
  return out;
}

// payments carry no term, so bucket by date. the newest term also keeps the running semester and anything still unpaid
export function paymentsInTerm(all: PaymentEntry[], termName: string, latest: boolean, now = Date.now()): PaymentEntry[] {
  const parsed = parseTermName(termName);
  if (!parsed) return all;
  const w = windowOf(parsed);
  if (latest) {
    const from = Math.min(w.fromMs, windowOf(academicTermAt(now)).fromMs);
    return all.filter((p) => p.dateMs >= from || (p.amount > 0 && !p.done));
  }
  return all.filter((p) => p.dateMs >= w.fromMs && p.dateMs < w.toMs);
}

// ---- periods --------------------------------------------------------------------------

export async function getPeriods(): Promise<PeriodEntry[]> {
  if (await isDemo()) return demo.periods();
  const terms = list(await apiGet<unknown>('Periods/GetTerms'));
  // last two terms: once next semester's registration opens it becomes the newest, and the current exam period must not vanish
  const ids = terms
    .slice(-2)
    .map((t) => String(t.value ?? ''))
    .filter(Boolean);
  return periodsOf(ids);
}

// one picked term. the periods endpoint keeps its own term list, so match the id and fall back to the name
export async function getTermPeriods(term: Term): Promise<PeriodEntry[]> {
  if (await isDemo()) return demo.termPeriods(term.id);
  const terms = list(await apiGet<unknown>('Periods/GetTerms'));
  const flat = (v: string) => v.replace(/\s+/g, '').toLowerCase();
  const hit =
    terms.find((t) => String(t.value ?? '') === term.id) ?? terms.find((t) => flat(str(t.text)) === flat(term.name));
  const id = hit ? String(hit.value ?? '') : '';
  return id ? periodsOf([id]) : [];
}

async function periodsOf(ids: string[]): Promise<PeriodEntry[]> {
  if (!ids.length) return [];
  const pages = await Promise.all(
    ids.map(async (id, i) => {
      try {
        return list(
          await apiGet<unknown>(
            `Periods/GetPeriods?request.termId=${encodeURIComponent(id)}&sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc`,
          ),
        );
      } catch (err) {
        if (i === ids.length - 1) throw err;
        return [];
      }
    }),
  );
  const seen = new Set<string>();
  const data = pages.flat().filter((item) => {
    const k = `${str(item.periodName)}|${str(item.fromDate)}|${str(item.toDate)}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  const lang = await neptunLang();
  const out = data
    .map((item) => ({ name: localizePeriodName(str(item.periodName, '-'), lang), fromMs: parseIso(item.fromDate), toMs: parseIso(item.toDate) }))
    .filter((p) => p.fromMs > 0 && p.toMs > 0);
  log.info('periods', `${out.length} periods`);
  return out;
}

// first teaching monday, same hack as the android app. neptun now answers in the app language so match all three
export function firstStudyWeekMs(periods: PeriodEntry[], now = Date.now()): number | null {
  const pick = (re: RegExp) =>
    periods.filter((p) => re.test(p.name.toLowerCase()) && p.fromMs <= now).sort((a, b) => b.fromMs - a.fromMs)[0];
  const monday = (ms: number, extraWeeks: number) => {
    const d = new Date(ms);
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7) + extraWeeks * 7);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  };
  const final = pick(/végleges tárgyjelentkezés|final (subject|course) registration|endgültige (fach|kurs)anmeldung/);
  if (final) return monday(final.toMs, 0);
  const study = pick(/szorgalmi időszak|study period|teaching period|term time|lecture period|vorlesungszeit/);
  if (study) {
    const day = new Date(study.fromMs).getDay();
    return monday(study.fromMs, day === 0 || day === 6 ? 1 : 0);
  }
  const reg = pick(/bejelentkezési időszak|registration period|anmeldezeitraum/);
  return reg ? monday(reg.toMs, 1) : null;
}

// ---- messages -------------------------------------------------------------------------

export async function getMessages(): Promise<MessageEntry[]> {
  if (await isDemo()) return demo.messages();
  const data = await apiGet<Json | null>('Message/GetReceivedMessages?firstRow=0&lastRow=49&filterType=0');
  const out = list(data?.receivedMessages).map((item, i) => ({
    id: str(item.messageId) || `m${i}`,
    subject: str(item.subject, '-'),
    sender: str(item.senderName, '-'),
    dateMs: parseIso(item.lastPostDate),
    isRead: num(item.unreadedPostCount) === 0,
    hasAttachment: item.hasAttachment === true,
  }));
  log.info('messages', `${out.length} messages`);
  return out;
}

type Post = { postId: string; isRead: boolean; html: string };

function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|li|tr|h\d)>/gi, '\n')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

// opening alone doesnt mark read, acking the posts does
export async function openMessage(id: string): Promise<string> {
  if (await isDemo()) return demo.messageBody(id);
  const data = await apiGet<Json | null>(`Messages/${encodeURIComponent(id)}/Posts`);
  const posts: Post[] = list(data?.posts).map((p) => ({
    postId: str(p.postId),
    isRead: p.isRead === true,
    html: str(p.htmlText),
  }));
  const unread = posts.filter((p) => !p.isRead && p.postId).map((p) => p.postId);
  if (unread.length) {
    try {
      await apiPost(`Messages/${encodeURIComponent(id)}/Posts/Processed`, { postIds: unread });
      log.info('messages', `marked ${unread.length} posts read`);
    } catch (err) {
      log.warn('messages', 'could not mark message read', err);
    }
  }
  return posts.map((p) => p.html.trim()).filter((h) => stripHtml(h)).join('<hr>');
}

export async function markMessageRead(id: string): Promise<void> {
  if (await isDemo()) return;
  const data = await apiGet<Json | null>(`Messages/${encodeURIComponent(id)}/Posts`);
  const unread = list(data?.posts)
    .filter((p) => p.isRead !== true && str(p.postId))
    .map((p) => str(p.postId));
  if (unread.length) await apiPost(`Messages/${encodeURIComponent(id)}/Posts/Processed`, { postIds: unread });
}

export async function getUnreadCount(): Promise<number> {
  const d = await apiGet<Json | null>('Message/GetUnreadedMessagesCount');
  return num(d?.count);
}

// ---- class details --------------------------------------------------------------------

export async function getCourseDetails(classInstanceId: string): Promise<DetailRow[]> {
  if (!classInstanceId) return [];
  if (await isDemo()) return demo.courseDetails(classInstanceId);
  const d = await apiGet<unknown>(
    `Calendar/GetCourseDetails?classInstanceId=${encodeURIComponent(classInstanceId)}&webexMeetingId=null`,
  );
  return detailRows(Array.isArray(d) ? d[0] : d);
}

// ---- profile, money, administration ---------------------------------------------------

export type Profile = {
  name: string;
  code: string;
  avatar: string | null; // base64 image
  rows: DetailRow[];
  documents: DetailRow[][];
  bankAccount: string;
};

export async function getProfile(): Promise<Profile> {
  const username = (await Store.getUsername()) ?? '';
  if (await isDemo()) return demo.profile();
  const [general, avatar, docs, bank] = await Promise.allSettled([
    apiGet<Json | null>('PersonalData/GetGeneralUserData'),
    apiGet<Json | null>('General/GetUserAvatar?imageSizeType=Normal'),
    apiGet<Json | null>('PersonalData/GetStudentPersonalDocuments'),
    apiGet<unknown>('BankAccount/GetDefaultBankAccountNumber'),
  ]);
  if (general.status === 'rejected' && avatar.status === 'rejected') throw general.reason;
  const g = general.status === 'fulfilled' ? general.value : null;
  const bankValue = bank.status === 'fulfilled' ? bank.value : null;
  const name =
    str(g?.name) || [str(g?.lastName), str(g?.firstName)].filter(Boolean).join(' ') || str(g?.birthName) || username;
  return {
    name,
    code: username,
    avatar: avatar.status === 'fulfilled' ? str(avatar.value?.image) || null : null,
    rows: detailRows(g),
    documents: docs.status === 'fulfilled' ? list(docs.value?.studentPersonalDocuments).map((x) => detailRows(x)) : [],
    bankAccount:
      typeof bankValue === 'string'
        ? bankValue
        : str((bankValue as Json | null)?.bankAccountNumber) || str((bankValue as Json | null)?.accountNumber),
  };
}

export type CollectiveAccount = { balance: number; currency: string; bankAccount: string };

export async function getCollectiveAccount(): Promise<CollectiveAccount | null> {
  if (await isDemo()) return demo.collectiveAccount();
  const d = list(await apiGet<unknown>('FinancialDataDashboard/GetCollectiveInvoices'));
  if (!d.length) return null;
  return {
    balance: num(d[0].collectiveInvoiceBalance),
    currency: str(d[0].collectiveInvoiceCurrency, 'HUF'),
    bankAccount: str(d[0].collectiveInvoiceBankAccount),
  };
}

export type ListItem = {
  id: string;
  title: string;
  subtitle: string;
  dateMs: number;
  status: string;
  rows: DetailRow[];
};

function fileSize(v: unknown): string | null {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n) || n <= 0) return null;
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(0)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

type Keys = { title: string[]; subtitle?: string[]; date: string[]; status: string[]; drop?: string[] };

function toItems(data: unknown, k: Keys): ListItem[] {
  const subtitleKeys = k.subtitle ?? ['subjectName', 'termName', 'typeName', 'documentTypeName', 'categoryName'];
  return list(data).map((x, i) => {
    const pick = (keys: string[]) => keys.map((key) => str(x[key])).find(Boolean) ?? '';
    const d = k.date.map((key) => parseIso(x[key])).find((v) => v > 0) ?? 0;
    const title = pick(k.title) || '-';
    const subtitle = pick(subtitleKeys);
    const rows = detailRows(x)
      .filter((r) => r.value !== title && !(k.drop ?? []).includes(r.key ?? ''))
      .filter((r) => !/^(true|false)$/i.test(r.value) || !/lecturer/i.test(r.key ?? ''))
      .map((r) => (r.key === 'size' ? { ...r, value: fileSize(x.size) ?? r.value } : r));
    return {
      id: `${pick(['id', 'requestFormId', 'requestFormTemplateId', 'documentId', 'documentationId', 'questionnaireId'])}-${i}`,
      title,
      subtitle,
      dateMs: d,
      status: pick(k.status),
      rows,
    };
  });
}

const PAGE = 'sortAndPage.firstRow=0&sortAndPage.lastRow=100';

export async function getRequestTemplates(): Promise<ListItem[]> {
  if (await isDemo()) return demo.requestTemplates();
  return toItems(
    await apiGet<unknown>(`RequestForm/GetStudentRequestFormTemplates?${PAGE}&sortAndPage.templateName=asc`),
    { title: ['templateName', 'name', 'requestFormName'], date: ['validTo', 'availableTo', 'endDate'], status: ['statusName', 'status'] },
  );
}

export async function getSubmittedRequests(): Promise<ListItem[]> {
  if (await isDemo()) return demo.submittedRequests();
  return toItems(
    await apiGet<unknown>(`RequestForm/GetSubmittedRequestForms?${PAGE}&sortAndPage.submissionDate=desc`),
    {
      title: ['templateName', 'requestFormName', 'name'],
      date: ['submissionDate', 'createdDate', 'date'],
      status: ['statusName', 'requestFormStatusName', 'status', 'state'],
    },
  );
}

export type DocumentKind = 'official' | 'uploaded' | 'tr';

export async function getDocuments(kind: DocumentKind): Promise<ListItem[]> {
  if (await isDemo()) return demo.documents(kind);
  const path =
    kind === 'official'
      ? `DocumentContainer/GetDocumentsUploadedForStudent?${PAGE}`
      : kind === 'uploaded'
        ? `DocumentContainer/GetDocumentsUploadedByStudent?${PAGE}`
        : `DocumentContainer/GetTrDocuments?request.isOnlyCertificated=false&request.mustBeCertified=false&request.isOnlyLegalRemediableFilter=false&${PAGE}`;
  // field names straight from the official web client's grid columns
  return toItems(await apiGet<unknown>(path), {
    title: ['documentationName', 'documentName', 'name', 'fileName', 'title'],
    subtitle: ['documentationType', 'documentTypeName', 'connectionType'],
    date: ['documentationUploadDate', 'uploadDate', 'createdDate', 'date'],
    status: ['statusName', 'uiDisplayStateText'],
    drop: ['uiDisplayStateText', 'documentationUploadDate', 'uploadDate'],
  });
}

export async function getQuestionnaires(finished: boolean): Promise<ListItem[]> {
  if (await isDemo()) return demo.questionnaires(finished);
  const path = finished ? 'Questionnaires/GetFinishedQuestionnaires' : 'Questionnaires/GetQuestionnaires';
  const d = await apiGet<unknown>(`${path}?firstRow=0&lastRow=100`);
  const box = d as Json | null;
  const items = Array.isArray(d) ? d : (box?.questionnaires ?? box?.gridData);
  return toItems(items, {
    title: ['title', 'questionnaireName', 'name', 'subjectName'],
    subtitle: ['courseCode', 'courseTypeName', 'subjectName', 'termName'],
    date: ['toDate', 'endDate', 'fillEndDate', 'deadline'],
    status: ['statusName', 'status'],
  });
}
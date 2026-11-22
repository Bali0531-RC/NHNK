import * as BackgroundTask from 'expo-background-task';
import * as Notifications from 'expo-notifications';
import * as SecureStore from 'expo-secure-store';
import * as TaskManager from 'expo-task-manager';
import { router } from 'expo-router';
import { useEffect } from 'react';
import { AppState } from 'react-native';

import { pickedTerm, type TermPick } from '@/hooks/use-term';
import { v2Strings, type V2Strings } from '@/i18n/v2-strings';
import { loadExams } from '@/lib/exams';
import { fmtMoney } from '@/lib/format';
import { readCache, writeCache } from '@/neptun/cache';
import { keepSessionFresh } from '@/neptun/client';
import { getMessages, getSubjects, getUnreadCount, getUpcomingEvents, mondayOf, type ClassEntry, type MessageEntry, type PaymentEntry, type PeriodEntry, type SubjectEntry, type Term } from '@/neptun/data';
import { neptunLang } from '@/neptun/lang';
import { log } from '@/neptun/log';
import { Store } from '@/neptun/storage';
import { loadPrefs, usePreferences, type Prefs } from '@/providers/preferences';

const TASK = 'nhnk.background-sync';
const SEEN_KEY = 'notify.seen-messages';
const PREFIX = 'nhnk.';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

async function strings(): Promise<V2Strings> {
  const lang = await SecureStore.getItemAsync('nhnk.pref.lang').catch(() => null);
  return v2Strings[lang === 'en' || lang === 'de' ? lang : 'hu'];
}

export async function ensurePermission(): Promise<boolean> {
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  if (!current.canAskAgain) return false;
  const asked = await Notifications.requestPermissionsAsync({
    ios: { allowAlert: true, allowSound: true, allowBadge: true },
  });
  return asked.granted;
}

export async function sendTest(timeSensitive: boolean): Promise<boolean> {
  if (!(await ensurePermission())) return false;
  const s = await strings();
  await Notifications.scheduleNotificationAsync({
    identifier: `${PREFIX}test.${Date.now()}`,
    content: {
      title: timeSensitive ? s.notify.testTsTitle : s.notify.testTitle,
      body: timeSensitive ? s.notify.testTsBody : s.notify.testBody,
      sound: true,
      interruptionLevel: timeSensitive ? 'timeSensitive' : 'active',
    },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL, seconds: 3 },
  });
  return true;
}

function weekKey(offset: number): string {
  const d = mondayOf(offset);
  return `week.${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

async function at(id: string, dateMs: number, title: string, body: string, timeSensitive = false) {
  if (dateMs <= Date.now() + 5000) return;
  await Notifications.scheduleNotificationAsync({
    identifier: `${PREFIX}${id}`,
    content: { title, body, sound: true, interruptionLevel: timeSensitive ? 'timeSensitive' : 'active' },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date: new Date(dateMs) },
  });
}

const norm = (t: string) => t.trim().toLowerCase().replace(/\s+/g, ' ');

// finished subjects across the current + picked term. no cache yet = go fetch it, a ping for a done class is worse
async function doneSubjects(): Promise<Set<string>> {
  const terms = (await readCache<Term[]>('terms'))?.data ?? [];
  const latest = terms[terms.length - 1]?.id;
  const picked = pickedTerm((await readCache<TermPick>('ui.termPick'))?.data ?? null, latest);
  const ids = [...new Set([latest, picked].filter((x): x is string => !!x))];
  const done = new Set<string>();
  for (const id of ids) {
    let list = (await readCache<SubjectEntry[]>(`subjects.${id}`))?.data;
    if (!list) {
      list = await getSubjects(id).catch(() => undefined);
      if (list) await writeCache(`subjects.${id}`, list);
    }
    for (const x of list ?? []) if (x.completed) done.add(norm(x.name));
  }
  return done;
}

function hhmm(ms: number): string {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

// rebuilds local reminders from cache. ios caps pending at 64 so nearest first
export async function rescheduleReminders(prefs: Prefs): Promise<void> {
  const pending = await Notifications.getAllScheduledNotificationsAsync();
  await Promise.all(
    pending
      .filter((n) => n.identifier.startsWith(PREFIX) && !n.identifier.startsWith(`${PREFIX}test.`))
      .map((n) => Notifications.cancelScheduledNotificationAsync(n.identifier)),
  );
  if (!(await Store.getAccessToken()) && !(await Store.getIsDemo())) return;
  const perm = await Notifications.getPermissionsAsync();
  if (!perm.granted) return;
  const s = await strings();
  const jobs: { when: number; run: () => Promise<void> }[] = [];

  const weeks = await Promise.all([readCache<ClassEntry[]>(weekKey(0)), readCache<ClassEntry[]>(weekKey(1))]);
  const events = weeks.flatMap((w) => w?.data ?? []);
  if (prefs.notifyClasses) {
    const done = await doneSubjects();
    const classes = events.filter((x) => (x.kind === 'class' && !done.has(norm(x.title))) || (prefs.showOfficeHours && x.kind === 'other'));
    for (const e of classes) {
      const when = e.startMs - prefs.classLeadMinutes * 60000;
      jobs.push({
        when,
        run: () => at(`class.${e.id}`, when, s.notify.classSoon(e.title, prefs.classLeadMinutes), s.notify.classAt(e.location, hhmm(e.startMs)), true),
      });
    }
  }
  if (prefs.notifyExams) {
    const upcoming = (await readCache<ClassEntry[]>('upcoming'))?.data ?? events.filter((x) => x.kind === 'exam' || x.kind === 'task');
    for (const e of upcoming) {
      const d = new Date(e.startMs);
      const when = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1, 18, 0).getTime();
      jobs.push({ when, run: () => at(`exam.${e.id}`, when, s.notify.examTomorrow(e.title), s.notify.classAt(e.location, hhmm(e.startMs))) });
    }
  }
  // hand-added exams: the per-exam switches are the opt-in, so the global exam toggle doesnt gate them
  for (const x of await loadExams()) {
    const d = new Date(x.atMs);
    const body = s.notify.classAt(x.lesson.title, hhmm(x.atMs));
    if (x.remindEvening) {
      const when = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1, 20, 0).getTime();
      jobs.push({ when, run: () => at(`mexam.e.${x.id}`, when, s.notify.examTomorrow(x.title), body, true) });
    }
    if (x.remindHour) {
      const when = x.atMs - 3_600_000;
      jobs.push({ when, run: () => at(`mexam.h.${x.id}`, when, s.exams.inHour(x.title), body, true) });
    }
  }
  if (prefs.notifyPayments) {
    const pays = (await readCache<PaymentEntry[]>('payments'))?.data ?? [];
    const lang = await neptunLang();
    for (const p of pays.filter((x) => x.amount > 0 && !x.done)) {
      const d = new Date(p.dateMs);
      const when = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1, 10, 0).getTime();
      jobs.push({ when, run: () => at(`pay.${p.id}`, when, s.notify.paymentDue(p.title), fmtMoney(p.amount, lang)) });
    }
  }
  if (prefs.notifyPeriods) {
    const periods = (await readCache<PeriodEntry[]>('periods'))?.data ?? [];
    for (const p of periods) {
      const d = new Date(p.fromMs);
      const when = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 8, 0).getTime();
      jobs.push({ when, run: () => at(`period.${p.name}.${p.fromMs}`, when, s.notify.periodStarts(p.name), '') });
    }
  }

  const soon = jobs.filter((j) => j.when > Date.now()).sort((a, b) => a.when - b.when).slice(0, 55);
  for (const j of soon) {
    try {
      await j.run();
    } catch (err) {
      log.warn('notify', 'schedule failed', err);
    }
  }
  log.info('notify', `${soon.length} reminders scheduled`);
}

// New Neptun messages since the last check, announced with sender and (shortened) subject.
async function announceNewMessages(prefs: Prefs): Promise<void> {
  if (!prefs.notifyMessages) return;
  if ((await getUnreadCount().catch(() => 1)) === 0) return;
  const list: MessageEntry[] = await getMessages();
  await writeCache('messages', list);
  const seen = new Set((await readCache<string[]>(SEEN_KEY))?.data ?? []);
  const first = seen.size === 0;
  const fresh = list.filter((m) => !m.isRead && !seen.has(m.id));
  await writeCache(SEEN_KEY, list.map((m) => m.id));
  if (first) return;
  const s = await strings();
  for (const m of fresh.slice(0, 5)) {
    const subject = m.subject.length > 120 ? `${m.subject.slice(0, 117)}...` : m.subject;
    await Notifications.scheduleNotificationAsync({
      identifier: `${PREFIX}msg.${m.id}`,
      content: { title: m.sender || s.notify.newMessage, subtitle: s.notify.newMessage, body: subject, sound: true, data: { messageId: m.id } },
      trigger: null,
    });
  }
}

// Exams and tasks that appeared in Neptun since the last check.
async function announceNewAssignments(prefs: Prefs): Promise<void> {
  if (!prefs.notifyExams) return;
  const list = await getUpcomingEvents();
  await writeCache('upcoming', list);
  const seenKey = 'notify.seen-assignments';
  const seen = new Set((await readCache<string[]>(seenKey))?.data ?? []);
  const first = seen.size === 0;
  const keyOf = (e: ClassEntry) => `${e.kind}|${e.title}|${e.startMs}`;
  const fresh = list.filter((e) => !seen.has(keyOf(e)));
  await writeCache(seenKey, list.map(keyOf));
  if (first) return;
  const s = await strings();
  for (const e of fresh.slice(0, 5)) {
    await Notifications.scheduleNotificationAsync({
      identifier: `${PREFIX}new.${keyOf(e)}`,
      content: { title: s.notify.newAssignment, body: `${e.title} · ${new Date(e.startMs).toLocaleDateString()}`, sound: true },
      trigger: null,
    });
  }
}

TaskManager.defineTask(TASK, async () => {
  try {
    const prefs = await loadPrefs();
    if (!prefs.backgroundSync || (await Store.getIsDemo()) || !(await Store.getAccessToken())) {
      return BackgroundTask.BackgroundTaskResult.Success;
    }
    await keepSessionFresh();
    await announceNewMessages(prefs);
    await announceNewAssignments(prefs).catch((err) => log.warn('notify', 'assignment check failed', err));
    await rescheduleReminders(prefs);
    return BackgroundTask.BackgroundTaskResult.Success;
  } catch (err) {
    log.warn('notify', 'background sync failed', err);
    return BackgroundTask.BackgroundTaskResult.Failed;
  }
});

async function setBackground(on: boolean): Promise<void> {
  try {
    const registered = await TaskManager.isTaskRegisteredAsync(TASK);
    if (on && !registered) await BackgroundTask.registerTaskAsync(TASK, { minimumInterval: 30 });
    if (!on && registered) await BackgroundTask.unregisterTaskAsync(TASK);
  } catch (err) {
    log.warn('notify', 'background task registration failed', err);
  }
}

// Keeps reminders and the background task in line with the settings while signed in.
export function useNotificationSync(signedIn: boolean): void {
  const prefs = usePreferences();
  const { loaded, backgroundSync, notifyClasses, notifyExams, notifyMessages, notifyPayments, notifyPeriods, classLeadMinutes, showOfficeHours } =
    prefs;
  useEffect(() => {
    if (!loaded) return;
    if (!signedIn) {
      void setBackground(false);
      void Notifications.cancelAllScheduledNotificationsAsync();
      return;
    }
    let active = true;
    void (async () => {
      // never prompt here, apple hates launch prompts. onboarding + settings ask when the user taps
      if (!active) return;
      await setBackground(backgroundSync);
      await rescheduleReminders(await loadPrefs());
    })().catch((err) => log.warn('notify', 'sync failed', err));
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') void loadPrefs().then(rescheduleReminders).catch(() => {});
    });
    const tap = Notifications.addNotificationResponseReceivedListener((res) => {
      const id = res.notification.request.content.data?.messageId;
      if (typeof id === 'string') router.push({ pathname: '/message/[id]', params: { id } });
    });
    return () => {
      active = false;
      sub.remove();
      tap.remove();
    };
  }, [loaded, signedIn, backgroundSync, notifyClasses, notifyExams, notifyMessages, notifyPayments, notifyPeriods, classLeadMinutes, showOfficeHours]);
}
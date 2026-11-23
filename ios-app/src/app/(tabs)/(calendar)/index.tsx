import { router, Stack } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import {
  Pressable,
  RefreshControl,
  ScrollView,
  Text,
  useWindowDimensions,
  View,
  type GestureResponderEvent,
} from 'react-native';
import Animated, {
  Extrapolation,
  FadeIn,
  FadeInDown,
  FadeOut,
  interpolate,
  interpolateColor,
  LinearTransition,
  useAnimatedReaction,
  useAnimatedRef,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';

import { DataBanner, ErrorCard, ProgressBar, ScreenTitle, useRefresh } from '@/components/screen';
import { Card, Skeleton } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useClassEnds } from '@/hooks/use-class-ends';
import { useHaptics } from '@/hooks/use-haptics';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTerm } from '@/hooks/use-term';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { DAY_MS, fmtDate, fmtDuration, hhmm, sameDay } from '@/lib/format';
import { pickCheer } from '@/lib/cheer';
import { defaultExamTime, examsFor, isLoose, useExams, type ManualExam } from '@/lib/exams';
import { iosMajor } from '@/lib/ios';
import { firstStudyWeekMs, getPeriods, getSubjects, getWeek, mondayOf, type ClassEntry, type PeriodEntry } from '@/neptun/data';
import { usePreferences } from '@/providers/preferences';

const FALLBACK_WEEKS = 14;

function dayIndex(ms: number): number {
  return (new Date(ms).getDay() + 6) % 7;
}

function startOfDay(ms: number): number {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function addDays(ms: number, n: number): number {
  const d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n).getTime();
}

function weekOffsetOf(mondayMs: number): number {
  return Math.round((mondayMs - mondayOf(0).getTime()) / (7 * DAY_MS));
}

function useNow(intervalMs: number): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}

function greetingKey(hour: number): 'morning' | 'day' | 'evening' | 'night' {
  if (hour >= 5 && hour < 10) return 'morning';
  if (hour >= 10 && hour < 18) return 'day';
  if (hour >= 18 && hour < 22) return 'evening';
  return 'night';
}

// Teaching weeks run from the first study week to the start of the exam period.
function teachingWeeks(periods: PeriodEntry[], firstWeek: number): number {
  const exam = periods
    .filter((p) => /vizsgaid[őo]szak|exam(ination)? period|prüfungszeit|prüfungszeitraum/i.test(p.name) && p.fromMs > firstWeek)
    .sort((a, b) => a.fromMs - b.fromMs)[0];
  if (!exam) return FALLBACK_WEEKS;
  const weeks = Math.round((exam.fromMs - firstWeek) / (7 * DAY_MS));
  return weeks >= 8 && weeks <= 20 ? weeks : FALLBACK_WEEKS;
}

function useWeekQuery(mondayMs: number) {
  const d = new Date(mondayMs);
  const key = `week.${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
  return useNeptunQuery(key, () => getWeek(weekOffsetOf(mondayMs)));
}

export default function CalendarScreen() {
  const c = useTheme();
  const { t, tx, lang } = useI18n();
  const { selection } = useHaptics();
  const { showOfficeHours, showPeriodsInCalendar, weekShift } = usePreferences();
  const { width } = useWindowDimensions();
  const now = useNow(15_000);
  const today = startOfDay(now);

  // every launch opens on today, the last browsed day is not worth remembering
  const [selected, setSelected] = useState(today);
  const monday = mondayOf(0, new Date(selected)).getTime();
  const sunday = addDays(monday, 6);
  const days = Array.from({ length: 9 }, (_, i) => addDays(monday, i - 1));
  const index = 1 + dayIndex(selected);

  const week = useWeekQuery(monday);
  const prev = useWeekQuery(addDays(monday, -7));
  const next = useWeekQuery(addDays(monday, 7));
  const periods = useNeptunQuery('periods', getPeriods);
  const { termId } = useTerm();
  const subjects = useNeptunQuery(termId ? `subjects.${termId}` : null, () => getSubjects(termId ?? ''));
  const allExams = useExams();
  const { endFor } = useClassEnds();
  const looseOn = (dayMs: number) => allExams.filter((x) => isLoose(x) && sameDay(x.atMs, dayMs));
  const doneTitles = new Set((subjects.data ?? []).filter((x) => x.completed).map((x) => norm(x.name)));
  const { refreshing, onRefresh } = useRefresh(() => Promise.all([week.refresh(), prev.refresh(), next.refresh(), periods.refresh()]));

  const firstWeek = periods.data ? firstStudyWeekMs(periods.data, now) : null;
  const total = firstWeek != null && periods.data ? teachingWeeks(periods.data, firstWeek) : FALLBACK_WEEKS;
  const eduWeek = firstWeek != null ? Math.floor((monday - firstWeek) / (7 * DAY_MS)) + 1 + weekShift : null;
  const inTerm = eduWeek != null && eduWeek >= 1 && eduWeek <= total;
  // Inside the current week the bar also moves with the days, so it creeps instead of jumping.
  const weekFraction = monday <= now && now < addDays(monday, 7) ? (now - monday) / (7 * DAY_MS) : 1;
  const progress = inTerm && eduWeek != null ? (eduWeek - 1 + weekFraction) / total : 0;

  const pager = useAnimatedRef<Animated.ScrollView>();
  // pager offset lives on the ui thread, the day pill rides it frame by frame instead of waiting for momentum
  const scrollX = useSharedValue(index * width);
  const dragging = useSharedValue(false);
  const weekKey = monday;
  useLayoutEffect(() => {
    scrollX.set(index * width);
    pager.current?.scrollTo({ x: index * width, animated: false });
    // only week jumps need this, days scroll themselves
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [weekKey, width]);

  const goTo = (dayMs: number) => {
    const target = startOfDay(dayMs);
    if (target === selected) return;
    selection();
    if (target >= monday && target <= sunday) {
      pager.current?.scrollTo({ x: (1 + dayIndex(target)) * width, animated: true });
    }
    setSelected(target);
  };

  // ios fires momentum on programmatic scrolls too, only real drags pick the day
  const [initialOffset] = useState(() => ({ x: index * width, y: 0 }));
  const onPageEnd = (x: number) => {
    const target = days[Math.round(x / width)];
    if (target != null && target !== selected) setSelected(target);
  };
  const onScroll = useAnimatedScrollHandler({
    onScroll: (e) => {
      scrollX.set(e.contentOffset.x);
    },
    onBeginDrag: () => {
      dragging.set(true);
    },
    onMomentumEnd: (e) => {
      if (!dragging.get()) return;
      dragging.set(false);
      scheduleOnRN(onPageEnd, e.contentOffset.x);
    },
  });

  // The header area is not part of the pager, so a horizontal flick there steps a day too.
  const touch = useRef({ x: 0, y: 0 });
  const onHeaderTouchStart = (e: GestureResponderEvent) => {
    touch.current = { x: e.nativeEvent.pageX, y: e.nativeEvent.pageY };
  };
  const onHeaderTouchEnd = (e: GestureResponderEvent) => {
    const dx = e.nativeEvent.pageX - touch.current.x;
    const dy = e.nativeEvent.pageY - touch.current.y;
    if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy) * 2) goTo(addDays(selected, dx < 0 ? 1 : -1));
  };

  const eventsFor = (dayMs: number): ClassEntry[] | null => {
    const src = dayMs < monday ? prev.data : dayMs > sunday ? next.data : week.data;
    if (!src) return null;
    // the lecturer's real end, set per subject, drives the bar, the countdown and the breaks
    return src
      .filter((e) => sameDay(e.startMs, dayMs) && (showOfficeHours || e.kind !== 'other'))
      .map((e) => {
        const endMs = endFor(e);
        return endMs === e.endMs ? e : { ...e, endMs };
      });
  };
  const busy = (dayMs: number) => (eventsFor(dayMs)?.length ?? 0) > 0 || looseOn(dayMs).length > 0;
  const periodsOn = (dayMs: number) =>
    showPeriodsInCalendar ? (periods.data ?? []).filter((p) => p.fromMs < addDays(dayMs, 1) && p.toMs >= dayMs) : [];

  const title = inTerm
    ? tx.calendar.eduWeek(eduWeek ?? 0)
    : monday === mondayOf(0).getTime()
      ? tx.calendar.thisWeek
      : tx.calendar.weekOf(fmtDate(monday, lang));

  return (
    <View style={{ flex: 1, backgroundColor: c.background }}>
      <ScreenTitle title={t.tabs.calendar} subtitle={tx.greeting[greetingKey(new Date(now).getHours())]} />
      <Stack.Screen options={{ headerTransparent: false, headerStyle: { backgroundColor: c.background }, headerShadowVisible: false }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          hidden={selected === today}
          icon="arrow.uturn.backward"
          accessibilityLabel={tx.v2.calendar.jumpToday}
          onPress={() => goTo(today)}
        />
        <Stack.Toolbar.Button
          icon="plus"
          accessibilityLabel={tx.v2.exams.add}
          onPress={() => {
            selection();
            router.push({ pathname: '/exam', params: { at: String(defaultExamTime(selected)) } });
          }}
        />
      </Stack.Toolbar>

      <View onTouchStart={onHeaderTouchStart} onTouchEnd={onHeaderTouchEnd} style={{ paddingHorizontal: Spacing.three, gap: Spacing.three, paddingBottom: Spacing.two }}>
        <Animated.View layout={LinearTransition.duration(260)}>
          <Card style={{ gap: Spacing.one, paddingVertical: Spacing.three }}>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              <Pressable testID="week-prev" hitSlop={12} onPress={() => goTo(addDays(selected, -7))} style={{ padding: Spacing.one }}>
                <SymbolView name="chevron.left" tintColor={c.brand} size={17} weight="semibold" />
              </Pressable>
              <View style={{ flex: 1, alignItems: 'center' }}>
                <Animated.Text
                  key={title}
                  entering={FadeIn.duration(200)}
                  style={{ color: c.text, fontSize: 18, fontWeight: '700' }}>
                  {title}
                </Animated.Text>
                <Text style={{ color: c.textSecondary, fontSize: 13, fontVariant: ['tabular-nums'] }}>
                  {fmtDate(monday, lang)} - {fmtDate(sunday, lang)}
                </Text>
              </View>
              <Pressable testID="week-next" hitSlop={12} onPress={() => goTo(addDays(selected, 7))} style={{ padding: Spacing.one }}>
                <SymbolView name="chevron.right" tintColor={c.brand} size={17} weight="semibold" />
              </Pressable>
            </View>
            {inTerm ? (
              <Animated.View
                entering={FadeIn.duration(250)}
                exiting={FadeOut.duration(200)}
                style={{ gap: 4, paddingHorizontal: Spacing.two, paddingTop: Spacing.two }}>
                <ProgressBar value={progress} color={c.brand} height={5} />
                <Text style={{ color: c.textTertiary, fontSize: 11, textAlign: 'right', fontVariant: ['tabular-nums'] }}>
                  {tx.v2.calendar.progress(eduWeek ?? 0, total)}
                </Text>
              </Animated.View>
            ) : null}
          </Card>
        </Animated.View>

        <DayStrip
          labels={tx.calendar.daysShort}
          monday={monday}
          today={today}
          width={width}
          scrollX={scrollX}
          dragging={dragging}
          busy={busy}
          onPress={goTo}
          initial={index}
        />

        <DataBanner query={week} />
      </View>

      <Animated.ScrollView
        ref={pager}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        contentOffset={initialOffset}
        onScroll={onScroll}
        scrollEventThrottle={1}
        style={{ flex: 1 }}>
        {days.map((dayMs) => (
          <View key={dayMs} style={{ width }}>
            <DayPage
              dayMs={dayMs}
              events={eventsFor(dayMs)}
              periods={periodsOn(dayMs)}
              loose={looseOn(dayMs)}
              now={now}
              loading={week.loading}
              failed={!week.data && !week.loading}
              query={week}
              refreshing={refreshing}
              onRefresh={onRefresh}
              doneTitles={doneTitles}
            />
          </View>
        ))}
      </Animated.ScrollView>
    </View>
  );
}

const GAP = 4;

// static chips + one pill on the ui thread. text colors flip once per page, the pill never waits on js
function DayStrip({
  labels,
  monday,
  today,
  width,
  scrollX,
  dragging,
  busy,
  onPress,
  initial,
}: {
  initial: number;
  labels: string[];
  monday: number;
  today: number;
  width: number;
  scrollX: SharedValue<number>;
  dragging: SharedValue<boolean>;
  busy: (dayMs: number) => boolean;
  onPress: (dayMs: number) => void;
}) {
  const c = useTheme();
  const { selection } = useHaptics();
  const [rowW, setRowW] = useState(0);
  const [live, setLive] = useState(initial);
  const chipW = (rowW - GAP * 6) / 7;
  const todayPage = today >= monday && today < addDays(monday, 7) ? 1 + dayIndex(today) : -10;

  useAnimatedReaction(
    () => Math.round(scrollX.get() / width),
    (cur, prev) => {
      if (prev === null || cur === prev) return;
      scheduleOnRN(setLive, cur);
      if (dragging.get()) scheduleOnRN(selection);
    },
    [width, selection],
  );

  const pill = useAnimatedStyle(() => {
    const pos = scrollX.get() / width;
    return {
      opacity: interpolate(pos, [0, 1, 7, 8], [0, 1, 1, 0], Extrapolation.CLAMP),
      transform: [{ translateX: Math.min(Math.max(pos - 1, 0), 6) * (chipW + GAP) }],
      backgroundColor: interpolateColor(Math.max(0, 1 - Math.abs(pos - todayPage)), [0, 1], [c.brand, c.danger]),
    };
  }, [width, chipW, todayPage, c.brand, c.danger]);

  return (
    <View onLayout={(e) => setRowW(e.nativeEvent.layout.width)}>
      <View style={{ position: 'absolute', inset: 0, flexDirection: 'row', gap: GAP }}>
        {labels.map((l) => (
          <View key={l} style={{ flex: 1, borderRadius: Radius.md, borderCurve: 'continuous', backgroundColor: c.card }} />
        ))}
      </View>
      {rowW ? (
        <Animated.View
          style={[{ position: 'absolute', top: 0, bottom: 0, left: 0, width: chipW, borderRadius: Radius.md, borderCurve: 'continuous' }, pill]}
        />
      ) : null}
      <View style={{ flexDirection: 'row', gap: GAP }}>
        {labels.map((label, i) => {
          const dayMs = addDays(monday, i);
          const active = live === i + 1;
          const isToday = dayMs === today;
          return (
            <Pressable
              key={label}
              testID={`day-${i}`}
              onPress={() => onPress(dayMs)}
              style={{ flex: 1, paddingVertical: Spacing.two, alignItems: 'center', gap: 2 }}>
              <Text style={{ color: active ? c.brandOn : isToday ? c.danger : c.textSecondary, fontSize: 12, fontWeight: '600' }}>{label}</Text>
              <Text style={{ color: active ? c.brandOn : isToday ? c.danger : c.text, fontSize: 16, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
                {new Date(dayMs).getDate()}
              </Text>
              <View
                style={{
                  width: 5,
                  height: 5,
                  borderRadius: 2.5,
                  backgroundColor: busy(dayMs) ? (active ? c.brandOn : c.textTertiary) : 'transparent',
                }}
              />
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

function DayPage({
  dayMs,
  events,
  periods,
  loose,
  now,
  loading,
  failed,
  query,
  refreshing,
  onRefresh,
  doneTitles,
}: {
  dayMs: number;
  events: ClassEntry[] | null;
  periods: PeriodEntry[];
  loose: ManualExam[];
  now: number;
  loading: boolean;
  failed: boolean;
  query: Parameters<typeof ErrorCard>[0]['query'];
  refreshing: boolean;
  onRefresh: () => void;
  doneTitles: Set<string>;
}) {
  const c = useTheme();
  const { tx, lang } = useI18n();
  let body: ReactNode;
  if (events == null && loading) {
    body = (
      <View style={{ gap: Spacing.two }}>
        {[0, 1, 2].map((i) => (
          <Card key={i} style={{ gap: Spacing.two }}>
            <Skeleton width="30%" height={12} />
            <Skeleton width="70%" height={18} />
            <Skeleton width="45%" height={12} />
          </Card>
        ))}
      </View>
    );
  } else if (events == null && failed) {
    body = <ErrorCard query={query} />;
  } else if ((!events || events.length === 0) && loose.length) {
    body = (
      <View style={{ gap: Spacing.two }}>
        {loose.map((x, i) => (
          <LooseExamCard key={x.id} exam={x} now={now} index={i} />
        ))}
      </View>
    );
  } else if (!events || events.length === 0) {
    body = (
      <Animated.View entering={FadeIn.duration(250)} style={{ paddingVertical: Spacing.six, alignItems: 'center', gap: Spacing.two }}>
        <SymbolView name="sun.max.fill" tintColor={c.warning} size={40} />
        <Text style={{ color: c.text, fontSize: 24, fontWeight: '800' }}>{tx.calendar.freeDay}</Text>
        <Text style={{ color: c.textSecondary, fontSize: 14 }}>{tx.v2.calendar.noClasses}</Text>
      </Animated.View>
    );
  } else {
    // pre-completed classes dont deserve a card, they melt into the break they free up
    const isDone = (e: ClassEntry) => e.kind === 'class' && doneTitles.has(norm(e.title));
    const live = events.filter((e) => !isDone(e));
    const done = events.filter(isDone);
    const between = (from: number, to: number) => done.filter((d) => d.startMs >= from && d.endMs <= to);
    const rows: ReactNode[] = [];
    // + button exams slot in by time between the classes
    const pushLoose = (from: number, to: number) => {
      const due = loose.filter((x) => x.atMs >= from && x.atMs < to);
      due.forEach((x, n) => {
        if (rows.length) rows.push(<View key={`sp-${x.id}`} style={{ height: Spacing.two }} />);
        rows.push(<LooseExamCard key={x.id} exam={x} now={now} index={n} />);
      });
      return due.length;
    };
    const lead = between(-Infinity, live[0]?.startMs ?? Infinity);
    if (lead.length) rows.push(<Gap key="gap-lead" cubes={lead} />);
    live.forEach((e, i) => {
      const before = live[i - 1];
      // a gap row already spaces the later ones
      if (pushLoose(before?.startMs ?? -Infinity, e.startMs) && !before) rows.push(<View key={`sp-${e.id}`} style={{ height: Spacing.two }} />);
      if (before) {
        const gap = e.startMs - before.endMs;
        rows.push(<Gap key={`gap-${e.id}`} cubes={between(before.endMs, e.startMs)} minutes={gap >= 15 * 60000 ? gap : 0} />);
      }
      rows.push(<EventCard key={e.id} e={e} now={now} index={i} />);
    });
    const tail = live.length ? between(live[live.length - 1].endMs, Infinity) : [];
    if (tail.length) rows.push(<Gap key="gap-tail" cubes={tail} />);
    pushLoose(live.length ? live[live.length - 1].startMs : -Infinity, Infinity);
    body = live.length || loose.length ? (
      <View>{rows}</View>
    ) : (
      <View style={{ gap: Spacing.two }}>
        <Animated.View entering={FadeIn.duration(250)} style={{ paddingVertical: Spacing.five, alignItems: 'center', gap: Spacing.two }}>
          <SymbolView name="sun.max.fill" tintColor={c.warning} size={40} />
          <Text style={{ color: c.text, fontSize: 24, fontWeight: '800' }}>{tx.calendar.freeDay}</Text>
        </Animated.View>
        <Gap cubes={lead} />
      </View>
    );
  }

  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ paddingHorizontal: Spacing.three, paddingTop: Spacing.one, paddingBottom: Spacing.six * 2, gap: Spacing.two }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={c.textSecondary} />}>
      <Text style={{ color: c.textSecondary, fontSize: 13, fontWeight: '600', marginLeft: Spacing.one }}>
        {new Intl.DateTimeFormat(lang === 'hu' ? 'hu-HU' : lang === 'de' ? 'de-DE' : 'en-US', {
          weekday: 'long',
          month: 'long',
          day: 'numeric',
        }).format(new Date(dayMs))}
      </Text>
      {periods.map((p) => {
        const starts = sameDay(p.fromMs, dayMs);
        const ends = sameDay(p.toMs, dayMs);
        const edge = starts || ends;
        return (
        <View
          key={`${p.name}-${p.fromMs}`}
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: Spacing.two,
            backgroundColor: edge ? c.brandSubtle : c.fill,
            borderRadius: Radius.md,
            borderCurve: 'continuous',
            paddingHorizontal: Spacing.three,
            paddingVertical: Spacing.two,
          }}>
          <SymbolView name={starts ? 'flag.fill' : ends ? 'flag.checkered' : 'calendar.badge.clock'} tintColor={edge ? c.brand : c.textSecondary} size={13} />
          <Text numberOfLines={2} style={{ color: c.text, fontSize: 13, flex: 1 }}>
            {p.name}
          </Text>
          <Text style={{ color: edge ? c.brand : c.textTertiary, fontSize: 12, fontWeight: '600' }}>
            {starts ? tx.v2.calendar.periodStarts : ends ? tx.v2.calendar.periodEnds : tx.v2.calendar.periodUntil(fmtDate(p.toMs, lang))}
          </Text>
        </View>
        );
      })}
      {body}
    </ScrollView>
  );
}

const norm = (t: string) => t.trim().toLowerCase().replace(/\s+/g, ' ');

// fixed height so every card sits the same distance apart, break or not
function Gap({ cubes, minutes = 0 }: { cubes: ClassEntry[]; minutes?: number }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  if (!cubes.length && !minutes) return <View style={{ height: Spacing.two }} />;
  return (
    <View style={{ minHeight: 40, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: Spacing.two, paddingVertical: Spacing.one }}>
      {cubes.map((e) => (
        <Pressable
          key={e.id}
          accessibilityLabel={e.title}
          onPress={() => {
            selection();
            router.push({
              pathname: '/class-details',
              params: { title: e.title, start: String(e.startMs), end: String(e.endMs), room: e.location, teacher: e.teacher, code: e.code, type: e.courseType, instance: e.classInstanceId, note: e.note },
            });
          }}
          style={({ pressed }) => ({
            width: 30,
            height: 30,
            borderRadius: 8,
            borderCurve: 'continuous',
            backgroundColor: c.fill,
            alignItems: 'center',
            justifyContent: 'center',
            opacity: pressed ? 0.6 : 1,
          })}>
          <SymbolView name="checkmark" tintColor={c.textTertiary} size={13} weight="semibold" />
        </Pressable>
      ))}
      {minutes ? (
        <Text style={{ color: c.textTertiary, fontSize: 12 }}>{tx.calendar.breakFor(Math.floor(Math.round(minutes / 60000) / 60), Math.round(minutes / 60000) % 60)}</Text>
      ) : null}
    </View>
  );
}

function EventCard({ e, now, index }: { e: ClassEntry; now: number; index: number }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const live = now >= e.startMs && now < e.endMs;
  const past = now >= e.endMs;
  const startsSoon = !live && !past && e.startMs - now < 60 * 60000;
  const accent =
    e.kind === 'exam' ? c.danger : e.kind === 'task' ? c.warning : e.kind === 'other' ? c.purple : live ? c.live : c.brand;
  const kindLabel =
    e.kind === 'exam' ? tx.calendar.exam : e.kind === 'task' ? tx.calendar.task : e.kind === 'other' ? tx.v2.calendar.officeHours : e.courseType;
  const exams = examsFor(useExams(), { title: e.title, startMs: e.startMs, instance: e.classInstanceId });
  const flagged = exams.length > 0 && !past;
  const cheer = live && e.kind === 'class' ? pickCheer(tx.v2.cheer, e.id, e.endMs - now) : null;

  return (
    <Animated.View entering={FadeInDown.duration(260).delay(index * 40)}>
      <Pressable
        onPress={() => {
          selection();
          router.push({
            pathname: '/class-details',
            params: {
              title: e.title,
              start: String(e.startMs),
              end: String(e.endMs),
              room: e.location,
              teacher: e.teacher,
              code: e.code,
              type: kindLabel,
              instance: e.classInstanceId,
              note: e.note,
            },
          });
        }}
        style={({ pressed }) => ({ opacity: past ? 0.5 : pressed ? 0.75 : 1 })}>
        <Card
          style={{
            flexDirection: 'row',
            gap: Spacing.three,
            backgroundColor: live ? c.liveSubtle : c.card,
            borderWidth: flagged ? 1.5 : undefined,
            borderColor: flagged ? c.danger : undefined,
          }}>
          <View style={{ alignItems: 'flex-end', width: 44 }}>
            <Text style={{ color: c.text, fontSize: 14, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{hhmm(e.startMs)}</Text>
            <Text style={{ color: c.textTertiary, fontSize: 13, fontVariant: ['tabular-nums'] }}>{hhmm(e.endMs)}</Text>
          </View>
          <View style={{ width: 4, borderRadius: 2, backgroundColor: flagged ? c.danger : accent }} />
          <View style={{ flex: 1, gap: 4 }}>
            <Text selectable style={{ color: c.text, fontSize: 16, fontWeight: '700' }}>
              {e.title}
            </Text>
            {e.location ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
                <SymbolView name="mappin.and.ellipse" tintColor={c.textSecondary} size={12} />
                <Text numberOfLines={1} selectable style={{ color: c.textSecondary, fontSize: 13, flex: 1 }}>
                  {e.location}
                </Text>
              </View>
            ) : null}
            <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 13 }}>
              {[kindLabel, e.teacher].filter(Boolean).join(' · ')}
            </Text>
            {live ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two, marginTop: 4 }}>
                <View style={{ flex: 1 }}>
                  <ProgressBar value={(now - e.startMs) / (e.endMs - e.startMs)} color={c.live} height={4} />
                </View>
                <Text style={{ color: c.live, fontSize: 12, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
                  {tx.v2.calendar.endsIn(fmtDuration(e.endMs - now))}
                </Text>
              </View>
            ) : null}
            {cheer ? (
              <Animated.Text key={cheer} entering={FadeIn.duration(300)} style={{ color: c.live, fontSize: 13, fontWeight: '600' }}>
                {cheer}
              </Animated.Text>
            ) : null}
            {startsSoon ? (
              <Text style={{ color: c.brand, fontSize: 12, fontWeight: '600' }}>{tx.calendar.startsIn(fmtDuration(e.startMs - now))}</Text>
            ) : null}
            {exams.map((x) => (
              <ExamLine key={x.id} exam={x} />
            ))}
          </View>
          {flagged ? (
            <BlinkingBang />
          ) : (
            <SymbolView name="chevron.right" tintColor={c.textTertiary} size={12} style={{ alignSelf: 'center' }} />
          )}
        </Card>
      </Pressable>
    </Animated.View>
  );
}

// exam added with the + button, its own red card at its own time
function LooseExamCard({ exam, now, index }: { exam: ManualExam; now: number; index: number }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const past = exam.atMs < now - 30 * 60000;
  const sub = [tx.v2.exams.badge, exam.photos.length ? `${exam.photos.length} ${tx.v2.exams.photos.toLowerCase()}` : '']
    .filter(Boolean)
    .join(' · ');
  return (
    <Animated.View entering={FadeInDown.duration(260).delay(index * 40)}>
      <Pressable
        onPress={() => {
          selection();
          router.push({ pathname: '/exam', params: { id: exam.id } });
        }}
        style={({ pressed }) => ({ opacity: past ? 0.5 : pressed ? 0.75 : 1 })}>
        <Card style={{ flexDirection: 'row', gap: Spacing.three, borderWidth: past ? undefined : 1.5, borderColor: past ? undefined : c.danger }}>
          <View style={{ alignItems: 'flex-end', width: 44 }}>
            <Text style={{ color: c.text, fontSize: 14, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{hhmm(exam.atMs)}</Text>
          </View>
          <View style={{ width: 4, borderRadius: 2, backgroundColor: c.danger }} />
          <View style={{ flex: 1, gap: 4 }}>
            <Text selectable style={{ color: c.text, fontSize: 16, fontWeight: '700' }}>
              {exam.title}
            </Text>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
              <SymbolView name={iosMajor >= 17 ? 'pencil.and.list.clipboard' : 'pencil'} tintColor={c.danger} size={12} />
              <Text numberOfLines={1} style={{ color: c.danger, fontSize: 13, fontWeight: '700', flex: 1 }}>
                {sub}
              </Text>
            </View>
            {exam.notes ? (
              <Text numberOfLines={2} style={{ color: c.textSecondary, fontSize: 13 }}>
                {exam.notes}
              </Text>
            ) : null}
          </View>
          {past ? (
            <SymbolView name="chevron.right" tintColor={c.textTertiary} size={12} style={{ alignSelf: 'center' }} />
          ) : (
            <BlinkingBang />
          )}
        </Card>
      </Pressable>
    </Animated.View>
  );
}

function ExamLine({ exam }: { exam: ManualExam }) {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 5 }}>
      <SymbolView name={iosMajor >= 17 ? 'pencil.and.list.clipboard' : 'pencil'} tintColor={c.danger} size={12} />
      <Text numberOfLines={1} style={{ color: c.danger, fontSize: 13, fontWeight: '700', flex: 1 }}>
        {`${exam.title} · ${hhmm(exam.atMs)}`}
      </Text>
    </View>
  );
}

// red circled ! that pulses on the ui thread, impossible to miss
function BlinkingBang() {
  const c = useTheme();
  const { tx } = useI18n();
  const o = useSharedValue(1);
  useEffect(() => {
    o.set(withRepeat(withSequence(withTiming(0.25, { duration: 550 }), withTiming(1, { duration: 550 })), -1));
  }, [o]);
  const style = useAnimatedStyle(() => ({ opacity: o.get() }));
  return (
    <Animated.View style={[{ alignSelf: 'center' }, style]} accessibilityLabel={tx.v2.exams.badge}>
      <SymbolView name="exclamationmark.circle.fill" tintColor={c.danger} size={24} />
    </Animated.View>
  );
}
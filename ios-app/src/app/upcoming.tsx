import { router, Stack } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { useState, type ComponentProps } from 'react';
import { Pressable, Text, View } from 'react-native';
import Animated, { FadeInDown } from 'react-native-reanimated';

import { FillCard } from '@/components/fill-card';
import { EmptyCard, QueryScreen, ScreenTitle } from '@/components/screen';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { daysFromToday, fmtDate, fmtMoney, hhmm } from '@/lib/format';
import { defaultExamTime, useExams } from '@/lib/exams';
import { getPayments, getPeriods, getUpcomingEvents } from '@/neptun/data';

type Kind = 'exam' | 'task' | 'period' | 'payment';
type Item = {
  id: string;
  kind: Kind;
  title: string;
  detail: string;
  atMs: number;
  fromMs?: number;
  open?: boolean;
  examId?: string;
};

// how full the card gets: open period = time used up, anything else fills up over the last 30 days
const WINDOW_DAYS = 30;

export default function UpcomingScreen() {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const [now] = useState(() => Date.now());
  const events = useNeptunQuery('upcoming', getUpcomingEvents);
  const periods = useNeptunQuery('periods', getPeriods);
  const payments = useNeptunQuery('payments', getPayments);
  const mine = useExams();
  const { selection } = useHaptics();

  const items: Item[] = [];
  for (const e of events.data ?? []) {
    if (e.endMs < now) continue;
    items.push({
      id: e.id,
      kind: e.kind === 'exam' ? 'exam' : 'task',
      title: e.title,
      detail: [`${fmtDate(e.startMs, lang)} ${hhmm(e.startMs)}`, e.location, e.teacher].filter(Boolean).join(' · '),
      atMs: e.startMs,
    });
  }
  for (const p of periods.data ?? []) {
    if (p.toMs < now) continue;
    const open = p.fromMs <= now;
    items.push({
      id: `period-${p.name}-${p.fromMs}`,
      kind: 'period',
      title: p.name,
      detail: open ? `${tx.upcoming.openUntil} ${fmtDate(p.toMs, lang)}` : `${tx.upcoming.opens} ${fmtDate(p.fromMs, lang)}`,
      atMs: open ? p.toMs : p.fromMs,
      fromMs: p.fromMs,
      open,
    });
  }
  for (const p of payments.data ?? []) {
    if (p.amount <= 0 || p.done) continue;
    items.push({
      id: `pay-${p.id}`,
      kind: 'payment',
      title: p.title,
      detail: `${fmtMoney(p.amount, lang)} · ${fmtDate(p.dateMs, lang)}`,
      atMs: p.dateMs,
    });
  }
  // the ones added by hand, + button or class sheet
  for (const x of mine) {
    if (x.atMs < now) continue;
    items.push({
      id: `mine-${x.id}`,
      kind: 'exam',
      title: x.title,
      detail: [`${fmtDate(x.atMs, lang)} ${hhmm(x.atMs)}`, x.lesson.title].filter(Boolean).join(' · '),
      atMs: x.atMs,
      examId: x.id,
    });
  }
  items.sort((a, b) => a.atMs - b.atMs);

  const buckets: { label: string; items: Item[] }[] = [
    {
      label: tx.upcoming.thisWeek,
      items: items.filter((i) => daysFromToday(i.atMs, now) <= 7),
    },
    {
      label: tx.upcoming.thisMonth,
      items: items.filter((i) => daysFromToday(i.atMs, now) > 7 && daysFromToday(i.atMs, now) <= 31),
    },
    {
      label: tx.upcoming.later,
      items: items.filter((i) => daysFromToday(i.atMs, now) > 31),
    },
  ];

  return (
    <>
      <ScreenTitle title={tx.upcoming.title} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button
          icon="plus"
          accessibilityLabel={tx.v2.exams.add}
          onPress={() => {
            selection();
            router.push({ pathname: '/exam', params: { at: String(defaultExamTime(Date.now())) } });
          }}
        />
      </Stack.Toolbar>
      <QueryScreen query={events} gap={Spacing.four}>
        {items.length === 0 ? <EmptyCard text={tx.upcoming.empty} icon="checkmark.seal" /> : null}
        {buckets
          .filter((b) => b.items.length > 0)
          .map((b) => (
            <View key={b.label} style={{ gap: Spacing.two }}>
              <Text
                style={{
                  color: c.textSecondary,
                  fontSize: 14,
                  fontWeight: '700',
                  marginLeft: 2,
                }}>
                {b.label}
              </Text>
              {b.items.map((i, n) => (
                <Animated.View key={i.id} entering={FadeInDown.duration(250).delay(Math.min(n, 8) * 35)}>
                  {i.examId ? (
                    <Pressable
                      onPress={() => {
                        selection();
                        router.push({ pathname: '/exam', params: { id: i.examId } });
                      }}
                      style={({ pressed }) => ({ opacity: pressed ? 0.75 : 1 })}>
                      <UpcomingCard item={i} now={now} />
                    </Pressable>
                  ) : (
                    <UpcomingCard item={i} now={now} />
                  )}
                </Animated.View>
              ))}
            </View>
          ))}
      </QueryScreen>
    </>
  );
}

function UpcomingCard({ item, now }: { item: Item; now: number }) {
  const c = useTheme();
  const { tx } = useI18n();
  const days = daysFromToday(item.atMs, now);
  const progress =
    item.open && item.fromMs != null
      ? (now - item.fromMs) / Math.max(1, item.atMs - item.fromMs)
      : Math.max(0.03, 1 - Math.max(0, days) / WINDOW_DAYS);
  // green only while a period is actually running, the ones still ahead are blue
  const color =
    item.kind === 'exam' ? c.danger : item.kind === 'task' ? c.warning : item.kind === 'period' && item.open ? c.live : c.brandText;
  const icon: ComponentProps<typeof SymbolView>['name'] =
    item.kind === 'exam'
      ? 'graduationcap.fill'
      : item.kind === 'task'
        ? 'checklist'
        : item.kind === 'period'
          ? 'calendar'
          : 'banknote.fill';

  return (
    <FillCard progress={progress} color={color}>
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: Spacing.three,
        }}>
        <View
          style={{
            width: 40,
            height: 40,
            borderRadius: Radius.md,
            borderCurve: 'continuous',
            backgroundColor: c.backgroundSelected,
            alignItems: 'center',
            justifyContent: 'center',
          }}>
          <SymbolView name={icon} tintColor={color} size={20} />
        </View>
        <View style={{ flex: 1, gap: 2 }}>
          <Text selectable style={{ color: c.text, fontSize: 15, fontWeight: '700' }}>
            {item.title}
          </Text>
          <Text style={{ color: c.textSecondary, fontSize: 12 }}>{item.detail}</Text>
        </View>
        <Text
          style={{
            color,
            fontSize: 15,
            fontWeight: '800',
            fontVariant: ['tabular-nums'],
          }}>
          {item.open
            ? tx.common.daysLeft(Math.max(0, days))
            : days <= 0
              ? tx.upcoming.today
              : days === 1
                ? tx.upcoming.tomorrow
                : tx.upcoming.inDays(days)}
        </Text>
      </View>
    </FillCard>
  );
}
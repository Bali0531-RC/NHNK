import { useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Text, View } from 'react-native';
import Animated, { FadeInDown } from 'react-native-reanimated';

import { FillCard } from '@/components/fill-card';
import { DividerLabel, EmptyCard, QueryScreen, ScreenTitle } from '@/components/screen';
import { Spacing } from '@/constants/theme';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTerm } from '@/hooks/use-term';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { daysFromToday, fmtDate } from '@/lib/format';
import { getPeriods, getTermPeriods, type PeriodEntry } from '@/neptun/data';

type Group = 'active' | 'future' | 'expired';

export default function PeriodsScreen() {
  const c = useTheme();
  const { t, tx } = useI18n();
  const { list: terms, termId, termName, isLatest } = useTerm();
  const term = terms.find((x) => x.id === termId);
  // newest term keeps the two-term merge so a running exam period survives next term's registration opening
  const past = !isLatest && term != null;
  const query = useNeptunQuery(past ? `periods.${term.id}` : 'periods', () => (past ? getTermPeriods(term) : getPeriods()));
  const [now, setNow] = useState(() => Date.now());
  // tabs stay mounted, refresh the clock on every visit so the fills are right
  useFocusEffect(
    useCallback(() => {
      setNow(Date.now());
    }, []),
  );
  const list = query.data ?? [];

  const active = list.filter((p) => p.fromMs <= now && now <= p.toMs).sort((a, b) => a.toMs - b.toMs);
  const future = list.filter((p) => p.fromMs > now).sort((a, b) => a.fromMs - b.fromMs);
  const expired = list.filter((p) => p.toMs < now).sort((a, b) => b.toMs - a.toMs);

  const groups: {
    key: Group;
    label: string;
    color: string;
    items: PeriodEntry[];
  }[] = [
    { key: 'active', label: tx.periods.active, color: c.live, items: active },
    {
      key: 'future',
      label: tx.periods.future,
      color: c.brandText,
      items: future,
    },
    {
      key: 'expired',
      label: tx.periods.expired,
      color: c.textSecondary,
      items: expired,
    },
  ];

  const over = list.length > 0 && active.length === 0 && future.length === 0;
  const summary = query.data ? tx.periods.summary(active.length, future.length, expired.length) : null;

  return (
    <>
      <ScreenTitle title={t.tabs.periods} subtitle={summary && termName ? `${termName} · ${summary}` : summary} />
      <QueryScreen query={query} gap={Spacing.five}>
        {list.length === 0 ? <EmptyCard text={tx.periods.empty} icon="timer" /> : null}
        {over ? <EmptyCard text={tx.periods.allOver} icon="checkmark.circle" /> : null}
        <View style={{ gap: Spacing.five }}>
          {groups
            .filter((g) => g.items.length > 0)
            .map((g) => (
              <View key={g.key} style={{ gap: Spacing.three }}>
                <DividerLabel label={g.label} color={g.color} />
                {g.items.map((p, i) => (
                  <Animated.View key={`${p.name}-${p.fromMs}-${i}`} entering={FadeInDown.duration(250).delay(Math.min(i, 8) * 35)}>
                    <PeriodCard p={p} group={g.key} now={now} />
                  </Animated.View>
                ))}
              </View>
            ))}
        </View>
      </QueryScreen>
    </>
  );
}

function PeriodCard({ p, group, now }: { p: PeriodEntry; group: Group; now: number }) {
  const c = useTheme();
  const { tx, lang } = useI18n();
  // gray cards, the fill does the talking: active = time used up, future = closing in over 60 days
  const accent = group === 'active' ? c.live : group === 'future' ? c.brandText : c.textSecondary;
  const progress =
    group === 'active'
      ? (now - p.fromMs) / Math.max(1, p.toMs - p.fromMs)
      : group === 'future'
        ? Math.max(0.03, 1 - daysFromToday(p.fromMs, now) / 60)
        : 0;

  let note: string;
  if (group === 'active') note = tx.common.daysLeft(Math.max(0, daysFromToday(p.toMs, now)));
  else if (group === 'future') note = tx.periods.startsIn(daysFromToday(p.fromMs, now));
  else note = tx.periods.endedAgo(-daysFromToday(p.toMs, now));

  return (
    <FillCard progress={progress} color={group === 'active' ? c.live : c.brand} style={{ opacity: group === 'expired' ? 0.75 : 1 }}>
      <View style={{ gap: Spacing.two }}>
        <Text
          selectable
          style={{
            color: group === 'expired' ? c.textSecondary : c.text,
            fontSize: 16,
            fontWeight: '700',
            textAlign: 'center',
          }}>
          {p.name}
        </Text>
        <View style={{ flexDirection: 'row', justifyContent: 'space-around' }}>
          <DateCol label={tx.periods.from} ms={p.fromMs} lang={lang} color={accent} />
          <DateCol label={tx.periods.to} ms={p.toMs} lang={lang} color={accent} />
        </View>
        <Text
          style={{
            color: group === 'active' ? c.live : c.textSecondary,
            fontSize: 13,
            fontWeight: '600',
            textAlign: 'center',
          }}>
          {note}
        </Text>
      </View>
    </FillCard>
  );
}

function DateCol({ label, ms, lang, color }: { label: string; ms: number; lang: string; color: string }) {
  const c = useTheme();
  return (
    <View style={{ alignItems: 'center' }}>
      <Text style={{ color: c.textTertiary, fontSize: 12 }}>
        {label} {new Date(ms).getFullYear()}
      </Text>
      <Text style={{ color, fontSize: 15, fontWeight: '700' }}>{fmtDate(ms, lang)}</Text>
    </View>
  );
}
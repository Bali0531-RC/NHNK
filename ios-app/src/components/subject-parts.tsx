import { Button, Divider, Host, Menu, Picker, Text as SText } from '@expo/ui/swift-ui';
import { pickerStyle, tag } from '@expo/ui/swift-ui/modifiers';
import { SymbolView } from 'expo-symbols';
import { useState } from 'react';
import { Alert, Pressable, Text, View } from 'react-native';
import Animated, { FadeIn, FadeOut, LinearTransition } from 'react-native-reanimated';

import { CreditGauge } from '@/components/credit-gauge';
import { Card } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { COURSE_KINDS, realEnd, useClassEnds, type CourseKind } from '@/hooks/use-class-ends';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { avgEmoji, fmtAvg, hhmm } from '@/lib/format';
import type { Override, TermStats } from '@/lib/grades';
import type { SubjectEntry } from '@/neptun/data';

const MINUTES = Array.from({ length: 60 }, (_, i) => i);
// the usual suspects for the quick menu, the wheel on the subject page has every minute
const QUICK_MINUTES = [30, 40, 45, 50, 55];
export const mm = (m: number) => String(m).padStart(2, '0');

const GRADE_ICONS = { 1: '1.circle', 2: '2.circle', 3: '3.circle', 4: '4.circle', 5: '5.circle' } as const;

type InfoKey = 'completed' | 'arithmetic' | 'weighted' | 'creditIndex' | 'correctedIndex';

export function StatsCard({ stats }: { stats: TermStats }) {
  const c = useTheme();
  const { tx } = useI18n();
  const rows: { key: InfoKey; value: string; strong?: boolean }[] = [
    { key: 'arithmetic', value: fmtAvg(stats.arithmetic) },
    { key: 'weighted', value: `${fmtAvg(stats.weighted)} ${stats.weighted ? avgEmoji(stats.weighted) : ''}`, strong: true },
    { key: 'creditIndex', value: stats.creditIndex ? stats.creditIndex.toFixed(2) : '-' },
    { key: 'correctedIndex', value: stats.correctedIndex ? stats.correctedIndex.toFixed(2) : '-' },
  ];
  return (
    <Card style={{ paddingVertical: Spacing.one }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three, paddingVertical: Spacing.two }}>
        <CreditGauge value={stats.completed} max={stats.taken} size={72} color={stats.completed >= stats.taken ? c.live : c.brand} />
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={{ color: c.text, fontSize: 17, fontWeight: '700' }}>{tx.v2.subjects.info.completed.title}</Text>
          <Text selectable style={{ color: c.textSecondary, fontSize: 13, fontVariant: ['tabular-nums'] }}>{tx.stats.done(stats.completed, stats.taken)}</Text>
        </View>
      </View>
      {rows.map((r, i) => (
        <StatRow key={r.key} info={r.key} value={r.value} strong={r.strong} first={false} altered={stats.altered} />
      ))}
      <Text style={{ color: c.textTertiary, fontSize: 11, textAlign: 'center', paddingBottom: Spacing.two }}>
        {tx.v2.subjects.infoTitle}
      </Text>
    </Card>
  );
}

function StatRow({ info, value, strong, first, altered }: { info: InfoKey; value: string; strong?: boolean; first: boolean; altered: boolean }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const [open, setOpen] = useState(false);
  const text = tx.v2.subjects.info[info];
  return (
    <Animated.View layout={LinearTransition.duration(220)} style={{ borderTopWidth: first ? 0 : 0.5, borderTopColor: c.separator }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two, paddingVertical: Spacing.two + 2 }}>
        <Text style={{ color: c.text, fontSize: 15, flex: 1 }}>{text.title}</Text>
        <Text
          selectable
          style={{
            color: altered ? c.purple : strong ? c.brand : c.text,
            fontSize: strong ? 17 : 15,
            fontWeight: '700',
            fontVariant: ['tabular-nums'],
          }}>
          {value}
        </Text>
        <Pressable
          hitSlop={10}
          accessibilityLabel={text.title}
          onPress={() => {
            selection();
            setOpen((o) => !o);
          }}>
          <SymbolView name={open ? 'info.circle.fill' : 'info.circle'} tintColor={c.brand} size={18} />
        </Pressable>
      </View>
      {open ? (
        <Animated.View
          entering={FadeIn.duration(180)}
          exiting={FadeOut.duration(120)}
          style={{
            backgroundColor: c.brandSubtle,
            borderRadius: Radius.md,
            borderCurve: 'continuous',
            padding: Spacing.three,
            marginBottom: Spacing.two,
          }}>
          <Text style={{ color: c.text, fontSize: 13, lineHeight: 19 }}>{text.body}</Text>
        </Animated.View>
      ) : null}
    </Animated.View>
  );
}

export function AlteredBanner({ onReset }: { onReset: () => void }) {
  const c = useTheme();
  const { t, tx } = useI18n();
  const { notify } = useHaptics();
  return (
    <Animated.View entering={FadeIn.duration(220)} exiting={FadeOut.duration(180)} layout={LinearTransition}>
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          gap: Spacing.two,
          backgroundColor: c.purple + '22',
          borderRadius: Radius.lg,
          borderCurve: 'continuous',
          paddingVertical: Spacing.two + 2,
          paddingHorizontal: Spacing.three,
        }}>
        <SymbolView name="wand.and.stars" tintColor={c.purple} size={16} />
        <Text style={{ color: c.text, fontSize: 13, flex: 1, lineHeight: 18 }}>{tx.v2.subjects.altered}</Text>
        <Pressable
          onPress={() =>
            Alert.alert(tx.v2.subjects.reset, tx.v2.subjects.resetConfirm, [
              { text: t.common.cancel, style: 'cancel' },
              {
                text: tx.v2.subjects.reset,
                style: 'destructive',
                onPress: () => {
                  notify();
                  onReset();
                },
              },
            ])
          }
          style={({ pressed }) => ({
            backgroundColor: c.purple,
            borderRadius: Radius.pill,
            paddingHorizontal: 12,
            paddingVertical: 6,
            opacity: pressed ? 0.7 : 1,
          })}>
          <Text style={{ color: '#FFFFFF', fontSize: 13, fontWeight: '700' }}>{tx.v2.subjects.reset}</Text>
        </Pressable>
      </View>
    </Animated.View>
  );
}

export function GradeBadge({ grade, passFail, completed, altered }: { grade: number; passFail: boolean; completed: boolean; altered: boolean }) {
  const c = useTheme();
  const color = grade >= 1 ? c.grade[grade] : c.textTertiary;
  return (
    <View
      style={{
        width: 44,
        height: 44,
        borderRadius: 12,
        borderCurve: 'continuous',
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: altered ? 1.5 : 0,
        borderStyle: altered ? 'dashed' : 'solid',
        borderColor: c.purple,
        backgroundColor: grade >= 1 ? color + '26' : c.fill,
      }}>
      {grade >= 1 ? (
        <Text style={{ color, fontSize: 22, fontWeight: '800' }}>{grade}</Text>
      ) : passFail || completed ? (
        <SymbolView name="checkmark" tintColor={c.success} size={20} weight="bold" />
      ) : (
        <SymbolView name="minus" tintColor={c.textTertiary} size={16} />
      )}
    </View>
  );
}

// Native menu on each subject card for quick what-ifs without opening the subject.
export function SubjectQuickMenu({
  s,
  effectiveCompleted,
  hasOverride,
  onChange,
}: {
  s: SubjectEntry;
  effectiveCompleted: boolean;
  hasOverride: boolean;
  onChange: (patch: Override | null) => void;
}) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const { minuteOf, setMinute } = useClassEnds();
  const t = tx.v2.subjects.classEnd;
  const set = (patch: Override | null) => {
    selection();
    onChange(patch);
  };
  const setEnd = (m: number | null, kind: CourseKind) => {
    selection();
    setMinute(s, m, kind);
  };
  return (
    <Host matchContents colorScheme={c.scheme}>
      <Menu label="" systemImage="ellipsis.circle">
        {([5, 4, 3, 2, 1] as const).map((g) => (
          <Button key={g} label={`${tx.v2.subjects.gradeLabel}: ${g}`} systemImage={GRADE_ICONS[g]} onPress={() => set({ grade: g })} />
        ))}
        <Button label={tx.v2.subjects.noGrade} systemImage="minus.circle" onPress={() => set({ grade: 0 })} />
        <Divider />
        <Button
          label={effectiveCompleted ? tx.v2.subjects.markIncomplete : tx.v2.subjects.markComplete}
          systemImage={effectiveCompleted ? 'xmark.circle' : 'checkmark.circle'}
          onPress={() => set({ completed: !effectiveCompleted })}
        />
        {hasOverride ? (
          <Button label={tx.v2.subjects.restore} systemImage="arrow.uturn.backward" role="destructive" onPress={() => set(null)} />
        ) : null}
        <Divider />
        <Menu label={t.title} systemImage="clock">
          {COURSE_KINDS.map((k) => {
            const minute = minuteOf(s.name, k);
            const quick = minute === null || QUICK_MINUTES.includes(minute) ? QUICK_MINUTES : [...QUICK_MINUTES, minute].sort((a, b) => a - b);
            return (
              <Menu key={k} label={minute === null ? t.kinds[k] : `${t.kinds[k]} :${mm(minute)}`}>
                {quick.map((m) => (
                  <Button key={m} label={`:${mm(m)}`} systemImage={m === minute ? 'checkmark' : undefined} onPress={() => setEnd(m, k)} />
                ))}
                <Divider />
                <Button label={t.neptun} systemImage={minute === null ? 'checkmark' : undefined} onPress={() => setEnd(null, k)} />
              </Menu>
            );
          })}
        </Menu>
      </Menu>
    </Host>
  );
}

// when the lecturer actually lets everyone go. native wheel, minutes only, the hour stays whatever neptun says
export function ClassEndCard({ s }: { s: SubjectEntry }) {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const { minuteOf, setMinute } = useClassEnds();
  const [kind, setKind] = useState<CourseKind>('all');
  const minute = minuteOf(s.name, kind);
  const t = tx.v2.subjects.classEnd;
  const sample = new Date(2026, 0, 5, 10, 0).getTime();
  return (
    <Card style={{ gap: Spacing.two }}>
      <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18 }}>{t.hint}</Text>
      <Host matchContents={{ vertical: true }} colorScheme={c.scheme} style={{ alignSelf: 'stretch' }}>
        <Picker
          selection={kind}
          onSelectionChange={(v: string) => {
            selection();
            setKind(v as CourseKind);
          }}
          modifiers={[pickerStyle('segmented')]}>
          {COURSE_KINDS.map((k) => (
            <SText key={k} modifiers={[tag(k)]}>{t.kinds[k]}</SText>
          ))}
        </Picker>
      </Host>
      {kind === 'all' ? <Text style={{ color: c.textTertiary, fontSize: 12, lineHeight: 16 }}>{t.kindHint}</Text> : null}
      <Host matchContents={{ vertical: true }} colorScheme={c.scheme} style={{ alignSelf: 'stretch' }}>
        <Picker
          selection={minute ?? -1}
          onSelectionChange={(v: number) => {
            if (v === (minute ?? -1)) return;
            selection();
            setMinute(s, v < 0 ? null : v, kind);
          }}
          modifiers={[pickerStyle('wheel')]}>
          <SText modifiers={[tag(-1)]}>{t.neptun}</SText>
          {MINUTES.map((m) => (
            <SText key={m} modifiers={[tag(m)]}>{`:${mm(m)}`}</SText>
          ))}
        </Picker>
      </Host>
      <Text style={{ color: minute === null ? c.textTertiary : c.live, fontSize: 13, fontWeight: '600', textAlign: 'center' }}>
        {minute === null ? t.unset : t.example(hhmm(realEnd(sample, sample + 2 * 3_600_000, minute)))}
      </Text>
      {minute !== null ? (
        <Host matchContents colorScheme={c.scheme} style={{ alignSelf: 'center' }}>
          <Button
            label={t.reset}
            systemImage="arrow.uturn.backward"
            role="destructive"
            onPress={() => {
              selection();
              setMinute(s, null, kind);
            }}
          />
        </Host>
      ) : null}
    </Card>
  );
}
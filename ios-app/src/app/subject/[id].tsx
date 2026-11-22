import { useLocalSearchParams } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, ScrollView, Switch, Text, View } from 'react-native';
import Animated, { FadeIn, LinearTransition } from 'react-native-reanimated';

import { CommentsCard } from '@/components/comments-card';
import { DetailList, DividerLabel, EmptyCard, ScreenTitle } from '@/components/screen';
import { AlteredBanner, ClassEndCard, GradeBadge } from '@/components/subject-parts';
import { Card, SkeletonList } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useOverrides } from '@/hooks/use-overrides';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtAvg } from '@/lib/format';
import { effective, termStats } from '@/lib/grades';
import { commentsOf, getSubjects } from '@/neptun/data';

// one subject plus the what-if grade calculator
export default function SubjectDetail() {
  const c = useTheme();
  const { tx } = useI18n();
  const { selection } = useHaptics();
  const { id, term } = useLocalSearchParams<{ id: string; term: string }>();
  const subjects = useNeptunQuery(term ? `subjects.${term}` : null, () => getSubjects(term ?? ''));
  const { overrides, setOverride } = useOverrides(term ?? null);
  const list = subjects.data ?? [];
  const s = list.find((x) => x.id === id);

  if (!s) {
    return (
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ padding: Spacing.three }}>
        <ScreenTitle title={tx.v2.common.details} />
        {subjects.loading ? <SkeletonList rows={3} /> : <EmptyCard text={tx.subjects.empty} icon="books.vertical" />}
      </ScrollView>
    );
  }

  const o = overrides[s.id];
  const e = effective(s, o);
  const real = termStats(list, {});
  const planned = termStats(list, overrides);
  const grades = [0, 1, 2, 3, 4, 5];
  const comments = commentsOf(s.details);
  const rest = s.details.filter((r) => !comments.includes(r.value.trim()));

  const compare: { label: string; a: string; b: string }[] = [
    { label: tx.v2.subjects.info.weighted.title, a: fmtAvg(real.weighted), b: fmtAvg(planned.weighted) },
    { label: tx.v2.subjects.info.creditIndex.title, a: real.creditIndex.toFixed(2), b: planned.creditIndex.toFixed(2) },
    { label: tx.v2.subjects.info.correctedIndex.title, a: real.correctedIndex.toFixed(2), b: planned.correctedIndex.toFixed(2) },
    { label: tx.v2.subjects.info.completed.title, a: `${real.completed}`, b: `${planned.completed}` },
  ];

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.three, paddingBottom: Spacing.six }}>
      <ScreenTitle title={s.name} subtitle={s.code} />
      <CommentsCard items={comments} />

      <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
        <GradeBadge grade={e.grade} passFail={s.passFail} completed={e.completed} altered={e.altered} />
        <View style={{ flex: 1, gap: 2 }}>
          <Text selectable style={{ color: c.text, fontSize: 18, fontWeight: '700' }}>
            {s.name}
          </Text>
          <Text style={{ color: c.textSecondary, fontSize: 13 }}>
            {[tx.subjects.creditCount(s.credit), s.requirement, s.code].filter(Boolean).join(' · ')}
          </Text>
          <Text style={{ color: e.completed ? c.success : c.textSecondary, fontSize: 13, fontWeight: '600' }}>
            {s.resultText || (s.completed ? tx.v2.subjects.complete : tx.v2.subjects.incomplete)}
          </Text>
        </View>
      </Card>

      {e.altered ? <AlteredBanner onReset={() => setOverride(s.id, null)} /> : null}

      <DividerLabel label={tx.v2.subjects.classEnd.title} />
      <ClassEndCard s={s} />

      <DividerLabel label={tx.v2.subjects.calculator} />
      <Animated.View layout={LinearTransition}>
        <Card style={{ gap: Spacing.three }}>
          <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18 }}>{tx.v2.subjects.calculatorHint}</Text>
          <View style={{ gap: Spacing.two }}>
            <Text style={{ color: c.text, fontSize: 15, fontWeight: '600' }}>{tx.v2.subjects.gradeLabel}</Text>
            <View style={{ flexDirection: 'row', gap: 6 }}>
              {grades.map((g) => {
                const active = e.grade === g;
                return (
                  <Pressable
                    key={g}
                    onPress={() => {
                      if (active) return;
                      selection();
                      setOverride(s.id, g === s.grade && o?.completed === undefined ? null : { grade: g });
                    }}
                    style={{
                      flex: 1,
                      height: 44,
                      borderRadius: Radius.md,
                      borderCurve: 'continuous',
                      alignItems: 'center',
                      justifyContent: 'center',
                      backgroundColor: active ? (g ? c.grade[g] : c.textSecondary) : c.fill,
                    }}>
                    {g ? (
                      <Text style={{ color: active ? '#FFFFFF' : c.text, fontSize: 18, fontWeight: '800' }}>{g}</Text>
                    ) : (
                      <SymbolView name="minus" tintColor={active ? '#FFFFFF' : c.textSecondary} size={16} />
                    )}
                  </Pressable>
                );
              })}
            </View>
          </View>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
            <Text style={{ color: c.text, fontSize: 15, fontWeight: '600', flex: 1 }}>{tx.v2.subjects.complete}</Text>
            <Switch
              value={e.completed}
              onValueChange={(v) => {
                selection();
                setOverride(s.id, { completed: v });
              }}
            />
          </View>
          {o ? (
            <Pressable
              onPress={() => {
                selection();
                setOverride(s.id, null);
              }}
              style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, opacity: pressed ? 0.6 : 1 })}>
              <SymbolView name="arrow.uturn.backward" tintColor={c.danger} size={14} />
              <Text style={{ color: c.danger, fontSize: 15, fontWeight: '600' }}>{tx.v2.subjects.restore}</Text>
            </Pressable>
          ) : null}
        </Card>
      </Animated.View>

      <DividerLabel label={tx.v2.subjects.impact} />
      <Card style={{ paddingVertical: Spacing.one }}>
        <View style={{ flexDirection: 'row', paddingVertical: Spacing.two }}>
          <Text style={{ flex: 1 }} />
          <Text style={{ color: c.textSecondary, fontSize: 12, width: 72, textAlign: 'right' }}>{tx.v2.subjects.real}</Text>
          <Text style={{ color: c.purple, fontSize: 12, width: 72, textAlign: 'right' }}>{tx.v2.subjects.planned}</Text>
        </View>
        {compare.map((r) => (
          <View key={r.label} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: Spacing.two, borderTopWidth: 0.5, borderTopColor: c.separator }}>
            <Text style={{ color: c.text, fontSize: 14, flex: 1 }}>{r.label}</Text>
            <Text style={{ color: c.textSecondary, fontSize: 15, width: 72, textAlign: 'right', fontVariant: ['tabular-nums'] }}>{r.a}</Text>
            <Animated.Text
              key={r.b}
              entering={FadeIn.duration(200)}
              style={{
                color: r.a !== r.b ? c.purple : c.text,
                fontSize: 15,
                fontWeight: '700',
                width: 72,
                textAlign: 'right',
                fontVariant: ['tabular-nums'],
              }}>
              {r.b}
            </Animated.Text>
          </View>
        ))}
      </Card>

      {rest.length > 0 ? (
        <>
          <DividerLabel label={tx.v2.subjects.neptunData} />
          <DetailList rows={rest} />
        </>
      ) : null}
    </ScrollView>
  );
}
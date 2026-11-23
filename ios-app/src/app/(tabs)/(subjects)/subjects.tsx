import { router, Stack } from 'expo-router';
import { Pressable, Text, View } from 'react-native';
import Animated, { FadeInDown, LinearTransition } from 'react-native-reanimated';

import { DividerLabel, EmptyCard, QueryScreen, ScreenTitle } from '@/components/screen';
import { AlteredBanner, GradeBadge, mm, StatsCard, SubjectQuickMenu } from '@/components/subject-parts';
import { Card, SkeletonList } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useClassEnds, type CourseKind } from '@/hooks/use-class-ends';
import { useHaptics } from '@/hooks/use-haptics';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useOverrides } from '@/hooks/use-overrides';
import { useTerm } from '@/hooks/use-term';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { effective, termStats, type Override } from '@/lib/grades';
import { getSubjects, type SubjectEntry } from '@/neptun/data';

export default function SubjectsScreen() {
  const { t, tx } = useI18n();
  const { selection } = useHaptics();
  const { terms, list: termList, termId, termName, setTermId } = useTerm();
  const subjects = useNeptunQuery(termId ? `subjects.${termId}` : null, () => getSubjects(termId ?? ''));
  const { overrides, setOverride, resetTerm } = useOverrides(termId);

  const list = subjects.data ?? [];
  const stats = termStats(list, overrides);
  const withEff = list.map((s) => ({ s, e: effective(s, overrides[s.id]) }));
  const open = withEff.filter((x) => !x.e.completed);
  const done = withEff.filter((x) => x.e.completed);
  const shown = termId ? subjects : terms;

  return (
    <>
      <ScreenTitle title={t.tabs.subjects} subtitle={subjects.data ? tx.subjects.creditsThisSemester(stats.taken) : null} />
      {termList.length > 1 ? (
        <Stack.Toolbar placement="right">
          <Stack.Toolbar.Menu icon="calendar.badge.clock" title={tx.v2.menu.semester}>
            {[...termList].reverse().map((term) => (
              <Stack.Toolbar.MenuAction
                key={term.id}
                isOn={term.id === termId}
                onPress={() => {
                  selection();
                  setTermId(term.id);
                }}>
                {term.name}
              </Stack.Toolbar.MenuAction>
            ))}
          </Stack.Toolbar.Menu>
        </Stack.Toolbar>
      ) : null}
      <QueryScreen query={shown} skeleton={<SkeletonList rows={6} height={56} />}>
        <DividerLabel label={termName} />
        {stats.altered ? <AlteredBanner onReset={resetTerm} /> : null}
        <Animated.View layout={LinearTransition}>
          <StatsCard stats={stats} />
        </Animated.View>

        {termId && list.length === 0 && subjects.data ? <EmptyCard text={tx.subjects.empty} icon="books.vertical" /> : null}

        {open.length > 0 ? (
          <Animated.View layout={LinearTransition} style={{ gap: Spacing.two }}>
            {open.map((x, i) => (
              <SubjectCard
                key={x.s.id}
                s={x.s}
                index={i}
                termId={termId ?? ''}
                override={overrides[x.s.id]}
                onChange={(p) => setOverride(x.s.id, p)}
              />
            ))}
          </Animated.View>
        ) : null}

        {done.length > 0 ? (
          <Animated.View layout={LinearTransition} style={{ gap: Spacing.two }}>
            <DividerLabel label={tx.subjects.completed} />
            {done.map((x, i) => (
              <SubjectCard
                key={x.s.id}
                s={x.s}
                index={i}
                termId={termId ?? ''}
                override={overrides[x.s.id]}
                onChange={(p) => setOverride(x.s.id, p)}
              />
            ))}
          </Animated.View>
        ) : null}
      </QueryScreen>
    </>
  );
}

function SubjectCard({
  s,
  index,
  termId,
  override,
  onChange,
}: {
  s: SubjectEntry;
  index: number;
  termId: string;
  override: Override | undefined;
  onChange: (patch: Override | null) => void;
}) {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const { selection } = useHaptics();
  const e = effective(s, override);
  const ends = useClassEnds().minutesOf(s.name);
  const kindName = (k: CourseKind) => (lang === 'de' ? tx.v2.subjects.classEnd.kinds[k] : tx.v2.subjects.classEnd.kinds[k].toLowerCase());
  const endLabel = ends.length
    ? tx.v2.subjects.classEnd.badge(ends.map((x) => (x.kind === 'all' ? `:${mm(x.minute)}` : `${kindName(x.kind)} :${mm(x.minute)}`)).join(', '))
    : '';

  return (
    <Animated.View entering={FadeInDown.duration(250).delay(Math.min(index, 10) * 30)} layout={LinearTransition}>
      <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
        <Pressable
          onPress={() => {
            selection();
            router.push({ pathname: '/subject/[id]', params: { id: s.id, term: termId } });
          }}
          style={({ pressed }) => ({ flex: 1, flexDirection: 'row', alignItems: 'center', gap: Spacing.three, opacity: pressed ? 0.6 : 1 })}>
          <GradeBadge grade={e.grade} passFail={s.passFail} completed={e.completed} altered={e.altered} />
          <View style={{ flex: 1, gap: 2 }}>
            <Text style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>{s.name}</Text>
            <Text numberOfLines={1} style={{ color: c.textSecondary, fontSize: 13 }}>
              {[tx.subjects.creditCount(s.credit), s.requirement, s.code, endLabel]
                .filter(Boolean)
                .join(' · ')}
            </Text>
            {e.altered ? (
              <Text style={{ color: c.purple, fontSize: 12, fontWeight: '600' }}>
                {tx.v2.subjects.planned} · {tx.v2.subjects.real}: {s.grade >= 1 ? s.grade : s.completed ? tx.v2.subjects.complete : tx.v2.subjects.noGrade}
              </Text>
            ) : null}
          </View>
        </Pressable>
        <SubjectQuickMenu s={s} effectiveCompleted={e.completed} hasOverride={!!override} onChange={onChange} />
      </Card>
    </Animated.View>
  );
}
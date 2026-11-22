import { router, useLocalSearchParams } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, ScrollView, Text, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';

import { CommentsCard } from '@/components/comments-card';
import { DetailList } from '@/components/screen';
import { Skeleton } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtLongDate, hhmm } from '@/lib/format';
import { examsFor, useExams } from '@/lib/exams';
import { commentsOf, getCourseDetails } from '@/neptun/data';

// everything about one calendar entry, neptun course details included
export default function ClassDetails() {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const p = useLocalSearchParams<{
    title: string;
    start: string;
    end: string;
    room: string;
    teacher: string;
    code: string;
    type: string;
    instance: string;
    note: string;
  }>();
  const start = Number(p.start) || 0;
  const end = Number(p.end) || 0;
  const { selection } = useHaptics();
  const exams = examsFor(useExams(), { title: p.title ?? '', startMs: start, instance: p.instance });
  const openExam = (id?: string) => {
    selection();
    router.push({
      pathname: '/exam',
      params: { id, title: p.title ?? '', start: String(start), end: String(end), instance: p.instance ?? '' },
    });
  };
  const details = useNeptunQuery(p.instance ? `course.${p.instance}` : null, () => getCourseDetails(p.instance ?? ''));

  const rows = [
    { label: tx.v2.calendar.time, value: start ? `${fmtLongDate(start, lang)}\n${hhmm(start)} - ${hhmm(end)}` : '' },
    { label: tx.v2.calendar.room, value: p.room ?? '' },
    { label: tx.v2.calendar.teacher, value: p.teacher ?? '' },
    { label: tx.v2.calendar.code, value: p.code ?? '' },
    { label: tx.v2.calendar.type, value: p.type ?? '' },
  ].filter((r) => r.value);
  const all = details.data ?? [];
  // event note + any comment-ish course field, profs hide the real room in there
  const comments = commentsOf(all, ...(p.note ?? '').split(/\n{2,}/));
  const extra = all.filter((r) => !rows.some((x) => x.value === r.value) && !comments.includes(r.value.trim()));

  return (
    <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: Spacing.four, paddingTop: Spacing.five, gap: Spacing.three }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
        <SymbolView name="calendar" tintColor={c.brand} size={20} />
        <Text style={{ color: c.textSecondary, fontSize: 13, fontWeight: '600', textTransform: 'uppercase' }}>
          {tx.v2.calendar.classDetails}
        </Text>
      </View>
      <Text selectable style={{ color: c.text, fontSize: 24, fontWeight: '800' }}>
        {p.title}
      </Text>
      <CommentsCard items={comments} />
      {exams.map((x) => (
        <Pressable
          key={x.id}
          onPress={() => openExam(x.id)}
          style={({ pressed }) => ({
            opacity: pressed ? 0.7 : 1,
            backgroundColor: c.dangerSubtle,
            borderRadius: 14,
            borderCurve: 'continuous',
            padding: Spacing.three,
            flexDirection: 'row',
            alignItems: 'center',
            gap: Spacing.three,
          })}>
          <SymbolView name="exclamationmark.circle.fill" tintColor={c.danger} size={26} />
          <View style={{ flex: 1, gap: 2 }}>
            <Text style={{ color: c.text, fontSize: 16, fontWeight: '700' }}>{x.title}</Text>
            <Text style={{ color: c.textSecondary, fontSize: 13 }}>
              {[
                `${fmtLongDate(x.atMs, lang)} ${hhmm(x.atMs)}`,
                x.photos.length ? `${x.photos.length} ${tx.v2.exams.photos.toLowerCase()}` : '',
              ]
                .filter(Boolean)
                .join(' · ')}
            </Text>
            {x.notes ? (
              <Text numberOfLines={2} style={{ color: c.textSecondary, fontSize: 13 }}>
                {x.notes}
              </Text>
            ) : null}
          </View>
          <SymbolView name="chevron.right" tintColor={c.textTertiary} size={12} />
        </Pressable>
      ))}
      {start ? (
        <Pressable
          onPress={() => openExam()}
          style={({ pressed }) => ({
            opacity: pressed ? 0.6 : 1,
            flexDirection: 'row',
            alignItems: 'center',
            gap: Spacing.two,
            paddingVertical: Spacing.one,
          })}>
          <SymbolView name="plus.circle.fill" tintColor={c.brand} size={20} />
          <Text style={{ color: c.brand, fontSize: 16, fontWeight: '600' }}>{tx.v2.exams.add}</Text>
        </Pressable>
      ) : null}
      <DetailList rows={rows} />
      {p.instance ? (
        details.data ? (
          extra.length ? (
            <Animated.View entering={FadeIn.duration(250)}>
              <DetailList rows={extra} />
            </Animated.View>
          ) : (
            <Text style={{ color: c.textTertiary, fontSize: 13, textAlign: 'center' }}>{tx.v2.calendar.noDetails}</Text>
          )
        ) : details.loading ? (
          <View style={{ gap: Spacing.two }}>
            <Skeleton width="100%" height={18} />
            <Skeleton width="80%" height={18} />
            <Skeleton width="90%" height={18} />
          </View>
        ) : null
      ) : null}
    </ScrollView>
  );
}
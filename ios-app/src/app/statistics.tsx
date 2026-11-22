import { Text, View } from 'react-native';

import { CreditBar, CreditGauge } from '@/components/credit-gauge';
import { QueryScreen, ScreenTitle } from '@/components/screen';
import { Card } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { avgEmoji, fmtAvg } from '@/lib/format';
import { termStats, type TermStats } from '@/lib/grades';
import { writeCache } from '@/neptun/cache';
import { getCreditProgress, getSubjects, getTerms, type SubjectEntry } from '@/neptun/data';

type TermRow = { id: string; name: string; stats: TermStats };

// two terms at a time so neptun doesnt choke, also warms the subjects cache
async function getHistory(): Promise<TermRow[]> {
  const terms = await getTerms();
  const out: TermRow[] = [];
  for (let i = 0; i < terms.length; i += 2) {
    const slice = terms.slice(i, i + 2);
    const fetched = await Promise.all(slice.map((t) => getSubjects(t.id)));
    fetched.forEach((subjects: SubjectEntry[], j) => {
      const term = slice[j];
      void writeCache(`subjects.${term.id}`, subjects);
      out.push({ id: term.id, name: term.name, stats: termStats(subjects) });
    });
  }
  return out;
}

export default function StatisticsScreen() {
  const c = useTheme();
  const { tx } = useI18n();
  const history = useNeptunQuery('stats.history', getHistory);
  const progress = useNeptunQuery('creditprogress', getCreditProgress);

  const rows = (history.data ?? []).filter((r) => r.stats.taken > 0);
  let weightedSum = 0;
  let weightedCredits = 0;
  for (const r of rows) {
    weightedSum += r.stats.weighted * r.stats.gradedCredits;
    weightedCredits += r.stats.gradedCredits;
  }
  const cumulative = weightedCredits ? weightedSum / weightedCredits : 0;
  const earned = progress.data?.completed || rows.reduce((n, r) => n + r.stats.completed, 0);
  const required = progress.data?.required ?? 0;
  const current = rows[rows.length - 1];

  return (
    <>
      <ScreenTitle title={tx.stats.title} />
      <QueryScreen query={history} gap={Spacing.four}>
        <View style={{ flexDirection: 'row', gap: Spacing.two }}>
          {current ? (
            <Ring title={tx.stats.thisTerm} sub={current.name} value={current.stats.completed} max={current.stats.taken} color={c.brand} />
          ) : null}
          {required > 0 ? <Ring title={tx.stats.toDegree} value={earned} max={required} color={c.live} /> : null}
        </View>

        <View style={{ flexDirection: 'row', gap: Spacing.two }}>
          <Tile value={`${fmtAvg(cumulative)} ${cumulative ? avgEmoji(cumulative) : ''}`} label={tx.stats.cumulative} />
          <Tile value={String(earned)} label={tx.stats.credits} />
          <Tile value={String(rows.length)} label={tx.stats.semesters} />
        </View>

        {rows.length > 0 ? (
          <View style={{ gap: Spacing.two }}>
            <Text style={{ color: c.text, fontSize: 17, fontWeight: '700' }}>{tx.stats.terms}</Text>
            <Card style={{ paddingVertical: Spacing.one }}>
              {[...rows].reverse().map((r, i) => (
                <TermLine key={r.id} row={r} first={i === 0} />
              ))}
            </Card>
          </View>
        ) : null}
      </QueryScreen>
    </>
  );
}

function Ring({ title, sub, value, max, color }: { title: string; sub?: string; value: number; max: number; color: string }) {
  const c = useTheme();
  const { tx } = useI18n();
  return (
    <Card style={{ flex: 1, alignItems: 'center', gap: Spacing.three, paddingVertical: Spacing.three, paddingHorizontal: Spacing.two }}>
      <View style={{ alignItems: 'center', alignSelf: 'stretch' }}>
        <Text numberOfLines={1} adjustsFontSizeToFit style={{ color: c.text, fontSize: 15, fontWeight: '700', textAlign: 'center' }}>
          {title}
        </Text>
        <Text numberOfLines={1} style={{ color: c.textTertiary, fontSize: 12 }}>
          {sub ?? ' '}
        </Text>
      </View>
      <CreditGauge value={value} max={max} size={96} color={color} />
      <Text selectable style={{ color: c.textSecondary, fontSize: 13, textAlign: 'center', fontVariant: ['tabular-nums'] }}>
        {tx.stats.done(value, max)}
      </Text>
    </Card>
  );
}

function Tile({ value, label }: { value: string; label: string }) {
  const c = useTheme();
  return (
    <Card style={{ flex: 1, alignItems: 'center', gap: 4, paddingHorizontal: Spacing.two }}>
      <Text selectable style={{ color: c.brandText, fontSize: 20, fontWeight: '800', fontVariant: ['tabular-nums'] }}>
        {value}
      </Text>
      <Text style={{ color: c.textSecondary, fontSize: 12, textAlign: 'center' }}>{label}</Text>
    </Card>
  );
}

function TermLine({ row, first }: { row: TermRow; first: boolean }) {
  const c = useTheme();
  const { tx } = useI18n();
  const s = row.stats;
  const info = tx.v2.subjects.info;
  return (
    <View style={{ gap: Spacing.two, paddingVertical: Spacing.three, borderTopWidth: first ? 0 : 0.5, borderTopColor: c.separator }}>
      <View style={{ flexDirection: 'row', alignItems: 'baseline', gap: Spacing.two }}>
        <Text style={{ color: c.text, fontSize: 16, fontWeight: '700', flex: 1 }}>{row.name}</Text>
        <Text selectable style={{ color: c.textSecondary, fontSize: 13, fontVariant: ['tabular-nums'] }}>
          {tx.stats.done(s.completed, s.taken)}
        </Text>
      </View>
      <CreditBar value={s.completed} max={s.taken} color={s.completed >= s.taken ? c.live : c.brand} />
      <View style={{ flexDirection: 'row', gap: Spacing.three }}>
        <Metric label={info.weighted.title} value={s.weighted ? `${fmtAvg(s.weighted)} ${avgEmoji(s.weighted)}` : '-'} />
        <Metric label={info.creditIndex.title} value={s.creditIndex ? s.creditIndex.toFixed(2) : '-'} />
        <Metric label={info.correctedIndex.title} value={s.correctedIndex ? s.correctedIndex.toFixed(2) : '-'} />
      </View>
    </View>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  const c = useTheme();
  return (
    <View style={{ flex: 1, gap: 2 }}>
      <Text selectable style={{ color: c.text, fontSize: 15, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{value}</Text>
      <Text numberOfLines={2} style={{ color: c.textTertiary, fontSize: 11 }}>{label}</Text>
    </View>
  );
}
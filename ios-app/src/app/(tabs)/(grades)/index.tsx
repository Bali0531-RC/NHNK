import { ScrollView, Text, View } from 'react-native';

import { Card, Chip, StatTile } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { grades, totalCredits, weightedAverage } from '@/demo/data';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

export default function GradesScreen() {
  const c = useTheme();
  const { t, lang } = useI18n();

  const avg = weightedAverage(grades);
  const credits = totalCredits(grades);

  function gradeColor(g: number): string {
    if (g >= 5) return c.success;
    if (g === 4) return c.brand;
    if (g === 3) return c.warning;
    return c.danger;
  }

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.four, paddingBottom: Spacing.six }}>
      <View style={{ flexDirection: 'row', gap: Spacing.two }}>
        <StatTile value={avg.toFixed(2)} label={t.common.average} accent={c.brand} />
        <StatTile value={`${credits}`} label={t.common.credits} />
      </View>

      <Card style={{ gap: Spacing.three }}>
        {grades.map((g, i) => (
          <View key={g.id} style={{ gap: Spacing.three }}>
            {i > 0 && <View style={{ height: 1, backgroundColor: c.separator }} />}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
              <View style={{ flex: 1, gap: 2 }}>
                <Text style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>
                  {lang === 'hu' ? g.subjectHu : g.subjectEn}
                </Text>
                <Text style={{ color: c.textSecondary, fontSize: 13 }}>
                  {g.code} · {g.credits} {t.common.credits}
                </Text>
              </View>
              <Chip label={String(g.grade)} color={gradeColor(g.grade)} textColor="#FFFFFF" />
            </View>
          </View>
        ))}
      </Card>
    </ScrollView>
  );
}

import { useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';

import { Card } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { pickTitle, timetable, type ClassType } from '@/demo/data';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';

function todayIndex(): number {
  const d = (new Date().getDay() + 6) % 7;
  return d > 4 ? 0 : d;
}

export default function TimetableScreen() {
  const c = useTheme();
  const { t, lang } = useI18n();
  const [day, setDay] = useState(todayIndex());

  const typeColor: Record<ClassType, string> = {
    lecture: c.brand,
    practice: c.success,
    exam: c.danger,
  };

  const classes = timetable
    .filter((cl) => cl.day === day)
    .sort((a, b) => a.start.localeCompare(b.start));

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.three, paddingBottom: Spacing.six }}>
      <View style={{ flexDirection: 'row', gap: Spacing.one + 2 }}>
        {t.timetable.daysShort.map((label, i) => {
          const active = i === day;
          return (
            <Pressable
              key={label}
              onPress={() => setDay(i)}
              style={{
                flex: 1,
                paddingVertical: Spacing.two,
                borderRadius: Radius.md,
                alignItems: 'center',
                backgroundColor: active ? c.brand : c.card,
                borderCurve: 'continuous',
              }}>
              <Text style={{ color: active ? c.brandOn : c.textSecondary, fontWeight: '700' }}>{label}</Text>
            </Pressable>
          );
        })}
      </View>

      {classes.length === 0 ? (
        <Card style={{ alignItems: 'center', paddingVertical: Spacing.five }}>
          <Text style={{ color: c.textSecondary }}>{t.timetable.empty}</Text>
        </Card>
      ) : (
        classes.map((cl) => (
          <Card key={cl.id} style={{ flexDirection: 'row', gap: Spacing.three, padding: 0, overflow: 'hidden' }}>
            <View style={{ width: 5, backgroundColor: typeColor[cl.type] }} />
            <View style={{ flex: 1, paddingVertical: Spacing.three, paddingRight: Spacing.three, gap: 2 }}>
              <Text style={{ color: c.text, fontSize: 16, fontWeight: '700' }}>{pickTitle(cl, lang)}</Text>
              <Text style={{ color: c.textSecondary, fontSize: 13 }}>
                {cl.code} · {cl.teacher}
              </Text>
            </View>
            <View style={{ paddingVertical: Spacing.three, paddingRight: Spacing.three, alignItems: 'flex-end', gap: 2 }}>
              <Text style={{ color: c.text, fontWeight: '600', fontVariant: ['tabular-nums'] }}>{cl.start}</Text>
              <Text style={{ color: c.textTertiary, fontSize: 13, fontVariant: ['tabular-nums'] }}>{cl.end}</Text>
              <Text style={{ color: c.textTertiary, fontSize: 12 }}>{cl.room}</Text>
            </View>
          </Card>
        ))
      )}
    </ScrollView>
  );
}

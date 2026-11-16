import { SymbolView } from 'expo-symbols';
import { useEffect, useState, type ComponentProps } from 'react';
import { ScrollView, Text, View } from 'react-native';

import { Card, SectionLabel, Skeleton, StatTile } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import {
  creditProgress as demoCredits,
  exams,
  grades,
  nextClass,
  pickTitle,
  student,
  weightedAverage,
} from '@/demo/data';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { getCreditProgress, type CreditProgress } from '@/neptun/data';
import { Store } from '@/neptun/storage';
import { useAuth } from '@/providers/auth';

type CreditsState = CreditProgress | 'loading' | 'unavailable';

export default function DashboardScreen() {
  const c = useTheme();
  const { t, lang } = useI18n();
  const { isDemo } = useAuth();

  const [username, setUsername] = useState<string | null>(null);
  const [credits, setCredits] = useState<CreditsState>(isDemo ? demoCredits : 'loading');

  useEffect(() => {
    if (isDemo) {
      setCredits(demoCredits);
      return;
    }
    let active = true;
    setCredits('loading');
    Store.getUsername().then((u) => {
      if (active) setUsername(u);
    });
    getCreditProgress().then((cp) => {
      if (active) setCredits(cp ?? 'unavailable');
    });
    return () => {
      active = false;
    };
  }, [isDemo]);

  const name = isDemo ? (lang === 'hu' ? student.nameHu : student.nameEn) : (username ?? '');
  const subtitle = isDemo ? (lang === 'hu' ? student.institutionHu : student.institutionEn) : t.login.tagline;

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.four, paddingBottom: Spacing.six }}>
      <View style={{ gap: 2, marginTop: Spacing.one }}>
        <Text style={{ color: c.text, fontSize: 20, fontWeight: '700' }}>
          {t.dashboard.greeting}
          {name ? `, ${name}` : ''}
        </Text>
        <Text style={{ color: c.textSecondary, fontSize: 15 }}>{subtitle}</Text>
      </View>

      <StatRow isDemo={isDemo} credits={credits} />

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.dashboard.creditProgress}</SectionLabel>
        <CreditProgressCard credits={credits} />
      </View>

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.dashboard.nextClass}</SectionLabel>
        {isDemo ? <DemoNextClass /> : <ComingSoonCard icon="calendar" />}
      </View>

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.dashboard.upcomingExams}</SectionLabel>
        {isDemo ? <DemoExams /> : <ComingSoonCard icon="graduationcap" />}
      </View>
    </ScrollView>
  );
}

function StatRow({ isDemo, credits }: { isDemo: boolean; credits: CreditsState }) {
  const { t } = useI18n();
  const avg = isDemo ? weightedAverage(grades).toFixed(2) : '—';
  const completed =
    typeof credits === 'object' ? String(credits.completed) : credits === 'loading' ? null : '—';
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', gap: Spacing.two }}>
      <StatTile value={avg} label={t.dashboard.weightedAverage} accent={c.brand} />
      {completed === null ? (
        <Card style={{ flex: 1, gap: Spacing.one, justifyContent: 'center' }}>
          <Skeleton width={56} height={30} />
          <Text style={{ color: c.textSecondary, fontSize: 13 }}>{t.dashboard.completedCredits}</Text>
        </Card>
      ) : (
        <StatTile value={completed} label={t.dashboard.completedCredits} />
      )}
    </View>
  );
}

function CreditProgressCard({ credits }: { credits: CreditsState }) {
  const c = useTheme();
  const { t } = useI18n();

  if (credits === 'loading') {
    return (
      <Card style={{ gap: Spacing.three }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          <Skeleton width={120} height={16} />
          <Skeleton width={44} height={16} />
        </View>
        <Skeleton width="100%" height={10} />
      </Card>
    );
  }

  if (credits === 'unavailable') {
    return (
      <Card>
        <Text style={{ color: c.textSecondary, fontSize: 14 }}>{t.dashboard.dataUnavailable}</Text>
      </Card>
    );
  }

  const pct = credits.required > 0 ? Math.round((credits.completed / credits.required) * 100) : 0;
  return (
    <Card style={{ gap: Spacing.two }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <Text style={{ color: c.text, fontWeight: '600' }}>
          {credits.completed} / {credits.required} {t.common.credits}
        </Text>
        <Text style={{ color: c.brand, fontWeight: '700', fontVariant: ['tabular-nums'] }}>{pct}%</Text>
      </View>
      <View style={{ height: 10, borderRadius: Radius.sm, backgroundColor: c.backgroundSelected, overflow: 'hidden' }}>
        <View style={{ width: `${pct}%`, height: '100%', backgroundColor: c.brand, borderRadius: Radius.sm }} />
      </View>
    </Card>
  );
}

function ComingSoonCard({ icon }: { icon: ComponentProps<typeof SymbolView>['name'] }) {
  const c = useTheme();
  const { t } = useI18n();
  return (
    <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
      <SymbolView name={icon} tintColor={c.textTertiary} size={20} />
      <Text style={{ color: c.textSecondary, fontSize: 14 }}>{t.common.soon}</Text>
    </Card>
  );
}

function DemoNextClass() {
  const c = useTheme();
  const { t, lang } = useI18n();
  const next = nextClass();
  return (
    <Card style={{ gap: Spacing.two }}>
      {next ? (
        <>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
            <SymbolView name="clock.fill" tintColor={c.brand} size={18} />
            <Text style={{ color: c.text, fontSize: 18, fontWeight: '700', flex: 1 }}>{pickTitle(next, lang)}</Text>
          </View>
          <View style={{ flexDirection: 'row', gap: Spacing.four }}>
            <InfoBit icon="clock" text={`${next.start} - ${next.end}`} />
            <InfoBit icon="mappin.and.ellipse" text={next.room} />
          </View>
          <InfoBit icon="person" text={next.teacher} />
        </>
      ) : (
        <Text style={{ color: c.textSecondary }}>{t.dashboard.noNextClass}</Text>
      )}
    </Card>
  );
}

function DemoExams() {
  const c = useTheme();
  const { lang } = useI18n();
  const dateFmt = new Intl.DateTimeFormat(lang === 'hu' ? 'hu-HU' : 'en-GB', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
  return (
    <Card style={{ gap: Spacing.three }}>
      {exams.slice(0, 3).map((e, i) => (
        <View key={e.id} style={{ gap: Spacing.three }}>
          {i > 0 && <View style={{ height: 1, backgroundColor: c.separator }} />}
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
            <SymbolView name="graduationcap.fill" tintColor={c.danger} size={18} />
            <View style={{ flex: 1 }}>
              <Text style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>
                {lang === 'hu' ? e.subjectHu : e.subjectEn}
              </Text>
              <Text style={{ color: c.textSecondary, fontSize: 13 }}>{e.room}</Text>
            </View>
            <Text style={{ color: c.textSecondary, fontSize: 13, fontVariant: ['tabular-nums'] }}>
              {dateFmt.format(new Date(e.date))}
            </Text>
          </View>
        </View>
      ))}
    </Card>
  );
}

function InfoBit({ icon, text }: { icon: ComponentProps<typeof SymbolView>['name']; text: string }) {
  const c = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.one + 2 }}>
      <SymbolView name={icon} tintColor={c.textSecondary} size={14} />
      <Text style={{ color: c.textSecondary, fontSize: 14 }}>{text}</Text>
    </View>
  );
}

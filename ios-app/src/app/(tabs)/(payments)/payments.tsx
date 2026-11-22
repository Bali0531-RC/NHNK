import { router } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, Text, View } from 'react-native';
import Animated, { FadeInDown } from 'react-native-reanimated';

import { DividerLabel, EmptyCard, QueryScreen, ScreenTitle } from '@/components/screen';
import { Card } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTerm } from '@/hooks/use-term';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { daysFromToday, fmtDate, fmtMoney } from '@/lib/format';
import { getCollectiveAccount, getPayments, paymentsInTerm, type PaymentEntry } from '@/neptun/data';

export default function PaymentsScreen() {
  const c = useTheme();
  const { t, tx, lang } = useI18n();
  const query = useNeptunQuery('payments', getPayments);
  const { termName, isLatest } = useTerm();
  const list = termName ? paymentsInTerm(query.data ?? [], termName, isLatest) : (query.data ?? []);

  const cancelled = (p: PaymentEntry) => /^(törölt|deleted|cancell?ed|gelöscht|storniert)$/i.test(p.status.trim());
  const pending = list.filter((p) => p.amount > 0 && !p.done).sort((a, b) => a.dateMs - b.dateMs);
  const payouts = list.filter((p) => p.amount < 0);
  const history = list.filter((p) => p.amount > 0 && p.done);
  const spent = history.filter((p) => !cancelled(p)).reduce((n, p) => n + p.amount, 0);
  const received = payouts.filter((p) => !cancelled(p)).reduce((n, p) => n + Math.abs(p.amount), 0);
  const account = useNeptunQuery('collective', getCollectiveAccount);
  const acc = account.data;

  return (
    <>
      <ScreenTitle
        title={t.tabs.payments}
        subtitle={query.data ? [termName, tx.payments.spent(fmtMoney(spent, lang))].filter(Boolean).join(' · ') : null}
      />
      <QueryScreen query={query} extraRefresh={account.refresh}>
        {acc ? (
          <Card style={{ gap: Spacing.two }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
              <SymbolView name="building.columns.fill" tintColor={c.brand} size={18} />
              <Text style={{ color: c.textSecondary, fontSize: 14, fontWeight: '600', flex: 1 }}>{tx.v2.payments.collective}</Text>
              <Pressable
                onPress={() => router.push('/top-up')}
                style={({ pressed }) => ({
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: 4,
                  backgroundColor: c.brand,
                  borderRadius: Radius.pill,
                  paddingHorizontal: 12,
                  paddingVertical: 6,
                  opacity: pressed ? 0.75 : 1,
                })}>
                <SymbolView name="arrow.right.arrow.left" tintColor={c.brandOn} size={12} weight="bold" />
                <Text style={{ color: c.brandOn, fontSize: 14, fontWeight: '700' }}>{tx.v2.payments.topUp}</Text>
              </Pressable>
            </View>
            <Text selectable style={{ color: c.text, fontSize: 30, fontWeight: '800', fontVariant: ['tabular-nums'] }}>
              {fmtMoney(acc.balance, lang)}
            </Text>
          </Card>
        ) : null}

        {received > 0 ? (
          <Card style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <Text style={{ color: c.textSecondary, fontSize: 14 }}>{tx.payments.received}</Text>
            <ReceivedValue value={fmtMoney(received, lang)} />
          </Card>
        ) : null}

        {list.length === 0 ? <EmptyCard text={tx.payments.empty} icon="banknote" /> : null}

        {pending.length > 0 ? (
          <View style={{ gap: Spacing.two }}>
            <DividerLabel label={tx.payments.toPay} />
            {pending.map((p, i) => (
              <PaymentCard key={p.id} p={p} index={i} />
            ))}
          </View>
        ) : null}

        {payouts.length > 0 ? (
          <View style={{ gap: Spacing.two }}>
            <DividerLabel label={tx.payments.payouts} />
            {payouts.map((p, i) => (
              <PaymentCard key={p.id} p={p} index={i} />
            ))}
          </View>
        ) : null}

        {history.length > 0 ? (
          <View style={{ gap: Spacing.two }}>
            <DividerLabel label={tx.payments.history} />
            {history.map((p, i) => (
              <PaymentCard key={p.id} p={p} index={i} />
            ))}
          </View>
        ) : null}
      </QueryScreen>
    </>
  );
}

function ReceivedValue({ value }: { value: string }) {
  const c = useTheme();
  return (
    <Text selectable style={{ color: c.live, fontSize: 17, fontWeight: '800', fontVariant: ['tabular-nums'] }}>
      +{value}
    </Text>
  );
}

function PaymentCard({ p, index }: { p: PaymentEntry; index: number }) {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const payout = p.amount < 0;
  const active = !payout && !p.done;
  const days = daysFromToday(p.dateMs);
  const accent = payout ? c.live : active ? (days < 0 ? c.danger : c.warning) : c.textSecondary;
  const year = new Date(p.dateMs).getFullYear();

  return (
    <Animated.View entering={FadeInDown.duration(250).delay(Math.min(index, 8) * 35)}>
    <Card
      style={{
        gap: Spacing.two,
        backgroundColor: payout ? c.liveSubtle : active ? (days < 0 ? c.dangerSubtle : c.warningSubtle) : c.card,
      }}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
        <Text selectable style={{ color: c.text, fontSize: 16, fontWeight: '700', flex: 1 }}>
          {p.title}
        </Text>
        {p.status ? (
          <View style={{ backgroundColor: c.fill, borderRadius: Radius.pill, paddingHorizontal: 10, paddingVertical: 3 }}>
            <Text style={{ color: accent, fontSize: 12, fontWeight: '700' }}>{p.status.toLowerCase()}</Text>
          </View>
        ) : null}
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <Text selectable style={{ color: accent, fontSize: 22, fontWeight: '800', fontVariant: ['tabular-nums'] }}>
          {payout ? '+' : ''}
          {fmtMoney(Math.abs(p.amount), lang)}
        </Text>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={{ color: c.textTertiary, fontSize: 12 }}>{year}</Text>
          <Text style={{ color: c.text, fontSize: 15, fontWeight: '700' }}>{fmtDate(p.dateMs, lang)}</Text>
        </View>
      </View>
      {active ? (
        <Text style={{ color: accent, fontSize: 13, fontWeight: '600', textAlign: 'center' }}>
          {days < 0 ? tx.common.overdue(-days) : days === 0 ? tx.common.dueToday : tx.common.daysLeft(days)}
        </Text>
      ) : null}
    </Card>
    </Animated.View>
  );
}
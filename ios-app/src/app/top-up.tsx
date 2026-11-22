import { SymbolView } from 'expo-symbols';
import { useEffect, useState } from 'react';
import { ScrollView, Text, View } from 'react-native';

import { CopyRow } from '@/components/copy-row';
import { Card } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtMoney } from '@/lib/format';
import { getCollectiveAccount } from '@/neptun/data';
import { Store } from '@/neptun/storage';

// account number + neptun code as reference, one tap copy each
export default function TopUp() {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const account = useNeptunQuery('collective', getCollectiveAccount);
  const [code, setCode] = useState('');
  useEffect(() => {
    let active = true;
    void Store.getUsername().then((u) => {
      if (active) setCode((u ?? '').toUpperCase());
    });
    return () => {
      active = false;
    };
  }, []);
  const acc = account.data;

  return (
    <ScrollView contentContainerStyle={{ padding: Spacing.four, paddingTop: Spacing.five, gap: Spacing.three }}>
      <View style={{ alignItems: 'center', gap: Spacing.two }}>
        <View
          style={{
            width: 56,
            height: 56,
            borderRadius: 28,
            backgroundColor: c.brandSubtle,
            alignItems: 'center',
            justifyContent: 'center',
          }}>
          <SymbolView name="building.columns.fill" tintColor={c.brand} size={26} />
        </View>
        <Text style={{ color: c.text, fontSize: 22, fontWeight: '800', textAlign: 'center' }}>{tx.v2.payments.topUpTitle}</Text>
        {acc ? (
          <Text style={{ color: c.textSecondary, fontSize: 15, fontVariant: ['tabular-nums'] }}>
            {tx.v2.payments.balance}: {fmtMoney(acc.balance, lang)}
          </Text>
        ) : null}
      </View>
      <Text style={{ color: c.textSecondary, fontSize: 14, lineHeight: 20, textAlign: 'center' }}>{tx.v2.payments.topUpHint}</Text>
      {acc?.bankAccount ? (
        <CopyRow label={tx.v2.payments.beneficiary} value={acc.bankAccount} />
      ) : (
        <Card>
          <Text style={{ color: c.textSecondary, fontSize: 14, textAlign: 'center' }}>{tx.v2.payments.noAccount}</Text>
        </Card>
      )}
      {code ? <CopyRow label={tx.v2.payments.reference} value={code} /> : null}
    </ScrollView>
  );
}
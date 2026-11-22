import { Image } from 'expo-image';
import { Text, View } from 'react-native';

import { CopyRow } from '@/components/copy-row';
import { DetailList, DividerLabel, QueryScreen, ScreenTitle } from '@/components/screen';
import { Card, Skeleton } from '@/components/ui';
import { Spacing } from '@/constants/theme';
import { useNeptunQuery } from '@/hooks/use-neptun-query';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { getCollectiveAccount, getProfile } from '@/neptun/data';
import { fmtMoney } from '@/lib/format';

// Adatlap: the photo, every general field Neptun returns, personal documents and bank data.
export default function ProfileScreen() {
  const c = useTheme();
  const { tx, lang } = useI18n();
  const profile = useNeptunQuery('profile', getProfile);
  const account = useNeptunQuery('collective', getCollectiveAccount);
  const p = profile.data;

  return (
    <>
      <ScreenTitle title={tx.v2.profile.title} />
      <QueryScreen
        query={profile}
        extraRefresh={account.refresh}
        skeleton={
          <View style={{ alignItems: 'center', gap: Spacing.two }}>
            <Skeleton width={96} height={96} radius={48} />
            <Skeleton width="50%" height={20} />
            <Skeleton width="30%" height={14} />
          </View>
        }>
        {p ? (
          <>
            <View style={{ alignItems: 'center', gap: Spacing.one, paddingVertical: Spacing.two }}>
              {p.avatar ? (
                <Image
                  source={{ uri: `data:image/jpeg;base64,${p.avatar}` }}
                  style={{ width: 96, height: 96, borderRadius: 48 }}
                  contentFit="cover"
                  transition={200}
                />
              ) : (
                <View
                  style={{
                    width: 96,
                    height: 96,
                    borderRadius: 48,
                    backgroundColor: c.brand,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}>
                  <Text style={{ color: c.brandOn, fontSize: 38, fontWeight: '700' }}>{(p.name || '?').slice(0, 1).toUpperCase()}</Text>
                </View>
              )}
              <Text selectable style={{ color: c.text, fontSize: 24, fontWeight: '800', marginTop: Spacing.two, textAlign: 'center' }}>
                {p.name}
              </Text>
              <Text selectable style={{ color: c.textSecondary, fontSize: 15, fontWeight: '600', letterSpacing: 1 }}>
                {p.code.toUpperCase()}
              </Text>
            </View>

            {account.data ? (
              <Card style={{ flexDirection: 'row', alignItems: 'center' }}>
                <Text style={{ color: c.textSecondary, fontSize: 15, flex: 1 }}>{tx.v2.menu.balance}</Text>
                <Text selectable style={{ color: c.text, fontSize: 17, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
                  {fmtMoney(account.data.balance, lang)}
                </Text>
              </Card>
            ) : null}

            {p.rows.length ? (
              <>
                <DividerLabel label={tx.v2.profile.personal} />
                <DetailList rows={p.rows} />
              </>
            ) : null}

            {p.bankAccount ? (
              <>
                <DividerLabel label={tx.v2.profile.bank} />
                <CopyRow label={tx.v2.payments.bankAccount} value={p.bankAccount} />
              </>
            ) : null}

            {p.documents.length ? <DividerLabel label={tx.v2.profile.documents} /> : null}
            {p.documents.map((rows, i) => (
              <View key={i} style={{ gap: Spacing.one }}>
                <Text style={{ color: c.textSecondary, fontSize: 13, fontWeight: '600', marginLeft: Spacing.three }}>
                  {tx.v2.profile.document(i + 1)}
                </Text>
                <DetailList rows={rows} />
              </View>
            ))}
          </>
        ) : null}
      </QueryScreen>
    </>
  );
}
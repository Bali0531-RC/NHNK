import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import { useEffect, useRef, useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { useAppLock } from '@/providers/app-lock';
import { useAuth } from '@/providers/auth';

const logo = require('../../assets/images/nhnk-logo.png');

// biometric lock overlay. sign out stays reachable so a dead sensor cant trap anyone
export function LockScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const { unlock, unlocking } = useAppLock();
  const { signOut } = useAuth();
  const [failed, setFailed] = useState(false);
  const prompted = useRef(false);

  const attempt = async () => {
    setFailed(false);
    const ok = await unlock();
    if (!ok) setFailed(true);
  };

  useEffect(() => {
    if (prompted.current) return;
    prompted.current = true;
    void attempt();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <View
      style={{
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: c.background,
        padding: Spacing.four,
        gap: Spacing.four,
      }}>
      <Image source={logo} style={{ width: 88, height: 88, borderRadius: Radius.xl }} contentFit="contain" />

      <View style={{ alignItems: 'center', gap: Spacing.two }}>
        <SymbolView name="faceid" tintColor={c.brand} size={40} />
        <Text style={{ color: c.text, fontSize: 18, fontWeight: '700' }}>{t.lock.title}</Text>
        {failed ? (
          <Text selectable style={{ color: c.textSecondary, fontSize: 14, textAlign: 'center' }}>
            {t.lock.failed}
          </Text>
        ) : null}
      </View>

      <Pressable
        onPress={attempt}
        disabled={unlocking}
        style={({ pressed }) => ({
          backgroundColor: c.brand,
          borderRadius: Radius.md,
          paddingVertical: Spacing.three,
          paddingHorizontal: Spacing.five,
          alignItems: 'center',
          opacity: unlocking || pressed ? 0.6 : 1,
          borderCurve: 'continuous',
          minWidth: 220,
        })}>
        <Text style={{ color: c.brandOn, fontSize: 16, fontWeight: '700' }}>{t.lock.unlock}</Text>
      </Pressable>

      <Pressable onPress={signOut} style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}>
        <Text style={{ color: c.danger, fontSize: 15, fontWeight: '600' }}>{t.common.signOut}</Text>
      </Pressable>
    </View>
  );
}
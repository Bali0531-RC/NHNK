import Constants from 'expo-constants';
import { SymbolView } from 'expo-symbols';
import { useEffect, useState } from 'react';
import { Alert, Linking, Pressable, ScrollView, Switch, Text, View } from 'react-native';

import { Card, Segmented, SectionLabel } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import type { Lang } from '@/i18n/strings';
import { Store } from '@/neptun/storage';
import { extractTotpSecret } from '@/neptun/totp';
import { useAuth } from '@/providers/auth';
import { usePreferences, type ThemeMode } from '@/providers/preferences';

// Marcell's App Store publisher page. Apple only mints the developer id once the app is
// live, so until then this stays empty and the name renders as plain text, not a dead link.
const PUBLISHER_URL = '';

type Credit = { name: string; role: string; url?: string };

export default function SettingsScreen() {
  const c = useTheme();
  const { t, lang, setLang } = useI18n();
  const { signOut, isDemo } = useAuth();
  const { themeMode, setThemeMode, haptics, setHaptics } = usePreferences();
  const { notify, selection } = useHaptics();
  const version = Constants.expoConfig?.version ?? '1.0.0';

  const credits: Credit[] = [
    { name: 'Marcell Béres', role: t.settings.creditsIos, url: PUBLISHER_URL || undefined },
    { name: 'Turi Balázs (Bali0531)', role: t.settings.creditsNhnk, url: 'https://github.com/Bali0531-RC' },
    { name: 'Kurucz Zoltán (zoligamer)', role: t.settings.creditsNeptunMobile, url: 'https://github.com/zoligamer' },
    { name: 'Dömötör Dávid (domedav)', role: t.settings.creditsNeptun2, url: 'https://github.com/domedav' },
  ];

  const openUrl = (url: string) => {
    selection();
    void Linking.openURL(url).catch(() => {});
  };

  const [totpSaved, setTotpSaved] = useState(false);
  useEffect(() => {
    let active = true;
    Store.getTotpSecret().then((s) => {
      if (active) setTotpSaved(!!s);
    });
    return () => {
      active = false;
    };
  }, []);

  const manageTotp = () => {
    if (totpSaved) {
      Alert.alert(t.settings.twoFactorKey, t.settings.twoFactorClearConfirm, [
        { text: t.common.cancel, style: 'cancel' },
        {
          text: t.settings.clear,
          style: 'destructive',
          onPress: async () => {
            await Store.setTotpSecret(null);
            setTotpSaved(false);
          },
        },
      ]);
      return;
    }
    Alert.prompt(
      t.settings.twoFactorKey,
      t.settings.twoFactorPrompt,
      [
        { text: t.common.cancel, style: 'cancel' },
        {
          text: t.common.save,
          onPress: async (value?: string) => {
            const secret = value ? extractTotpSecret(value) : null;
            if (!secret) {
              Alert.alert(t.settings.twoFactorKey, t.settings.twoFactorInvalid);
              return;
            }
            await Store.setTotpSecret(secret);
            setTotpSaved(true);
            notify();
          },
        },
      ],
      'plain-text',
    );
  };

  const themeOptions: { value: ThemeMode; label: string }[] = [
    { value: 'system', label: t.settings.themeSystem },
    { value: 'light', label: t.settings.themeLight },
    { value: 'dark', label: t.settings.themeDark },
  ];
  const langOptions: { value: Lang; label: string }[] = [
    { value: 'hu', label: 'Magyar' },
    { value: 'en', label: 'English' },
  ];

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.four, paddingBottom: Spacing.six }}>
      {isDemo ? (
        <Card
          style={{
            flexDirection: 'row',
            alignItems: 'center',
            gap: Spacing.two,
            backgroundColor: c.brandSubtle,
          }}>
          <SymbolView name="info.circle.fill" tintColor={c.brand} size={18} />
          <Text style={{ color: c.text, fontSize: 14, flex: 1 }}>{t.settings.demoBanner}</Text>
        </Card>
      ) : null}

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.settings.appearance}</SectionLabel>
        <Segmented options={themeOptions} value={themeMode} onChange={setThemeMode} />
        <Text style={{ color: c.textTertiary, fontSize: 13, marginLeft: Spacing.one }}>
          {t.settings.appearanceNote}
        </Text>
      </View>

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.settings.language}</SectionLabel>
        <Segmented options={langOptions} value={lang} onChange={setLang} />
      </View>

      <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
        <SymbolView name="hand.tap.fill" tintColor={c.brand} size={20} />
        <View style={{ flex: 1 }}>
          <Text style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>{t.settings.haptics}</Text>
          <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18 }}>{t.settings.hapticsNote}</Text>
        </View>
        <Switch value={haptics} onValueChange={setHaptics} />
      </Card>

      {!isDemo ? (
        <View style={{ gap: Spacing.two }}>
          <SectionLabel>{t.settings.security}</SectionLabel>
          <Pressable onPress={manageTotp} style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}>
            <Card style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three }}>
              <SymbolView
                name={totpSaved ? 'key.fill' : 'key'}
                tintColor={totpSaved ? c.success : c.textSecondary}
                size={20}
              />
              <View style={{ flex: 1 }}>
                <Text style={{ color: c.text, fontSize: 16, fontWeight: '600' }}>{t.settings.twoFactorKey}</Text>
                <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 18 }}>
                  {totpSaved ? t.settings.twoFactorSaved : t.settings.twoFactorNotSaved}
                </Text>
              </View>
              <SymbolView name="chevron.right" tintColor={c.textTertiary} size={14} />
            </Card>
          </Pressable>
        </View>
      ) : null}

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.settings.about}</SectionLabel>
        <Card style={{ gap: Spacing.three }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            <Text style={{ color: c.text, fontSize: 15 }}>{t.settings.version}</Text>
            <Text selectable style={{ color: c.textSecondary, fontVariant: ['tabular-nums'] }}>
              {version}
            </Text>
          </View>
          <View style={{ height: 1, backgroundColor: c.separator }} />
          <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 19 }}>{t.settings.unofficial}</Text>
        </Card>
      </View>

      <View style={{ gap: Spacing.two }}>
        <SectionLabel>{t.settings.credits}</SectionLabel>
        <Card style={{ gap: 0 }}>
          {credits.map((p, i) => {
            const body = (
              <View
                style={{
                  flexDirection: 'row',
                  alignItems: 'center',
                  gap: Spacing.three,
                  paddingVertical: Spacing.two + 2,
                }}>
                <View style={{ flex: 1 }}>
                  <Text style={{ color: c.text, fontSize: 15, fontWeight: '600' }}>{p.name}</Text>
                  <Text style={{ color: c.textSecondary, fontSize: 13 }}>{p.role}</Text>
                </View>
                {p.url ? <SymbolView name="arrow.up.right" tintColor={c.textTertiary} size={13} /> : null}
              </View>
            );
            return (
              <View key={p.name}>
                {i > 0 ? <View style={{ height: 1, backgroundColor: c.separator }} /> : null}
                {p.url ? (
                  <Pressable onPress={() => openUrl(p.url!)} style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}>
                    {body}
                  </Pressable>
                ) : (
                  body
                )}
              </View>
            );
          })}
          <View style={{ height: 1, backgroundColor: c.separator }} />
          <Text style={{ color: c.textTertiary, fontSize: 12, lineHeight: 18, paddingTop: Spacing.two + 2 }}>
            {t.settings.creditsLicence}
          </Text>
        </Card>
      </View>

      <Pressable
        onPress={signOut}
        style={({ pressed }) => ({
          backgroundColor: c.card,
          borderRadius: Radius.md,
          paddingVertical: Spacing.three,
          alignItems: 'center',
          opacity: pressed ? 0.6 : 1,
          borderCurve: 'continuous',
        })}>
        <Text style={{ color: c.danger, fontSize: 16, fontWeight: '600' }}>{t.common.signOut}</Text>
      </Pressable>
    </ScrollView>
  );
}

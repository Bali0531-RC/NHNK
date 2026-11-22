import Constants from 'expo-constants';
import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import * as Updates from 'expo-updates';
import { type ComponentProps, type ReactNode, useState } from 'react';
import { ActivityIndicator, Alert, Linking, Pressable, ScrollView, Text, View } from 'react-native';

import { ScreenTitle } from '@/components/screen';
import { Card, SectionLabel } from '@/components/ui';
import { Radius, Spacing } from '@/constants/theme';
import { useHaptics } from '@/hooks/use-haptics';
import { applyUpdate, otaEnabled, pullUpdate } from '@/hooks/use-ota';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { fmtDate, hhmm } from '@/lib/format';

const logo = require('../../assets/images/nhnk-logo.png');

const PUBLISHER_URL = 'https://apps.apple.com/developer/id1822126360';

type Row = { icon: ComponentProps<typeof SymbolView>['name']; label: string; sub?: string; url: string };

export default function AboutScreen() {
  const c = useTheme();
  const { t, tx, lang } = useI18n();
  const { selection } = useHaptics();
  const version = Constants.expoConfig?.version ?? '1.0.0';
  // tells you straight away if an eas update actually landed or you are still on the bundle from the build
  const ota = !Updates.isEmbeddedLaunch && Updates.createdAt ? Updates.createdAt.getTime() : null;
  const bundle = ota ? tx.about.updated(`${fmtDate(ota, lang)} ${hhmm(ota)}`) : tx.about.embedded;

  const [checking, setChecking] = useState(false);
  const a = tx.about;

  const checkNow = async () => {
    selection();
    setChecking(true);
    try {
      const id = await pullUpdate();
      if (!id) Alert.alert(a.upToDate, a.upToDateBody);
      else
        Alert.alert(a.updateReady, a.updateReadyBody, [
          { text: a.later, style: 'cancel' },
          { text: a.restart, onPress: () => void applyUpdate(id).catch(() => {}) },
        ]);
    } catch {
      Alert.alert(a.updateFailed, a.updateFailedBody);
    } finally {
      setChecking(false);
    }
  };

  const openUrl = (url: string) => {
    selection();
    void Linking.openURL(url).catch(() => {});
  };

  const credits: Row[] = [
    { icon: 'person', label: 'Turi Balázs (Bali0531)', sub: t.settings.creditsNhnk, url: 'https://github.com/Bali0531-RC' },
    { icon: 'person', label: 'Kurucz Zoltán (zoligamer)', sub: t.settings.creditsNeptunMobile, url: 'https://github.com/zoligamer' },
    { icon: 'person', label: 'Dömötör Dávid (domedav)', sub: t.settings.creditsNeptun2, url: 'https://github.com/domedav' },
  ];
  const links: Row[] = [
    { icon: 'globe', label: tx.about.website, url: 'https://nhnk.hu' },
    { icon: 'hand.raised', label: tx.about.privacy, url: 'https://nhnk.hu/adatvedelem' },
    { icon: 'doc.text', label: tx.about.terms, url: 'https://nhnk.hu/felhasznalasi-feltetelek' },
    { icon: 'chevron.left.forwardslash.chevron.right', label: tx.about.source, url: 'https://github.com/Bali0531-RC/NHNK' },
  ];

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{ padding: Spacing.three, gap: Spacing.four, paddingBottom: Spacing.six }}>
      <ScreenTitle title={t.menu.about} />

      <View style={{ alignItems: 'center', gap: Spacing.one }}>
        <Image source={logo} style={{ width: 84, height: 84, borderRadius: Radius.lg }} contentFit="contain" />
        <Text style={{ color: c.text, fontSize: 26, fontWeight: '800', marginTop: Spacing.two }}>NHNK</Text>
        <Text style={{ color: c.textSecondary, fontSize: 14 }}>{t.login.tagline}</Text>
        <View style={{ backgroundColor: c.fill, borderRadius: Radius.pill, paddingHorizontal: 12, paddingVertical: 4, marginTop: 4 }}>
          <Text selectable style={{ color: c.textSecondary, fontSize: 12, fontVariant: ['tabular-nums'] }}>
            {`v${version} · ${bundle}`}
          </Text>
        </View>
        {otaEnabled ? (
          <Pressable
            disabled={checking}
            onPress={() => void checkNow()}
            style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1, flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: Spacing.one })}>
            {checking ? (
              <ActivityIndicator size="small" color={c.brandText} />
            ) : (
              <SymbolView name="arrow.triangle.2.circlepath" tintColor={c.brandText} size={14} />
            )}
            <Text style={{ color: c.brandText, fontSize: 14, fontWeight: '600' }}>{checking ? a.checking : a.checkUpdates}</Text>
          </Pressable>
        ) : null}
      </View>

      <Card style={{ gap: Spacing.two, backgroundColor: c.dangerSubtle }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.two }}>
          <SymbolView name="exclamationmark.triangle" tintColor={c.danger} size={18} />
          <Text style={{ color: c.danger, fontSize: 16, fontWeight: '700' }}>{tx.about.legalTitle}</Text>
        </View>
        {tx.about.legal.map((line) => (
          <View key={line} style={{ flexDirection: 'row', gap: Spacing.two }}>
            <Text style={{ color: c.danger }}>•</Text>
            <Text style={{ color: c.textSecondary, fontSize: 13, lineHeight: 19, flex: 1 }}>{line}</Text>
          </View>
        ))}
      </Card>

      <Section title={t.settings.developer}>
        <LinkRow row={{ icon: 'app.badge', label: t.settings.moreFromDev, sub: 'Marcell Béres', url: PUBLISHER_URL }} onPress={openUrl} />
      </Section>

      <Section title={t.settings.credits}>
        {credits.map((r) => (
          <LinkRow key={r.label} row={r} onPress={openUrl} />
        ))}
        <Text style={{ color: c.textTertiary, fontSize: 12, lineHeight: 18, paddingTop: Spacing.two, paddingBottom: Spacing.one, textAlign: 'center' }}>
          {t.settings.creditsLicence}
        </Text>
      </Section>

      <Section title={tx.about.links}>
        {links.map((r) => (
          <LinkRow key={r.label} row={r} onPress={openUrl} />
        ))}
      </Section>
    </ScrollView>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={{ gap: Spacing.two }}>
      <SectionLabel>{title}</SectionLabel>
      <Card style={{ paddingVertical: Spacing.one }}>{children}</Card>
    </View>
  );
}

function LinkRow({ row, onPress }: { row: Row; onPress: (url: string) => void }) {
  const c = useTheme();
  return (
    <Pressable onPress={() => onPress(row.url)} style={({ pressed }) => ({ opacity: pressed ? 0.6 : 1 })}>
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: Spacing.three, paddingVertical: Spacing.two + 2 }}>
        <SymbolView name={row.icon} tintColor={c.style === 'native' ? c.brand : c.brandText} size={18} />
        <View style={{ flex: 1 }}>
          <Text style={{ color: c.text, fontSize: 15, fontWeight: '600' }}>{row.label}</Text>
          {row.sub ? <Text style={{ color: c.textSecondary, fontSize: 13 }}>{row.sub}</Text> : null}
        </View>
        <SymbolView name="arrow.up.right" tintColor={c.textTertiary} size={13} />
      </View>
    </Pressable>
  );
}
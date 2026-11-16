import { Image } from 'expo-image';
import { SymbolView } from 'expo-symbols';
import { useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, Text, TextInput, View } from 'react-native';

import { InstitutionPicker } from '@/components/institution-picker';
import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import type { Institute } from '@/neptun/types';
import { useAuth } from '@/providers/auth';

const logo = require('../../assets/images/nhnk-logo.png');

export default function LoginScreen() {
  const c = useTheme();
  const { t } = useI18n();
  const { signInReal, signInDemo, submitTwoFactor, pendingTwoFactor, cancelTwoFactor } = useAuth();

  const [institute, setInstitute] = useState<Institute | null>(null);
  const [neptunCode, setNeptunCode] = useState('');
  const [password, setPassword] = useState('');
  const [twoFactor, setTwoFactor] = useState('');
  const [pickerOpen, setPickerOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const inTwoFactor = pendingTwoFactor !== null;

  const field = {
    backgroundColor: c.card,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three - 2,
    color: c.text,
    fontSize: 16,
    borderCurve: 'continuous' as const,
  };

  const onSignIn = async () => {
    setError(null);
    if (!institute) return setError(t.login.errorNoInstitution);
    if (!neptunCode.trim() || !password) return setError(t.login.errorMissing);
    setBusy(true);
    const outcome = await signInReal(institute, neptunCode.trim(), password);
    setBusy(false);
    if (outcome.kind === 'failed') setError(outcome.message ?? t.login.errorWrong);
    else if (outcome.kind === 'network') setError(t.login.errorNetwork);
  };

  const onVerify = async () => {
    setError(null);
    if (twoFactor.trim().length < 6) return setError(t.login.errorCode);
    setBusy(true);
    const outcome = await submitTwoFactor(twoFactor.trim());
    setBusy(false);
    if (outcome.kind !== 'ok') setError(t.login.errorCode);
  };

  const onBack = () => {
    cancelTwoFactor();
    setTwoFactor('');
    setError(null);
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: c.background }}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={{
        flexGrow: 1,
        justifyContent: 'center',
        paddingHorizontal: Spacing.four,
        paddingVertical: Spacing.six,
        gap: Spacing.four,
      }}
      keyboardDismissMode="interactive">
      <View style={{ alignItems: 'center', gap: Spacing.two }}>
        <Image source={logo} style={{ width: 84, height: 84, borderRadius: Radius.xl }} contentFit="contain" />
        <Text style={{ color: c.text, fontSize: 34, fontWeight: '800', letterSpacing: 1 }}>NHNK</Text>
        <Text style={{ color: c.textSecondary, fontSize: 15 }}>{t.login.tagline}</Text>
      </View>

      {inTwoFactor ? (
        <View style={{ gap: Spacing.three }}>
          <View style={{ gap: Spacing.one }}>
            <Text style={{ color: c.text, fontSize: 20, fontWeight: '700', textAlign: 'center' }}>
              {t.login.twoFactorTitle}
            </Text>
            <Text style={{ color: c.textSecondary, fontSize: 14, textAlign: 'center', lineHeight: 20 }}>
              {t.login.twoFactorHint}
            </Text>
          </View>
          <TextInput
            style={[field, { textAlign: 'center', fontSize: 26, letterSpacing: 8, fontVariant: ['tabular-nums'] }]}
            placeholder="000000"
            placeholderTextColor={c.textTertiary}
            keyboardType="number-pad"
            maxLength={6}
            value={twoFactor}
            onChangeText={setTwoFactor}
            autoFocus
          />
          {error ? <Text style={{ color: c.danger, fontSize: 14, textAlign: 'center' }}>{error}</Text> : null}
          <PrimaryButton label={busy ? t.login.signingIn : t.login.verify} onPress={onVerify} busy={busy} c={c} />
          <Pressable onPress={onBack} disabled={busy} style={{ alignItems: 'center', paddingVertical: Spacing.two }}>
            <Text style={{ color: c.textSecondary, fontSize: 15 }}>{t.login.back}</Text>
          </Pressable>
        </View>
      ) : (
        <>
          <View style={{ gap: Spacing.two }}>
            <Pressable
              style={[field, { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }]}
              onPress={() => setPickerOpen(true)}>
              <Text style={{ color: institute ? c.text : c.textTertiary, fontSize: 16, flex: 1 }} numberOfLines={1}>
                {institute ? institute.name : t.login.institutionPlaceholder}
              </Text>
              <SymbolView name="chevron.right" tintColor={c.textTertiary} size={14} />
            </Pressable>
            <TextInput
              style={field}
              placeholder={t.login.codePlaceholder}
              placeholderTextColor={c.textTertiary}
              autoCapitalize="characters"
              autoCorrect={false}
              value={neptunCode}
              onChangeText={setNeptunCode}
            />
            <TextInput
              style={field}
              placeholder={t.login.passwordPlaceholder}
              placeholderTextColor={c.textTertiary}
              secureTextEntry
              value={password}
              onChangeText={setPassword}
            />
            {error ? <Text style={{ color: c.danger, fontSize: 14 }}>{error}</Text> : null}
          </View>

          <View style={{ gap: Spacing.two }}>
            <PrimaryButton label={busy ? t.login.signingIn : t.login.signInReal} onPress={onSignIn} busy={busy} c={c} />
            <Pressable
              onPress={signInDemo}
              disabled={busy}
              style={({ pressed }) => ({
                borderRadius: Radius.md,
                paddingVertical: Spacing.three,
                alignItems: 'center',
                flexDirection: 'row',
                justifyContent: 'center',
                gap: Spacing.two,
                borderWidth: 1,
                borderColor: c.separator,
                opacity: pressed ? 0.6 : 1,
                borderCurve: 'continuous',
              })}>
              <SymbolView name="play.circle.fill" tintColor={c.textSecondary} size={20} />
              <Text style={{ color: c.textSecondary, fontSize: 16, fontWeight: '600' }}>{t.login.exploreDemo}</Text>
            </Pressable>
          </View>
        </>
      )}

      <Text style={{ color: c.textTertiary, fontSize: 12, textAlign: 'center', lineHeight: 17 }}>
        {t.login.disclaimer}
      </Text>

      <InstitutionPicker visible={pickerOpen} onClose={() => setPickerOpen(false)} onSelect={setInstitute} />
    </ScrollView>
  );
}

function PrimaryButton({
  label,
  onPress,
  busy,
  c,
}: {
  label: string;
  onPress: () => void;
  busy: boolean;
  c: ReturnType<typeof useTheme>;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={busy}
      style={({ pressed }) => ({
        backgroundColor: c.brand,
        borderRadius: Radius.md,
        paddingVertical: Spacing.three,
        alignItems: 'center',
        flexDirection: 'row',
        justifyContent: 'center',
        gap: Spacing.two,
        opacity: pressed || busy ? 0.85 : 1,
        borderCurve: 'continuous',
      })}>
      {busy ? <ActivityIndicator color={c.brandOn} /> : null}
      <Text style={{ color: c.brandOn, fontSize: 16, fontWeight: '700' }}>{label}</Text>
    </Pressable>
  );
}
